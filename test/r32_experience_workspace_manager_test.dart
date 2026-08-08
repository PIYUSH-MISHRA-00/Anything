/// Implementation Specification IS-R32 — Experience Workspace Manager, AI
/// Operating System Workspace. Proves the real gap this specification
/// closes: `IntentSessionManager` (R31) already manages many concurrent
/// sessions internally, but nothing tracked which of them are "open" for
/// workspace display purposes or which one is "active." `ExperienceWorkspaceManager`
/// is that composition — it never re-implements creation/evolution/runtime
/// tracking, only forwards to the real, unmodified `IntentSessionManager`.
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
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r31_intent_session_manager_test.dart's
// established shape exactly (a test file cannot import another test file's
// private helpers). ──────────────────────────────────────────────────────

SemanticApp _app(String name, {bool withGear = false}) => SemanticApp(
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
    if (withGear)
      const SemanticEntity(
        id: 'gear',
        name: 'Gear',
        displayField: 'title',
        fields: [
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

/// Real end-to-end rig: one shared Kernel, one shared SQLite-backed
/// repository set, a real `IntentSessionManager`, and the real
/// `ExperienceWorkspaceManager` under test wrapping it — never a hand-built
/// substitute for either.
class _Rig {
  final SqliteExperienceRepository repository;
  final IntentSessionManager sessionManager;
  final ExperienceWorkspaceManager workspace;

  _Rig(this.repository, this.sessionManager, this.workspace);

  static _Rig create(List<SemanticApp> reasonerSequence) {
    final dbName = 'r32_workspace_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: dbName);
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
    return _Rig(repository, sessionManager, workspace);
  }
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Workspace creation (R32)', () {
    test(
      'openExperience() genuinely invokes the real, unmodified IntentSessionManager.startSession()',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final result = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );

        expect(result.creationResult, isA<CreationCreated>());
        // Real, hard proof of forwarding, not re-implementation: the exact
        // same session is now reachable directly off the real, unmodified
        // IntentSessionManager underneath.
        expect(
          identical(
            rig.sessionManager.sessionFor(result.sessionId),
            rig.workspace.activeSession,
          ),
          isTrue,
        );
        expect(rig.workspace.openSessionIds, [result.sessionId]);
        expect(rig.workspace.activeSessionId, result.sessionId);
        await rig.repository.close();
      },
    );
  });

  group('Multiple open experiences (R32)', () {
    test(
      'two real experiences open into one workspace, both tracked, the first stays active by default',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Book Club')]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my book club'),
        );

        expect(rig.workspace.openSessionIds, [
          first.sessionId,
          second.sessionId,
        ]);
        expect(rig.workspace.openSessions, hasLength(2));
        expect(
          rig.workspace.activeSessionId,
          first.sessionId,
          reason:
              'the first opened session stays active until explicitly switched',
        );
        await rig.repository.close();
      },
    );

    test(
      'switchActiveExperience() updates the real active pointer; switching to a non-open session throws',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Book Club')]);
        await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my book club'),
        );

        await rig.workspace.switchActiveExperience(second.sessionId);
        expect(rig.workspace.activeSessionId, second.sessionId);

        expect(
          () => rig.workspace.switchActiveExperience('unknown-session'),
          throwsStateError,
        );
        await rig.repository.close();
      },
    );

    test(
      'closeExperience() removes a session from the open set; closing the active session promotes a real remaining one',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Book Club')]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my book club'),
        );
        await rig.workspace.switchActiveExperience(first.sessionId);

        await rig.workspace.closeExperience(first.sessionId);
        expect(rig.workspace.openSessionIds, [second.sessionId]);
        expect(
          rig.workspace.activeSessionId,
          second.sessionId,
          reason:
              'closing the active session must promote a real remaining open one',
        );

        // Closing never touches the persisted Experience itself.
        final persisted = await rig.repository.getPackage(
          rig.sessionManager.sessionFor(second.sessionId)!.currentExperienceId!,
        );
        expect(persisted, isNotNull);
        await rig.repository.close();
      },
    );

    test(
      'closing the last open session leaves activeSessionId honestly null, never fabricated',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final only = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        await rig.workspace.closeExperience(only.sessionId);
        expect(rig.workspace.activeSessionId, isNull);
        expect(rig.workspace.openSessions, isEmpty);
        await rig.repository.close();
      },
    );
  });

  group('Session forwarding (R32)', () {
    test(
      'continueExperience() genuinely invokes the real, unmodified EngineeringLifecycleCoordinator via IntentSessionManager',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Camp Log', withGear: true),
        ]);
        final start = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );

        final continueResult = await rig.workspace.continueExperience(
          start.sessionId,
          Intent.create(expression: 'also track my gear'),
        );

        expect(
          continueResult.lifecycleResult.regenerationPlan!.isNoOp,
          isFalse,
        );
        // Real, hard identity proof this is the SAME result IntentSessionManager itself now holds.
        expect(
          identical(
            rig.sessionManager
                .sessionFor(start.sessionId)!
                .currentLifecycleResult,
            continueResult.lifecycleResult,
          ),
          isTrue,
        );
        await rig.repository.close();
      },
    );

    test(
      'continueExperience() on a session the workspace never opened is honestly rejected, never silently forwarded',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        await expectLater(
          () => rig.workspace.continueExperience(
            'never-opened',
            Intent.create(expression: 'anything'),
          ),
          throwsStateError,
        );
        await rig.repository.close();
      },
    );
  });

  group('Background engineering (R32)', () {
    test(
      'a session that is open but NOT active still has its own real, independent SessionState tracked correctly',
      () async {
        final rig = _Rig.create([
          _app('Camp Log'),
          _app('Book Club'),
          _app('Book Club', withGear: true),
        ]);
        final active = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final background = await rig.workspace.openExperience(
          Intent.create(expression: 'track my book club'),
        );
        expect(
          rig.workspace.activeSessionId,
          active.sessionId,
          reason: 'background stays non-active by default',
        );

        // Evolve the BACKGROUND session while another remains active.
        final continueResult = await rig.workspace.continueExperience(
          background.sessionId,
          Intent.create(expression: 'also track gear'),
        );
        expect(
          continueResult.lifecycleResult.regenerationPlan!.isNoOp,
          isFalse,
        );
        expect(
          rig.workspace.activeSessionId,
          active.sessionId,
          reason:
              'evolving a background session must never change which one is active',
        );
        expect(
          rig.sessionManager
              .sessionFor(background.sessionId)!
              .currentLifecycleResult,
          isNotNull,
        );
        expect(
          rig.sessionManager
              .sessionFor(active.sessionId)!
              .currentLifecycleResult,
          isNull,
          reason:
              'the active-but-untouched session has its own, real, independent state',
        );
        await rig.repository.close();
      },
    );
  });

  group('Runtime tracking (R32)', () {
    test(
      'updateRuntimeState() forwards, unmodified, to the real IntentSessionManager — never a second, parallel copy',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final start = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final runtimeState = ExperienceSession(
          id: 'rt-1',
          experienceId: rig.sessionManager
              .sessionFor(start.sessionId)!
              .currentExperienceId!,
          package: (start.creationResult as CreationCreated).package,
          status: SessionStatus.running,
          startedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        rig.workspace.updateRuntimeState(start.sessionId, runtimeState);
        expect(
          identical(
            rig.sessionManager.sessionFor(start.sessionId)!.currentRuntimeState,
            runtimeState,
          ),
          isTrue,
        );
        await rig.repository.close();
      },
    );

    test(
      'reportRuntimeStateForExperience() finds the real open session by experienceId and forwards; a harmless no-op when none is open',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final start = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final experienceId = rig.sessionManager
            .sessionFor(start.sessionId)!
            .currentExperienceId!;
        final runtimeState = ExperienceSession(
          id: 'rt-1',
          experienceId: experienceId,
          package: (start.creationResult as CreationCreated).package,
          status: SessionStatus.running,
          startedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        rig.workspace.reportRuntimeStateForExperience(
          experienceId,
          runtimeState,
        );
        expect(
          identical(
            rig.sessionManager.sessionFor(start.sessionId)!.currentRuntimeState,
            runtimeState,
          ),
          isTrue,
        );

        // A harmless no-op for an experience with no open session.
        expect(
          () => rig.workspace.reportRuntimeStateForExperience(
            'unknown-experience',
            runtimeState,
          ),
          returnsNormally,
        );
        await rig.repository.close();
      },
    );
  });

  group('Workspace timeline (R32)', () {
    test(
      'open/close/switch each record a real, real-ordered timeline event',
      () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Book Club')]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my book club'),
        );
        await rig.workspace.switchActiveExperience(second.sessionId);
        await rig.workspace.closeExperience(first.sessionId);

        expect(rig.workspace.timeline, hasLength(4));
        expect(rig.workspace.timeline.map((e) => e.type), [
          'workspace_closed',
          'workspace_switched',
          'workspace_opened',
          'workspace_opened',
        ]);
        await rig.repository.close();
      },
    );
  });

  group(
    'UI integration — backward compatibility (R32, Mandatory Vision Validation)',
    () {
      // Real SQLite FFI (via the rig's real Kernel/repository calls) does not
      // cooperate with testWidgets's default FakeAsync zone — same pattern as
      // Stage 11/R13's own established widget-test convention: every real
      // async step (rig setup, real Kernel/SQLite calls, real pump delays)
      // must run inside `tester.runAsync()`.
      Future<void> settleReal(WidgetTester tester, {int rounds = 5}) async {
        for (var i = 0; i < rounds; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }
      }

      setUpAll(() {
        TestWidgetsFlutterBinding.ensureInitialized();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
      });

      testWidgets(
        'ExperienceHostScreen constructed WITHOUT workspaceManager behaves exactly as before — no crash, real render',
        (tester) async {
          late _Rig rig;
          late SessionStartResult result;
          await tester.runAsync(() async {
            rig = _Rig.create([_app('Camp Log')]);
            result = await rig.workspace.openExperience(
              Intent.create(expression: 'track my camping trips'),
            );
          });
          final package = (result.creationResult as CreationCreated).package;

          await tester.pumpWidget(
            MaterialApp(
              home: ExperienceHostScreen(
                package: package,
                experienceId: 'exp-no-workspace',
                experienceName: 'Camp Log',
              ),
            ),
          );
          await settleReal(tester);
          expect(find.byType(ExperienceHostScreen), findsOneWidget);
          await tester.runAsync(() => rig.repository.close());
        },
      );

      testWidgets(
        'ExperienceHostScreen constructed WITH a real workspaceManager reports its runtime state once loaded',
        (tester) async {
          late _Rig rig;
          late SessionStartResult result;
          late String experienceId;
          await tester.runAsync(() async {
            rig = _Rig.create([_app('Camp Log')]);
            result = await rig.workspace.openExperience(
              Intent.create(expression: 'track my camping trips'),
            );
            experienceId = rig.sessionManager
                .sessionFor(result.sessionId)!
                .currentExperienceId!;
          });
          final package = (result.creationResult as CreationCreated).package;

          expect(
            rig.sessionManager
                .sessionFor(result.sessionId)!
                .currentRuntimeState,
            isNull,
            reason: 'no runtime has reported in yet',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: ExperienceHostScreen(
                package: package,
                experienceId: experienceId,
                experienceName: 'Camp Log',
                workspaceManager: rig.workspace,
              ),
            ),
          );
          await settleReal(tester);

          final reported = rig.sessionManager
              .sessionFor(result.sessionId)!
              .currentRuntimeState;
          expect(
            reported,
            isNotNull,
            reason:
                'a real, injected workspaceManager must receive a real runtime-state report once the runtime loads',
          );
          expect(reported!.status, SessionStatus.running);
          expect(reported.experienceId, experienceId);
          await tester.runAsync(() => rig.repository.close());
        },
      );
    },
  );

  group(
    'Regression (R32) — IntentSessionManager behavior is completely unaffected',
    () {
      test(
        'IntentSessionManager.startSession()/continueSession() called directly (bypassing the workspace entirely) behave exactly as before',
        () async {
          final rig = _Rig.create([
            _app('Camp Log'),
            _app('Camp Log', withGear: true),
          ]);
          final start = await rig.sessionManager.startSession(
            Intent.create(expression: 'track my camping trips'),
          );
          expect(start.creationResult, isA<CreationCreated>());
          final cont = await rig.sessionManager.continueSession(
            start.sessionId,
            Intent.create(expression: 'also track my gear'),
          );
          expect(cont.lifecycleResult.regenerationPlan!.isNoOp, isFalse);
          await rig.repository.close();
        },
      );
    },
  );

  group(
    'Performance (R32) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('workspace startup + first open latency', () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final stopwatch = Stopwatch()..start();
        await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'R32 workspace startup + first open: ${stopwatch.elapsedMilliseconds}ms',
        );
        await rig.repository.close();
      });

      test('experience-switching latency across two open sessions', () async {
        final rig = _Rig.create([_app('Camp Log'), _app('Book Club')]);
        final first = await rig.workspace.openExperience(
          Intent.create(expression: 'track my camping trips'),
        );
        final second = await rig.workspace.openExperience(
          Intent.create(expression: 'track my book club'),
        );
        final stopwatch = Stopwatch()..start();
        await rig.workspace.switchActiveExperience(second.sessionId);
        await rig.workspace.switchActiveExperience(first.sessionId);
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'R32 experience switching (2 switches): ${stopwatch.elapsedMilliseconds}ms',
        );
        await rig.repository.close();
      });

      test(
        'memory: real process RSS delta while opening 20 real experiences into one workspace',
        () async {
          final rig = _Rig.create(List.generate(20, (i) => _app('App $i')));
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 20; i++) {
            await rig.workspace.openExperience(
              Intent.create(expression: 'app number $i'),
            );
          }
          final rssAfter = ProcessInfo.currentRss;
          expect(rig.workspace.openSessions, hasLength(20));
          // ignore: avoid_print
          print(
            'R32 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 20 sessions',
          );
          await rig.repository.close();
        },
      );
    },
  );
}
