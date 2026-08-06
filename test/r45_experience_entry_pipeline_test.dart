/// Implementation Specification IS-R45 — Unified Experience Entry Pipeline,
/// AI Operating System Canonical Experience Entry.
///
/// REALITY before R45 (confirmed by reading source): `HomeScreen` had 4 real
/// entry-triggering call sites (Recent list, birth completion, protection
/// resume, the `CreationOpened` reopen branch) all funneling through
/// `ExperienceOpeningCoordinator` directly, then activating with
/// `sessionId: null` always — no workspace session was ever registered for
/// any of them, and none of them participated in scheduling. Only the
/// Workspace Switcher's already-registered-session case (R44) was fully
/// correct. `Intent` has no explicit `experienceId` field, and `CreationOpened`
/// is produced only by the real Kernel's own fuzzy text-matching — routing
/// an explicit, already-known `experienceId` through that path would be
/// unreliable AND would wrongly introduce Kernel/AI involvement into a path
/// that needs none.
///
/// This file proves, with real objects (never mocks of the subsystem under
/// test): `ExperienceWorkspaceManager.openExistingExperience()`/
/// `IntentSessionManager.startSessionForExistingExperience()` (new,
/// additive) register a real session WITHOUT ever touching the Kernel;
/// `ExperienceEntryPipeline.activateExperience()` genuinely registers a
/// workspace session for an already-persisted Experience (the concrete,
/// load-bearing proof this milestone exists for); a second Experience opened
/// this way correctly pauses the first via the real Inactive Runtime policy;
/// the resulting Navigator correctly avoids duplicate `ExperienceHostScreen`
/// creation; `AppComposition` constructs ONE real shared pipeline instance;
/// and every pre-R45 behavior (no pipeline injected) stays unaffected.
library;

import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_activation_manager.dart';
import 'package:anything/app/experience_entry_pipeline.dart';
import 'package:anything/app/experience_opening_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_execution_pipeline.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/universal_intent_router.dart';
import 'package:anything/app/workspace_event_publisher.dart';
import 'package:anything/app/workspace_lifecycle_policy_engine.dart';
import 'package:anything/app/workspace_runtime_supervisor.dart';
import 'package:anything/app/workspace_scheduling_engine.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/core/events/events.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/features/experiences/experiences_screen.dart';
import 'package:anything/features/home/home_screen.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/runtime/experience_runtime_controller.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures — mirrors test/r44_experience_activation_manager_test.dart's /
// test/r43_workspace_experience_switcher_test.dart's established shapes
// exactly. ──────────────────────────────────────────────────────────────

SemanticApp _app(String name) => SemanticApp(
  name: name,
  purpose: 'Track $name',
  entities: [SemanticEntity(id: 'trip', name: 'Trip', displayField: 'title', fields: const [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)])],
  requiredCapabilities: const ['storage'],
);

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(id: 'storage', version: '1.0.0', name: 'Storage', description: 'Local storage', category: CapabilityCategory.storage, inputContract: 'data', outputContract: 'stored data'),
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

/// A real reasoner that counts every real call — the concrete, load-bearing
/// proof `activateExperience()`/`openExistingExperience()` never touch the
/// Kernel: any test asserting `reasoner.calls` stays at its pre-activation
/// value after an `EntryByExperienceId`-style call proves this directly,
/// never by assumption.
class _CountingReasoner implements ApplicationReasoner {
  final List<SemanticApp> apps;
  int calls = 0;
  _CountingReasoner(this.apps);

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    final app = apps[calls < apps.length ? calls : apps.length - 1];
    calls++;
    return ReasoningReady(semanticApp: app);
  }
}

class _Rig {
  final SqliteExperienceRepository repository;
  final ExperienceCreationCoordinator creationCoordinator;
  final ExperienceWorkspaceManager workspace;
  final AutonomousWorkspaceRuntime workspaceRuntime;
  final WorkspaceRuntimeSupervisor supervisor;
  final WorkspaceSchedulingEngine scheduler;
  final ExperienceActivationManager activationManager;
  final ExperienceEntryPipeline entryPipeline;
  final _CountingReasoner reasoner;

  _Rig({
    required this.repository,
    required this.creationCoordinator,
    required this.workspace,
    required this.workspaceRuntime,
    required this.supervisor,
    required this.scheduler,
    required this.activationManager,
    required this.entryPipeline,
    required this.reasoner,
  });

  static Future<_Rig> create(List<SemanticApp> reasonerSequence, {String? dbName}) async {
    final name = dbName ?? 'r45_entry_pipeline_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: name);
    final engineeringMemory = EngineeringMemoryRepository(experienceRepository: repository);
    final activity = ActivityRepository();
    final reasoner = _CountingReasoner(reasonerSequence);
    final kernel = AnythingKernel(providerRegistry: _FakeProviderRegistry(), capabilityRegistry: _registryWithStorage(), reasoner: reasoner);

    final creationCoordinator = ExperienceCreationCoordinator(kernel: kernel, repository: repository, engineeringMemory: engineeringMemory);
    final lifecycleCoordinator = EngineeringLifecycleCoordinator(kernel: kernel, engineeringMemory: engineeringMemory, repository: repository);
    final sessionManager = IntentSessionManager(creationCoordinator: creationCoordinator, lifecycleCoordinator: lifecycleCoordinator, engineeringMemory: engineeringMemory, activity: activity);
    final workspace = ExperienceWorkspaceManager(sessionManager: sessionManager, activity: activity);
    final workspaceRuntime = AutonomousWorkspaceRuntime(workspace: workspace);
    final supervisor = WorkspaceRuntimeSupervisor();
    const policyEngine = WorkspaceLifecyclePolicyEngine();
    final scheduler = WorkspaceSchedulingEngine(workspaceRuntime: workspaceRuntime, supervisor: supervisor, policyEngine: policyEngine, workspace: workspace);
    final activationManager = ExperienceActivationManager(scheduler: scheduler);
    final intentExecutionPipeline = IntentExecutionPipeline(
      router: UniversalIntentRouter(workspace: workspace),
      eventPublisher: WorkspaceEventPublisher(bus: EventBus()),
    );
    final entryPipeline = ExperienceEntryPipeline(
      intentExecutionPipeline: intentExecutionPipeline,
      openingCoordinator: ExperienceOpeningCoordinator(repository: repository, activity: activity),
      activationManager: activationManager,
      workspaceManager: workspace,
      engineeringMemory: engineeringMemory,
      workspaceRuntime: workspaceRuntime,
      runtimeSupervisor: supervisor,
      scheduler: scheduler,
    );

    return _Rig(
      repository: repository,
      creationCoordinator: creationCoordinator,
      workspace: workspace,
      workspaceRuntime: workspaceRuntime,
      supervisor: supervisor,
      scheduler: scheduler,
      activationManager: activationManager,
      entryPipeline: entryPipeline,
      reasoner: reasoner,
    );
  }

  /// Opens a real, NEW workspace session AND registers a real, started
  /// controller for it with [supervisor] — mirrors
  /// test/r44_experience_activation_manager_test.dart's own
  /// `openAndRegister()`.
  Future<String> openAndRegister(String expression) async {
    final result = await workspace.openExperience(Intent.create(expression: expression));
    final experienceId = (result.creationResult as CreationCreated).experienceId;
    final controller = ExperienceRuntimeController(runtime: AnythingRuntime(), workspace: workspace, experienceId: experienceId);
    await controller.start(_runnablePackage(experienceId: experienceId));
    supervisor.register(result.sessionId, controller, experienceId: experienceId);
    return result.sessionId;
  }

  /// Seeds a real, PERSISTED Experience via `ExperienceCreationCoordinator`
  /// directly — bypassing `workspace`/`supervisor` entirely, simulating an
  /// Experience created in a PAST session that is now just sitting in the
  /// database, exactly like a real "Recent" list entry: known to storage,
  /// but not tracked as an open workspace session in THIS process.
  Future<String> seedPersistedExperience(String expression) async {
    final result = await creationCoordinator.createFromIntent(Intent.create(expression: expression));
    final experienceId = (result as CreationCreated).experienceId;
    await repository.touchLastUsed(experienceId);
    return experienceId;
  }
}

/// Minimal, real `ExperiencePackage` that ACTUALLY SUCCEEDS in
/// `AnythingRuntime.openExperience()`. Mirrors
/// test/r38_experience_runtime_controller_test.dart's own `_runnablePackage()`.
ExperiencePackage _runnablePackage({String experienceId = 'exp-1'}) {
  final now = DateTime(2026);
  const screens = [InterfaceScreen(id: 's1', title: 'Home', children: [InterfaceNode(type: 'text', id: 'n1', properties: {'text': 'Hi'})])];
  return ExperiencePackage(
    manifest: ExperienceManifest(experienceId: experienceId, name: 'Test', description: 'd', category: 'general', entryPoint: 's1', version: '1', createdAt: now, updatedAt: now),
    interface: const InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    capabilityDeclarations: const [],
    provenance: const PackageProvenance(creationEngineVersion: 'test', specVersion: 1, planVersion: 1),
    integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
  );
}

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group('Shared pipeline construction (R45)', () {
    test('AppComposition.production().experienceEntryPipeline is a real, non-null ExperienceEntryPipeline; two reads return the IDENTICAL instance', () async {
      final composition = AppComposition.production();
      addTearDown(() => composition.experienceRepository.close());

      expect(composition.experienceEntryPipeline, isA<ExperienceEntryPipeline>());
      final firstRead = composition.experienceEntryPipeline;
      final secondRead = composition.experienceEntryPipeline;
      expect(identical(firstRead, secondRead), isTrue, reason: 'AppComposition.experienceEntryPipeline is a final field set exactly once at production() time — matches R44\'s own singleton proof for experienceActivationManager');
    });
  });

  group('Workspace registration (R45) — new additive methods, Kernel-free', () {
    test('ExperienceWorkspaceManager.openExistingExperience()/IntentSessionManager.startSessionForExistingExperience() register a real session WITHOUT ever touching the Kernel/reasoner', () async {
      final rig = await _Rig.create([_app('Camp Log')]);
      final experienceId = await rig.seedPersistedExperience('track my camping trips');
      expect(rig.reasoner.calls, 1, reason: 'one real Kernel call for the seed itself');

      final result = await rig.workspace.openExistingExperience(experienceId: experienceId, experienceName: 'Camp Log');

      expect(rig.reasoner.calls, 1, reason: 'openExistingExperience() must never reach the Kernel — the reasoner call count must not have grown');
      expect(result.creationResult, isA<CreationOpened>(), reason: 'reuses the real, existing CreationOpened shape — no new result type');
      expect(rig.workspace.openSessionIds, contains(result.sessionId));
      expect(rig.workspace.sessionForExperience(experienceId)?.sessionId, result.sessionId);

      await rig.repository.close();
    });
  });

  group('Recent flow (R45) — the concrete, load-bearing proof this milestone exists for', () {
    testWidgets('activateExperience() for an already-persisted, not-yet-open Experience registers a real NEW workspace session — which never happened before this milestone', (tester) async {
      late _Rig rig;
      late String experienceId;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
        experienceId = await rig.seedPersistedExperience('track my camping trips');
      });
      expect(rig.workspace.openSessionIds, isEmpty, reason: 'the seed alone must not have registered any workspace session — the real pre-R45 gap');

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()));

      final callsBeforeActivate = rig.reasoner.calls;
      unawaited(rig.entryPipeline.activateExperience(navigatorKey.currentState!, experienceId));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();

      expect(rig.reasoner.calls, callsBeforeActivate, reason: 'activateExperience() must never touch the Kernel/reasoner — this path resolves identity by explicit id, never by intent disambiguation');
      expect(rig.workspace.openSessionIds, isNotEmpty, reason: 'a real, NEW workspace session must now be registered — the concrete gap this milestone closes');
      expect(rig.workspace.sessionForExperience(experienceId), isNotNull);
      expect(find.byType(ExperienceHostScreen), findsOneWidget);

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Scheduler participation (R45)', () {
    testWidgets('opening a SECOND Experience via activateExperience() while a first is active correctly pauses the first via the real Inactive Runtime policy', (tester) async {
      late _Rig rig;
      late String experienceIdA;
      late String experienceIdB;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
        experienceIdA = await rig.seedPersistedExperience('track my camping trips');
        experienceIdB = await rig.seedPersistedExperience('track my book club');
      });

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()));

      unawaited(rig.entryPipeline.activateExperience(navigatorKey.currentState!, experienceIdA));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();

      final sessionA = rig.workspace.sessionForExperience(experienceIdA)!.sessionId;
      expect(rig.supervisor.lookup(sessionA)!.status, RuntimeStatus.running);

      unawaited(rig.entryPipeline.activateExperience(navigatorKey.currentState!, experienceIdB));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();

      final sessionB = rig.workspace.sessionForExperience(experienceIdB)!.sessionId;
      expect(rig.workspace.activeSessionId, sessionB, reason: 'B must be the real, new active session');
      expect(rig.supervisor.lookup(sessionB)!.status, RuntimeStatus.running);
      expect(rig.supervisor.lookup(sessionA)!.status, RuntimeStatus.paused, reason: 'A must have been paused via the real Inactive Runtime policy — proving this entry path genuinely participates in scheduling, not just workspace bookkeeping');

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Activation participation (R45) — no duplicate ExperienceHostScreen creation', () {
    testWidgets('re-activating the SAME already-open Experience via activateExperience() never creates a duplicate ExperienceHostScreen', (tester) async {
      late _Rig rig;
      late String experienceId;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
        experienceId = await rig.seedPersistedExperience('track my camping trips');
      });

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()));

      unawaited(rig.entryPipeline.activateExperience(navigatorKey.currentState!, experienceId));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
      expect(find.byType(ExperienceHostScreen), findsOneWidget);

      // Push an unrelated route on top first — a real proof the second
      // activation's popUntil must search past it, not just no-op by luck.
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const SizedBox(key: ValueKey('unrelated'))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unrelated')), findsOneWidget);

      final sessionCountBefore = rig.supervisor.registrations.length;
      unawaited(rig.entryPipeline.activateExperience(navigatorKey.currentState!, experienceId));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'must never throw WorkspaceRuntimeSupervisor.register()\'s duplicate StateError');
      expect(find.byType(ExperienceHostScreen), findsOneWidget, reason: 'still exactly ONE — the second activation must have revealed the existing route, never pushed a duplicate');
      expect(find.byKey(const ValueKey('unrelated')), findsNothing, reason: 'popUntil must have popped the unrelated route to reveal the tracked one');
      expect(rig.supervisor.registrations.length, sessionCountBefore, reason: 'never duplicated');

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Create flow (R45) — Intent-driven path unchanged', () {
    // A plain test(), never testWidgets() — this test pumps no widget, and
    // real SQLite/Kernel I/O called directly inside a testWidgets callback
    // hangs forever in Flutter's FakeAsync zone unless wrapped in
    // tester.runAsync() (test/r40_workspace_runtime_supervisor_test.dart's
    // own doc comment documents this the hard way) — the simpler, correct
    // fix for non-widget work is to just not use testWidgets at all.
    test('submitIntent() reaches the real IntentExecutionPipeline/ExperienceCreationCoordinator chain exactly as before, registering a real workspace session', () async {
      final rig = await _Rig.create([_app('Camp Log')]);

      final result = await rig.entryPipeline.submitIntent(Intent.create(expression: 'track my camping trips'));

      expect(result.creationResult, isA<CreationCreated>());
      expect(result.sessionId, isNotNull);
      expect(rig.workspace.openSessionIds, contains(result.sessionId), reason: 'submitIntent() reaches the real, unmodified IntentExecutionPipeline, which already registers a real workspace session (since R37)');

      await rig.repository.close();
    });

    testWidgets('a real, live HomeScreen "submit something, birth sequence, land in the new app" flow is unaffected by R45', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HomeScreen())));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      // The always-visible "Calculator" quick-suggestion chip drives the
      // exact same real `_createExperience()` a typed-and-submitted
      // expression would — a simpler, always-rendered interaction than
      // typing + tapping the conditionally-shown submit button (whose own
      // visibility toggle is a real, pre-existing, R45-unrelated UI
      // reactivity quirk, not something this test exists to exercise).
      await tester.tap(find.text('Calculator'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }

      // Real, honest outcome without a configured AI provider: the birth
      // sequence never completes (CreationProviderRequired), matching every
      // pre-R45 HomeScreen test's own established, real, offline behavior —
      // this test's own proof is simply that nothing throws and the screen
      // stays coherent, not a fabricated successful creation.
      expect(tester.takeException(), isNull);
    });
  });

  group('Switcher flow (R45) — regression-proof, not a new capability', () {
    testWidgets('EntryBySession-equivalent (Workspace Switcher) behaves identically to R44\'s own already-correct activateRunningSession() behavior', (tester) async {
      late _Rig rig;
      late String sessionId;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
        sessionId = await rig.openAndRegister('track my camping trips');
      });

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()));
      final controller = rig.supervisor.lookup(sessionId)!;

      unawaited(rig.entryPipeline.activateRunningSession(
        navigatorKey.currentState!,
        sessionId,
        controller: controller,
        package: controller.currentSession!.package,
        experienceId: controller.experienceId,
      ));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();

      expect(find.byType(ExperienceHostScreen), findsOneWidget);
      final hostWidget = tester.widget<ExperienceHostScreen>(find.byType(ExperienceHostScreen));
      expect(hostWidget.runtime, same(controller.runtime), reason: 'reuses the SAME real, already-running runtime — never a freshly-constructed one');
      expect(hostWidget.runtimeSupervisor, isNull, reason: 'deliberately omitted — the controller is already registered, passing the supervisor would throw the duplicate StateError');

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Restore flow (R45) — honest scope', () {
    test('activateExperience() (loading a real, persisted package by known experienceId) is itself the real restore mechanism — no separate snapshot-specific restore trigger exists in production, and none is fabricated here', () async {
      final rig = await _Rig.create([_app('Camp Log')]);
      final experienceId = await rig.seedPersistedExperience('track my camping trips');

      // Real, honest proof: the SAME real ExperienceOpeningCoordinator load
      // path `activateExperience()` uses for "Recent" is what "restoring" a
      // previously-closed Experience means today — there is no separate,
      // deeper snapshot-based restore (ExperienceRuntimeController.restore()
      // exists, R38, but has no real production trigger anywhere in lib/,
      // confirmed by grep before writing this milestone's code).
      final result = await ExperienceOpeningCoordinator(repository: rig.repository).openExperience(experienceId);
      expect(result, isA<OpenReady>());

      await rig.repository.close();
    });
  });

  group('Regression (R45) — WorkspaceSchedulingEngine/WorkspaceRuntimeSupervisor/WorkspaceLifecyclePolicyEngine/ExperienceRuntimeController/AnythingRuntime/UniversalIntentRouter unaffected', () {
    test('IntentSessionManager.startSession()/ExperienceWorkspaceManager.openExperience() (the pre-existing Intent-driven methods) called directly still behave exactly as R31/R32 built them', () async {
      final rig = await _Rig.create([_app('Camp Log')]);
      final result = await rig.workspace.openExperience(Intent.create(expression: 'track my camping trips'));
      expect(result.creationResult, isA<CreationCreated>());
      expect(rig.workspace.openSessionIds, contains(result.sessionId));
      await rig.repository.close();
    });

    test('WorkspaceSchedulingEngine/WorkspaceRuntimeSupervisor used directly, bypassing the pipeline entirely, still behave exactly as R40/R42 built them', () async {
      final rig = await _Rig.create([_app('Camp Log'), _app('Book Club')]);
      final sessionA = await rig.openAndRegister('track my camping trips');
      final sessionB = await rig.openAndRegister('track my book club');

      await rig.scheduler.scheduleForeground(sessionB);
      expect(rig.workspace.activeSessionId, sessionB);
      expect(rig.supervisor.lookup(sessionA)!.status, RuntimeStatus.paused);

      await rig.repository.close();
    });
  });

  // ── My Apps library (`ExperiencesScreen`) — the real production entry
  // surface R45's first pass MISSED entirely. ────────────────────────────
  //
  // REALITY (found by re-auditing every `Navigator.push`/`ExperienceHostScreen`
  // call site in lib/ AFTER R45 shipped): `ExperiencesScreen` is a real,
  // live production screen — the "My Apps" tab, constructed unconditionally
  // in `AnythingAppShell._screenBuilders` (`lib/app/app_shell.dart`). All
  // THREE of its Experience-opening paths (library tap, protection resume
  // "current time", protection resume "custom time") called
  // `ExperienceOpeningCoordinator` directly — through their OWN privately
  // constructed instance, not even the shared one — and then raw-
  // `Navigator.push`ed `ExperienceHostScreen`, registering NO workspace
  // session, reaching NO scheduler, NO runtime supervisor and NO
  // `ExperienceActivationManager`. That is precisely the bypass this
  // milestone exists to eliminate, so R45's own success criterion ("every
  // production experience-opening path flows through ONE pipeline") was not
  // actually met until these paths were routed through the pipeline too.
  //
  // R44's `ExperienceActivationManager` doc comment asserting `HomeScreen`
  // is "the ONE and ONLY real production call site that ever pushes
  // `ExperienceHostScreen` anywhere in this codebase (confirmed by grep)"
  // was, in reality, never true — `experiences_screen.dart` pushed it in
  // three places the whole time.
  group('My Apps library flow (R45) — ExperiencesScreen, the production entry surface the first pass missed', () {
    testWidgets('tapping a real Experience in the real My Apps library registers a real workspace session through the unified pipeline — this path previously registered nothing at all', (tester) async {
      late _Rig rig;
      late String experienceId;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
        experienceId = await rig.seedPersistedExperience('track my camping trips');
      });
      expect(rig.workspace.openSessionIds, isEmpty, reason: 'the seed alone must not have registered any workspace session');

      await tester.pumpWidget(
        MaterialApp(home: ExperiencesScreen(repository: rig.repository, entryPipeline: rig.entryPipeline)),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(find.text('Camp Log'), findsOneWidget, reason: 'the real, persisted Experience must actually be listed in the real library before we can tap it');

      final callsBeforeTap = rig.reasoner.calls;
      await tester.tap(find.text('Camp Log'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(rig.reasoner.calls, callsBeforeTap, reason: 'opening from the library resolves identity by explicit id — it must never reach the Kernel/reasoner, and must add no second AI boundary');
      expect(rig.workspace.openSessionIds, isNotEmpty, reason: 'the real, load-bearing proof: the My Apps tap now genuinely registers a workspace session, which it never did before');
      expect(rig.workspace.sessionForExperience(experienceId), isNotNull);

      final sessionId = rig.workspace.sessionForExperience(experienceId)!.sessionId;
      expect(rig.supervisor.lookup(sessionId), isNotNull, reason: 'real runtime supervision — the raw Navigator.push path supervised nothing');
      expect(rig.supervisor.lookup(sessionId)!.status, RuntimeStatus.running, reason: 'real scheduler participation via the same canonical activation path every other entry source uses');
      expect(rig.activationManager.existingRouteFor(sessionId), isNotNull, reason: 'the route must be tracked by the ONE ExperienceActivationManager — proving this is real activation, not an untracked raw push');
      expect(find.byType(ExperienceHostScreen), findsOneWidget);

      await tester.runAsync(() => rig.repository.close());
    });

    testWidgets('re-tapping the SAME already-open Experience in the library never creates a duplicate ExperienceHostScreen', (tester) async {
      late _Rig rig;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
        await rig.seedPersistedExperience('track my camping trips');
      });

      await tester.pumpWidget(
        MaterialApp(home: ExperiencesScreen(repository: rig.repository, entryPipeline: rig.entryPipeline)),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      await tester.tap(find.text('Camp Log'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(find.byType(ExperienceHostScreen), findsOneWidget);

      // Pop back to the library and open the very same Experience again.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      await tester.tap(find.text('Camp Log'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(find.byType(ExperienceHostScreen), findsOneWidget, reason: 'exactly one host screen — real duplicate-prevention through the canonical activation manager');

      await tester.runAsync(() => rig.repository.close());
    });
  });

  group('Backward compatibility (R45)', () {
    test('HomeScreen() constructed WITHOUT entryPipeline defaults it to null (constructor otherwise unchanged)', () {
      const screen = HomeScreen();
      expect(screen.entryPipeline, isNull);
    });

    test('ExperiencesScreen() constructed WITHOUT entryPipeline defaults it to null (constructor otherwise unchanged)', () {
      const screen = ExperiencesScreen();
      expect(screen.entryPipeline, isNull);
    });

    testWidgets('a bare HomeScreen() pumped with no injected entryPipeline renders without throwing — now sourcing its pipeline from individually-resolved fields/AppComposition.production()', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HomeScreen())));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bare ExperiencesScreen() pumped with no injected entryPipeline renders without throwing — sourcing the ONE shared pipeline from AppComposition.production()', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExperiencesScreen())));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.byType(ExperiencesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Performance (R45) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated', () {
    testWidgets('entry latency: Recent flow (activateExperience) for a new session', (tester) async {
      late _Rig rig;
      late String experienceId;
      await tester.runAsync(() async {
        rig = await _Rig.create([_app('Camp Log')]);
        experienceId = await rig.seedPersistedExperience('track my camping trips');
      });
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()));

      final sw = Stopwatch()..start();
      unawaited(rig.entryPipeline.activateExperience(navigatorKey.currentState!, experienceId));
      await tester.pump();
      sw.stop();
      // ignore: avoid_print
      print('R45 activateExperience() new session (fire to first pump): ${sw.elapsedMicroseconds}us');

      await tester.runAsync(() => rig.repository.close());
    });

    test('workspace registration latency: openExistingExperience()', () async {
      final rig = await _Rig.create([_app('Camp Log')]);
      final experienceId = await rig.seedPersistedExperience('track my camping trips');

      final sw = Stopwatch()..start();
      await rig.workspace.openExistingExperience(experienceId: experienceId, experienceName: 'Camp Log');
      sw.stop();
      // ignore: avoid_print
      print('R45 openExistingExperience(): ${sw.elapsedMicroseconds}us');

      await rig.repository.close();
    });

    test('memory: real process RSS delta across repeated openExistingExperience() cycles', () async {
      final rssBefore = ProcessInfo.currentRss;
      final rig = await _Rig.create(List.generate(10, (i) => _app('App $i')));
      for (var i = 0; i < 10; i++) {
        final experienceId = await rig.seedPersistedExperience('track app $i');
        await rig.workspace.openExistingExperience(experienceId: experienceId, experienceName: 'App $i');
      }
      final rssAfter = ProcessInfo.currentRss;
      // ignore: avoid_print
      print('R45 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 openExistingExperience() cycles');

      await rig.repository.close();
    });
  });
}
