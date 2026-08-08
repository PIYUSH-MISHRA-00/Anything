/// Implementation Specification IS-R31 — Intent Session Manager, AI
/// Operating System Entry Point. Proves the real gap this specification
/// closes: nothing composed `ExperienceCreationCoordinator` (initial
/// creation) and `EngineeringLifecycleCoordinator` (R30, ongoing
/// evolution) into one session-owning entry point. `IntentSessionManager`
/// is that composition — it never calls `AnythingKernel.processIntent()`
/// directly, never re-implements diffing/execution/persistence, and never
/// touches `ExperienceModificationCoordinator` directly (that stays
/// `EngineeringLifecycleCoordinator`'s own internal concern, R30).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r30_engineering_lifecycle_test.dart's
// established shape exactly (a test file cannot import another test
// file's private helpers). One real difference: a STATEFUL reasoner
// (`_SequencedReasoner`) rather than two separately-configured Kernels —
// this manager holds ONE kernel-backed coordinator pair for its whole
// lifetime, exactly as production does (one shared `AppComposition`
// Kernel answers many different real prompts over a session's lifetime);
// a real LLM naturally returns different SemanticApps for different real
// prompts, so a sequenced fake reproduces that shape faithfully instead of
// needing a second Kernel instance per call, which production never has. ──

SemanticApp _campApp({bool withGear = false}) => SemanticApp(
  name: 'Camp Log',
  purpose: 'Track camping trips',
  entities: [
    const SemanticEntity(
      id: 'trip',
      name: 'Trip',
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

/// Returns [apps] in order, one per real reasoning call, then repeats the
/// last one — the SAME single reasoning call every production path already
/// uses, just deterministic instead of a real LLM.
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

/// Real end-to-end rig: one shared Kernel (stateful reasoner), one shared
/// SQLite-backed repository set, and the real `IntentSessionManager` under
/// test — composing the real, unmodified `ExperienceCreationCoordinator`/
/// `EngineeringLifecycleCoordinator`, never a hand-built substitute.
class _Rig {
  final SqliteExperienceRepository repository;
  final EngineeringMemoryRepository engineeringMemory;
  final ActivityRepository activity;
  final IntentSessionManager manager;

  _Rig(this.repository, this.engineeringMemory, this.activity, this.manager);

  static _Rig create(
    List<SemanticApp> reasonerSequence, {
    String dbSuffix = '',
  }) {
    final dbName =
        'r31_session_${DateTime.now().microsecondsSinceEpoch}_$dbSuffix.db';
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
    final manager = IntentSessionManager(
      creationCoordinator: creationCoordinator,
      lifecycleCoordinator: lifecycleCoordinator,
      engineeringMemory: engineeringMemory,
      activity: activity,
    );
    return _Rig(repository, engineeringMemory, activity, manager);
  }
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Session creation (R31)', () {
    test(
      'startSession() creates a real experience, records a real timeline entry, loads real engineering state',
      () async {
        final rig = _Rig.create([_campApp()]);
        final result = await rig.manager.startSession(
          Intent.create(expression: 'track my camping trips'),
        );

        expect(result.creationResult, isA<CreationCreated>());
        final experienceId =
            (result.creationResult as CreationCreated).experienceId;

        final state = rig.manager.sessionFor(result.sessionId)!;
        expect(state.currentExperienceId, experienceId);
        expect(state.currentExperienceName, 'Camp Log');
        expect(
          state.currentEngineeringState,
          isNotNull,
          reason:
              'ExperienceCreationCoordinator already persists engineering memory on success (R5) — no second write needed',
        );
        expect(state.currentEngineeringState!.requirementGraph, isNotNull);
        expect(state.timeline, hasLength(1));
        expect(state.timeline.single.type, 'session_started');
        expect(state.timeline.single.experienceId, experienceId);

        await rig.repository.close();
      },
    );

    test(
      'an unknown sessionId is honestly rejected, never a fabricated empty session',
      () {
        final rig = _Rig.create([_campApp()]);
        expect(rig.manager.sessionFor('does-not-exist'), isNull);
      },
    );
  });

  group(
    'Session continuation (R31 centerpiece) — real dispatch to EngineeringLifecycleCoordinator, unmodified',
    () {
      test(
        'continueSession() on an active session invokes the REAL, unmodified EngineeringLifecycleCoordinator and reflects its real LifecycleOutcome',
        () async {
          final rig = _Rig.create([_campApp(), _campApp(withGear: true)]);
          final start = await rig.manager.startSession(
            Intent.create(expression: 'track my camping trips'),
          );
          final experienceId =
              (start.creationResult as CreationCreated).experienceId;

          final continueResult = await rig.manager.continueSession(
            start.sessionId,
            Intent.create(expression: 'also track my gear'),
          );

          expect(continueResult.sessionId, start.sessionId);
          expect(continueResult.lifecycleResult, isA<LifecycleResult>());
          // A real, structural change (gear entity added) against a real
          // "before" state must be detected — never noChangeDetected for a
          // genuinely different after-state.
          expect(
            continueResult.lifecycleResult.outcome,
            isNot(LifecycleOutcome.noEngineeringMemory),
          );
          expect(
            continueResult.lifecycleResult.outcome,
            isNot(LifecycleOutcome.cannotEvolve),
          );
          expect(
            continueResult.lifecycleResult.regenerationPlan!.isNoOp,
            isFalse,
          );

          final state = rig.manager.sessionFor(start.sessionId)!;
          expect(
            state.currentLifecycleResult,
            same(continueResult.lifecycleResult),
          );
          expect(
            state.completedModification,
            same(continueResult.lifecycleResult),
          );
          expect(
            state.pendingModification,
            isNull,
            reason: 'must be cleared once the call returns',
          );
          expect(state.timeline, hasLength(2));
          expect(state.timeline.first.type, 'session_continued');
          expect(state.timeline.first.experienceId, experienceId);

          await rig.repository.close();
        },
      );

      test(
        'an identical re-intent produces LifecycleOutcome.noChangeDetected, reflected honestly in the session',
        () async {
          final rig = _Rig.create([_campApp(), _campApp()]);
          final start = await rig.manager.startSession(
            Intent.create(expression: 'track my camping trips'),
          );

          final continueResult = await rig.manager.continueSession(
            start.sessionId,
            Intent.create(expression: 'track my camping trips'),
          );
          expect(
            continueResult.lifecycleResult.outcome,
            LifecycleOutcome.noChangeDetected,
          );

          await rig.repository.close();
        },
      );

      test(
        'continueSession() on an unknown sessionId throws StateError, never silently no-ops',
        () async {
          final rig = _Rig.create([_campApp()]);
          expect(
            () => rig.manager.continueSession(
              'nope',
              Intent.create(expression: 'x'),
            ),
            throwsStateError,
          );
        },
      );

      test(
        'continueSession() on a session whose creation never succeeded (no active experience) throws StateError',
        () async {
          // A reasoner that always fails to reach ExecutionPlanReady — Kernel
          // never returns a usable outcome, so startSession() leaves the
          // session with no experienceId.
          final dbName =
              'r31_no_experience_${DateTime.now().microsecondsSinceEpoch}.db';
          final repository = SqliteExperienceRepository(dbName: dbName);
          final engineeringMemory = EngineeringMemoryRepository(
            experienceRepository: repository,
          );
          final kernel = AnythingKernel(
            providerRegistry: _FakeProviderRegistry(),
            capabilityRegistry: CapabilityRegistry(),
            reasoner: _SequencedReasoner([_campApp()]),
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
          final manager = IntentSessionManager(
            creationCoordinator: creationCoordinator,
            lifecycleCoordinator: lifecycleCoordinator,
            engineeringMemory: engineeringMemory,
          );

          // No 'storage' capability registered -> UnsupportedIntent -> CreationFailed.
          final start = await manager.startSession(
            Intent.create(expression: 'track my camping trips'),
          );
          expect(start.creationResult, isA<CreationFailed>());
          expect(
            () => manager.continueSession(
              start.sessionId,
              Intent.create(expression: 'x'),
            ),
            throwsStateError,
          );

          await repository.close();
        },
      );
    },
  );

  group(
    'Runtime state tracking (R31) — this manager never owns/constructs a runtime, only records what a caller reports',
    () {
      test(
        'currentRuntimeState is null until a caller reports one; updateRuntimeState() sets it honestly',
        () async {
          final rig = _Rig.create([_campApp()]);
          final start = await rig.manager.startSession(
            Intent.create(expression: 'track my camping trips'),
          );
          expect(
            rig.manager.sessionFor(start.sessionId)!.currentRuntimeState,
            isNull,
          );

          final runtimeSession = ExperienceSession(
            id: 'rt-1',
            experienceId:
                (start.creationResult as CreationCreated).experienceId,
            package: (start.creationResult as CreationCreated).package,
            status: SessionStatus.running,
            startedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          );
          rig.manager.updateRuntimeState(start.sessionId, runtimeSession);
          expect(
            rig.manager.sessionFor(start.sessionId)!.currentRuntimeState,
            same(runtimeSession),
          );

          await rig.repository.close();
        },
      );

      test(
        'updateRuntimeState() on an unknown sessionId is a real, harmless no-op, never a crash',
        () {
          final rig = _Rig.create([_campApp()]);
          final runtimeSession = ExperienceSession.error(
            experienceId: 'x',
            error: 'test',
          );
          expect(
            () => rig.manager.updateRuntimeState('unknown', runtimeSession),
            returnsNormally,
          );
        },
      );
    },
  );

  group(
    'Regression (R31) — ExperienceCreationCoordinator/EngineeringLifecycleCoordinator behavior is completely unaffected',
    () {
      test(
        'ExperienceCreationCoordinator.createFromIntent() called directly (bypassing IntentSessionManager entirely) behaves exactly as before',
        () async {
          final dbName =
              'r31_direct_creation_${DateTime.now().microsecondsSinceEpoch}.db';
          final repository = SqliteExperienceRepository(dbName: dbName);
          final kernel = AnythingKernel(
            providerRegistry: _FakeProviderRegistry(),
            capabilityRegistry: _registryWithStorage(),
            reasoner: _SequencedReasoner([_campApp()]),
          );
          final coordinator = ExperienceCreationCoordinator(
            kernel: kernel,
            repository: repository,
          );
          final result = await coordinator.createFromIntent(
            Intent.create(expression: 'track my camping trips'),
          );
          expect(result, isA<CreationCreated>());
          await repository.close();
        },
      );
    },
  );

  group(
    'Performance (R31) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('session startup latency', () async {
        final rig = _Rig.create([_campApp()]);
        final stopwatch = Stopwatch()..start();
        await rig.manager.startSession(
          Intent.create(expression: 'track my camping trips'),
        );
        stopwatch.stop();
        // ignore: avoid_print
        print('R31 session startup: ${stopwatch.elapsedMilliseconds}ms');
        await rig.repository.close();
      });

      test('session continuation latency', () async {
        final rig = _Rig.create([_campApp(), _campApp(withGear: true)]);
        final start = await rig.manager.startSession(
          Intent.create(expression: 'track my camping trips'),
        );
        final stopwatch = Stopwatch()..start();
        await rig.manager.continueSession(
          start.sessionId,
          Intent.create(expression: 'also track my gear'),
        );
        stopwatch.stop();
        // ignore: avoid_print
        print('R31 session continuation: ${stopwatch.elapsedMilliseconds}ms');
        await rig.repository.close();
      });

      test(
        'memory: real process RSS delta while running 20 real sessions',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 20; i++) {
            final rig = _Rig.create([_campApp()], dbSuffix: 'mem$i');
            await rig.manager.startSession(
              Intent.create(expression: 'track my camping trips'),
            );
            await rig.repository.close();
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R31 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 20 sessions',
          );
        },
      );
    },
  );
}
