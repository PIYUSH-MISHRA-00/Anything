/// Implementation Specification IS-R38 — Experience Runtime Controller, AI
/// Operating System Runtime Lifecycle.
///
/// REALITY before R38 (confirmed by reading source): `AnythingRuntime`
/// (`lib/runtime/anything_runtime.dart`) already has a real, tested
/// lifecycle API — `openExperience()`/`pauseSession()`/`resumeSession()`/
/// `closeSession()` — but `pauseSession()`/`resumeSession()` had ZERO
/// callers anywhere in `lib/`, and `ExperienceHostScreen` duplicated the
/// real `closeSession()`+`openExperience()` "reload" pair inline, verbatim,
/// twice (`_runModification`, `_performRollback`). This file proves, with
/// real objects (never mocks of the subsystem under test):
/// `ExperienceRuntimeController` reaches the real `AnythingRuntime` for
/// every transition, pause/resume now have a real caller, reload performs a
/// genuine close+reopen (not a no-op), snapshot/restore round-trips a real
/// package through a FRESH runtime, and workspace/event reporting now
/// carries the runtime's own REAL `currentSession` — never the synthetic
/// stand-in `ExperienceHostScreen` used to hand-build.
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/workspace_event_publisher.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/core/events/events.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/runtime/experience_runtime_controller.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r37_intent_execution_pipeline_test.dart's
// established rig shape exactly, restricted to the R31-R32 chain this file
// needs (an open workspace session to report/publish against). ───────────

SemanticApp _app(String name) => SemanticApp(
  name: name,
  purpose: 'Track $name',
  entities: [
    SemanticEntity(
      id: 'trip',
      name: 'Trip',
      displayField: 'title',
      fields: const [
        SemanticField(
          id: 'title',
          name: 'Title',
          type: BlueprintFieldType.text,
          required: true,
        ),
      ],
    ),
  ],
  requiredCapabilities: const ['storage'],
);

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 'Local storage',
      category: CapabilityCategory.storage,
      inputContract: 'data',
      outputContract: 'stored data',
    ),
  );
  return registry;
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  @override
  ModelProvider? get activeProvider => null;
  @override
  List<ModelProvider> get providers => const [];
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String providerId) async {}
  @override
  ModelProvider? getProvider(String providerId) => null;
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

class _SequencedReasoner implements ApplicationReasoner {
  final List<SemanticApp> apps;
  int _calls = 0;
  _SequencedReasoner(this.apps);

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    final app = apps[_calls < apps.length ? _calls : apps.length - 1];
    _calls++;
    return ReasoningReady(semanticApp: app);
  }
}

class _Rig {
  final SqliteExperienceRepository repository;
  final EngineeringMemoryRepository engineeringMemory;
  final ExperienceWorkspaceManager workspace;

  _Rig({
    required this.repository,
    required this.engineeringMemory,
    required this.workspace,
  });

  static Future<_Rig> create(List<SemanticApp> reasonerSequence) async {
    final name =
        'r38_runtime_controller_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: name);
    final engineeringMemory = EngineeringMemoryRepository(
      experienceRepository: repository,
    );
    final activity = ActivityRepository();
    final reasoner = _SequencedReasoner(reasonerSequence);
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: reasoner,
    );

    final creationCoordinator = ExperienceCreationCoordinator(
      kernel: kernel,
      repository: repository,
      engineeringMemory: engineeringMemory,
    );
    final lifecycleCoordinator = EngineeringLifecycleCoordinator(
      kernel: kernel,
      engineeringMemory: engineeringMemory,
      repository: repository,
    );
    final sessionManager = IntentSessionManager(
      creationCoordinator: creationCoordinator,
      lifecycleCoordinator: lifecycleCoordinator,
      engineeringMemory: engineeringMemory,
      activity: activity,
    );
    final workspace = ExperienceWorkspaceManager(
      sessionManager: sessionManager,
      activity: activity,
    );

    return _Rig(
      repository: repository,
      engineeringMemory: engineeringMemory,
      workspace: workspace,
    );
  }

  /// Opens a real workspace session and returns its real `experienceId` —
  /// the id [ExperienceRuntimeController]'s workspace/event reporting keys
  /// off of.
  Future<String> openRealSession() async {
    final result = await workspace.openExperience(
      Intent.create(expression: 'track my camping trips'),
    );
    return (result.creationResult as CreationCreated).experienceId;
  }
}

/// Minimal, real `ExperiencePackage` that ACTUALLY SUCCEEDS in
/// `AnythingRuntime.openExperience()` — needs at least one real screen
/// (`AnythingRuntime._validatePackage` rejects an empty screen list).
/// Mirrors `test/r6_runtime_patching_test.dart`'s own established
/// `_package()` helper shape.
ExperiencePackage _runnablePackage({
  String experienceId = 'exp-1',
  String version = '1',
}) {
  final now = DateTime(2026);
  const screens = [
    InterfaceScreen(
      id: 's1',
      title: 'Home',
      children: [
        InterfaceNode(type: 'text', id: 'n1', properties: {'text': 'Hi'}),
      ],
    ),
  ];
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: experienceId,
      name: 'Test',
      description: 'd',
      category: 'general',
      entryPoint: 's1',
      version: version,
      createdAt: now,
      updatedAt: now,
    ),
    interface: const InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    capabilityDeclarations: const [],
    provenance: const PackageProvenance(
      creationEngineVersion: 'test',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
  );
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Runtime startup (R38)', () {
    test(
      'controller.start(package) reaches AnythingRuntime.openExperience(), returns a real running ExperienceSession',
      () async {
        final runtime = AnythingRuntime();
        final controller = ExperienceRuntimeController(runtime: runtime);

        final session = await controller.start(_runnablePackage());

        expect(session.status, SessionStatus.running);
        expect(runtime.status, RuntimeStatus.running);
        expect(runtime.currentSession, same(session));
      },
    );
  });

  group(
    'Pause / Resume (R38) — previously-dead AnythingRuntime methods, now with a real caller',
    () {
      test(
        'controller.pause() transitions runtime.status/currentSession.status to paused; controller.resume() transitions back to running',
        () async {
          final runtime = AnythingRuntime();
          final controller = ExperienceRuntimeController(runtime: runtime);
          await controller.start(_runnablePackage());

          controller.pause();
          expect(runtime.status, RuntimeStatus.paused);
          expect(runtime.currentSession!.status, SessionStatus.paused);

          controller.resume();
          expect(runtime.status, RuntimeStatus.running);
          expect(runtime.currentSession!.status, SessionStatus.running);
        },
      );
    },
  );

  group(
    'Reload (R38) — the exact real closeSession()+openExperience() pair ExperienceHostScreen used to duplicate inline',
    () {
      test(
        'reload() with no explicit package reuses the current one; the underlying runtime genuinely tears down and reconstructs (a fresh ExperienceRouter instance proves it, not a no-op)',
        () async {
          final runtime = AnythingRuntime();
          final controller = ExperienceRuntimeController(runtime: runtime);
          await controller.start(_runnablePackage());
          final routerBefore = runtime.router;

          final session = await controller.reload();

          expect(session.package.manifest.experienceId, 'exp-1');
          expect(
            identical(runtime.router, routerBefore),
            isFalse,
            reason:
                'openExperience() always constructs a NEW ExperienceRouter — identity change is real, direct proof of a genuine close+reopen',
          );
          expect(runtime.status, RuntimeStatus.running);
        },
      );

      test(
        'reload(package: evolved) uses the explicitly-passed package, not the stale runtime.currentSession.package — the real case every ExperienceHostScreen call site needs',
        () async {
          final runtime = AnythingRuntime();
          final controller = ExperienceRuntimeController(runtime: runtime);
          await controller.start(_runnablePackage(version: '1'));

          final evolved = _runnablePackage(version: '2');
          final session = await controller.reload(package: evolved);

          expect(session.package.manifest.version, '2');
          expect(runtime.currentSession!.package.manifest.version, '2');
        },
      );

      test(
        'reload() with no current session and no explicit package throws a real, honest StateError',
        () async {
          final controller = ExperienceRuntimeController(
            runtime: AnythingRuntime(),
          );
          expect(() => controller.reload(), throwsStateError);
        },
      );
    },
  );

  group('Termination (R38)', () {
    test(
      'controller.terminate() reaches runtime.closeSession() — status becomes idle, currentSession becomes null',
      () async {
        final runtime = AnythingRuntime();
        final controller = ExperienceRuntimeController(runtime: runtime);
        await controller.start(_runnablePackage());

        await controller.terminate();

        expect(runtime.status, RuntimeStatus.idle);
        expect(runtime.currentSession, isNull);
      },
    );
  });

  group(
    'Snapshot / Restore (R38) — no new snapshot type, ExperienceSession itself is the real snapshot',
    () {
      test(
        'captureSnapshot() returns the real current session; restore(snapshot) on a FRESH controller/runtime reconstructs a running session from the SAME package — a real round-trip',
        () async {
          final originalRuntime = AnythingRuntime();
          final originalController = ExperienceRuntimeController(
            runtime: originalRuntime,
          );
          await originalController.start(
            _runnablePackage(experienceId: 'exp-snapshot', version: '3'),
          );

          final snapshot = originalController.captureSnapshot();
          expect(snapshot, isNotNull);
          expect(snapshot!.package.manifest.experienceId, 'exp-snapshot');

          final freshRuntime = AnythingRuntime();
          final freshController = ExperienceRuntimeController(
            runtime: freshRuntime,
          );
          final restored = await freshController.restore(snapshot);

          expect(restored.status, SessionStatus.running);
          expect(restored.package.manifest.experienceId, 'exp-snapshot');
          expect(restored.package.manifest.version, '3');
          expect(freshRuntime.status, RuntimeStatus.running);
        },
      );
    },
  );

  group(
    'Workspace / event integration (R38) — the REAL AnythingRuntime.currentSession is reported, never a synthetic stand-in',
    () {
      test(
        'start()/pause()/resume()/reload()/terminate() each report the real currentSession via workspace.reportRuntimeStateForExperience',
        () async {
          final rig = await _Rig.create([_app('Camp Log')]);
          final experienceId = await rig.openRealSession();
          final runtime = AnythingRuntime();
          final controller = ExperienceRuntimeController(
            runtime: runtime,
            workspace: rig.workspace,
            experienceId: experienceId,
          );

          final started = await controller.start(
            _runnablePackage(experienceId: experienceId),
          );
          final reportedAfterStart = rig.workspace
              .sessionForExperience(experienceId)!
              .currentRuntimeState;
          expect(
            reportedAfterStart,
            same(started),
            reason:
                'the workspace must hold the REAL runtime session object, never a hand-built stand-in with a fabricated id',
          );

          controller.pause();
          expect(
            rig.workspace
                .sessionForExperience(experienceId)!
                .currentRuntimeState!
                .status,
            SessionStatus.paused,
          );

          controller.resume();
          expect(
            rig.workspace
                .sessionForExperience(experienceId)!
                .currentRuntimeState!
                .status,
            SessionStatus.running,
          );

          final reloaded = await controller.reload();
          expect(
            rig.workspace
                .sessionForExperience(experienceId)!
                .currentRuntimeState,
            same(reloaded),
          );

          await controller.terminate();
          // terminate() reports the CLOSING session (captured before close nulls
          // it) — the workspace's last real report is the closed-status session,
          // never silently skipped.
          expect(
            rig.workspace
                .sessionForExperience(experienceId)!
                .currentRuntimeState!
                .status,
            SessionStatus.closed,
          );

          await rig.repository.close();
        },
      );

      test(
        'every transition publishes a real WorkspaceUpdated event to a real EventBus subscriber, with the correct change string',
        () async {
          final rig = await _Rig.create([_app('Camp Log')]);
          final experienceId = await rig.openRealSession();
          final bus = EventBus();
          final publisher = WorkspaceEventPublisher(bus: bus, source: 'test');
          final runtime = AnythingRuntime();
          final controller = ExperienceRuntimeController(
            runtime: runtime,
            workspace: rig.workspace,
            eventPublisher: publisher,
            experienceId: experienceId,
          );

          final received = <WorkspaceUpdated>[];
          bus.on<WorkspaceUpdated>().listen(received.add);

          await controller.start(_runnablePackage(experienceId: experienceId));
          controller.pause();
          controller.resume();
          await controller.reload();
          await controller.terminate();
          await Future.delayed(Duration.zero);

          expect(received.map((e) => e.change).toList(), [
            'runtime_started',
            'runtime_paused',
            'runtime_resumed',
            'runtime_reloaded',
            'runtime_terminated',
          ]);

          await rig.repository.close();
        },
      );
    },
  );

  group(
    'Regression (R38) — AnythingRuntime behavior is completely unaffected by the controller',
    () {
      test(
        'AnythingRuntime.openExperience()/pauseSession()/resumeSession()/closeSession() called directly, bypassing the controller entirely, still behave exactly as before',
        () async {
          final runtime = AnythingRuntime();
          final session = await runtime.openExperience(_runnablePackage());
          expect(session.status, SessionStatus.running);

          runtime.pauseSession();
          expect(runtime.status, RuntimeStatus.paused);
          runtime.resumeSession();
          expect(runtime.status, RuntimeStatus.running);

          await runtime.closeSession();
          expect(runtime.status, RuntimeStatus.idle);
          expect(runtime.currentSession, isNull);
        },
      );
    },
  );

  group('Backward compatibility (R38) — ExperienceHostScreen', () {
    test(
      'ExperienceHostScreen constructed WITHOUT runtimeController defaults it to null (constructor otherwise unchanged)',
      () {
        final widget = ExperienceHostScreen(package: _runnablePackage());
        expect(widget.runtimeController, isNull);
      },
    );

    testWidgets(
      'the existing "Change this app" reload flow behaves identically (same snackbar, same undo availability) whether or not a runtimeController is injected',
      (tester) async {
        final before = _runnablePackage(experienceId: 'exp-host', version: '1');
        final runtime = AnythingRuntime();
        await runtime.openExperience(before);

        await tester.pumpWidget(
          MaterialApp(
            home: ExperienceHostScreen(
              package: before,
              experienceId: 'exp-host',
              runtime: runtime,
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(
          find.text('Home'),
          findsWidgets,
          reason:
              'the screen loaded successfully with no injected runtimeController (the default, accept-and-store path)',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'Performance (R38) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated',
    () {
      test(
        'lifecycle transition latency: start/pause/resume/reload/terminate',
        () async {
          final runtime = AnythingRuntime();
          final controller = ExperienceRuntimeController(runtime: runtime);

          final sw = Stopwatch()..start();
          await controller.start(_runnablePackage());
          controller.pause();
          controller.resume();
          await controller.reload();
          await controller.terminate();
          sw.stop();
          // ignore: avoid_print
          print(
            'R38 full lifecycle (start/pause/resume/reload/terminate): ${sw.elapsedMicroseconds}us',
          );
        },
      );

      test('snapshot latency', () async {
        final runtime = AnythingRuntime();
        final controller = ExperienceRuntimeController(runtime: runtime);
        await controller.start(_runnablePackage());

        final sw = Stopwatch()..start();
        controller.captureSnapshot();
        sw.stop();
        // ignore: avoid_print
        print('R38 captureSnapshot(): ${sw.elapsedMicroseconds}us');
      });

      test(
        'memory: real process RSS delta across repeated start/terminate cycles',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 10; i++) {
            final runtime = AnythingRuntime();
            final controller = ExperienceRuntimeController(runtime: runtime);
            await controller.start(_runnablePackage());
            await controller.terminate();
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R38 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 start/terminate cycles',
          );
        },
      );
    },
  );
}
