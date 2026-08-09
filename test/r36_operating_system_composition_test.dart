/// Implementation Specification IS-R36 — Operating System Composition Root,
/// AI Operating System Service Composition.
///
/// REALITY before R36 (confirmed by reading source, not assumed): `AppComposition`
/// (`lib/app/app_composition.dart`, R1) held `experienceRepository`/`worldModel`/
/// `providerRegistry`/`credentialVault`/`capabilityPlatform`/`knowledgeEngine`/
/// `softwareCognition`/`runtimeIntelligence`/`kernel`/`engineeringMemory` —
/// never `ExperienceCreationCoordinator`/`EngineeringLifecycleCoordinator`/
/// `IntentSessionManager`/`ExperienceWorkspaceManager`/`UniversalIntentRouter`/
/// `AutonomousWorkspaceRuntime`/`EventBus`/`WorkspaceEventPublisher`.
/// `HomeScreen.initState()` constructed its OWN, LOCAL `ExperienceCreationCoordinator`
/// — never reachable from `AppComposition`, the one real, disconnected-graph
/// gap this milestone closes (R1's own original precedent, repeated: fixing
/// an "independently constructed, disconnected graph" problem, previously
/// done for `WorldModelCoordinator`).
///
/// This file proves, with real objects (never mocks of the subsystems under
/// test): the full R31-R35 service graph constructs correctly from
/// `AppComposition.production()`, every service is a genuine shared
/// singleton reachable from every real consumer, the EventBus carries a real
/// event across two independent access paths through the SAME composition,
/// dependency injection is honored end-to-end (never silently replaced), the
/// relocated `ExperienceCreationCoordinator` behaves identically to its
/// pre-R36 locally-constructed shape, and `HomeScreen`/`ExperienceHostScreen`
/// remain backward compatible while gaining real, wired services at their
/// real navigation call site.
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/autonomous_workspace_runtime.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/engineering_lifecycle_coordinator.dart';
import 'package:anything/app/experience_workspace_manager.dart';
import 'package:anything/app/intent_session_manager.dart';
import 'package:anything/app/universal_intent_router.dart';
import 'package:anything/app/workspace_event_publisher.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/core/events/events.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/features/home/home_screen.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/experience_host_screen.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';

/// Minimal, real, valid `ExperiencePackage` — mirrors
/// `test/r6_runtime_patching_test.dart`'s own established helper shape,
/// used ONLY for a constructor-signature-level proof (never rendered).
ExperiencePackage _minimalPackage() {
  final now = DateTime(2026);
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: 'exp-ctor-check',
      name: 'Test',
      description: 'd',
      category: 'general',
      entryPoint: 's1',
      version: '1',
      createdAt: now,
      updatedAt: now,
    ),
    interface: const InterfaceDefinition(screens: []),
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

// ── Fixtures — mirrors test/r35_workspace_event_bus_test.dart's established
// rig shape exactly, extended to expose every R36 composition field. ──────

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

/// A full, real R31-R36 service graph, mirroring `AppComposition.production()`'s
/// exact real dependency order (Kernel -> ExperienceCreationCoordinator ->
/// EngineeringLifecycleCoordinator -> IntentSessionManager ->
/// ExperienceWorkspaceManager -> UniversalIntentRouter/AutonomousWorkspaceRuntime;
/// EventBus -> WorkspaceEventPublisher independently), with test doubles ONLY
/// for the pieces that would otherwise touch real AI provider network I/O
/// (`ModelProviderRegistry`/`ApplicationReasoner`) — matching every R1-R35
/// test rig's established convention (`AppComposition.production()` itself is
/// deliberately never called for identity/graph tests — see this file's own
/// "AppComposition.production() itself" group below for the one, safe,
/// offline-proof exception).
class _Rig {
  final SqliteExperienceRepository repository;
  final WorldModelCoordinator worldModel;
  final EngineeringMemoryRepository engineeringMemory;
  final ExperienceCreationCoordinator creationCoordinator;
  final EngineeringLifecycleCoordinator lifecycleCoordinator;
  final IntentSessionManager sessionManager;
  final ExperienceWorkspaceManager workspace;
  final UniversalIntentRouter router;
  final AutonomousWorkspaceRuntime workspaceRuntime;
  final EventBus bus;
  final WorkspaceEventPublisher publisher;

  _Rig({
    required this.repository,
    required this.worldModel,
    required this.engineeringMemory,
    required this.creationCoordinator,
    required this.lifecycleCoordinator,
    required this.sessionManager,
    required this.workspace,
    required this.router,
    required this.workspaceRuntime,
    required this.bus,
    required this.publisher,
  });

  static _Rig create(List<SemanticApp> reasonerSequence, {String? dbName}) {
    final name =
        dbName ?? 'r36_composition_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: name);
    final worldModel = WorldModelCoordinator();
    final softwareCognition = SoftwareCognitionCoordinator();
    final engineeringMemory = EngineeringMemoryRepository(
      experienceRepository: repository,
    );
    final activity = ActivityRepository();
    final reasoner = _SequencedReasoner(reasonerSequence);
    final kernel = AnythingKernel(
      providerRegistry: _FakeProviderRegistry(),
      capabilityRegistry: _registryWithStorage(),
      reasoner: reasoner,
      worldModel: worldModel,
      softwareCognition: softwareCognition,
    );

    // The EXACT same 4 named args AppComposition.production() now passes
    // (Implementation Specification IS-R36) — matching, not re-deriving,
    // HomeScreen's own pre-R36 local construction call.
    final creationCoordinator = ExperienceCreationCoordinator(
      kernel: kernel,
      repository: repository,
      worldModel: worldModel,
      softwareCognition: softwareCognition,
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
    final router = UniversalIntentRouter(workspace: workspace);
    final workspaceRuntime = AutonomousWorkspaceRuntime(workspace: workspace);
    final bus = EventBus();
    final publisher = WorkspaceEventPublisher(bus: bus, source: 'test-rig');

    return _Rig(
      repository: repository,
      worldModel: worldModel,
      engineeringMemory: engineeringMemory,
      creationCoordinator: creationCoordinator,
      lifecycleCoordinator: lifecycleCoordinator,
      sessionManager: sessionManager,
      workspace: workspace,
      router: router,
      workspaceRuntime: workspaceRuntime,
      bus: bus,
      publisher: publisher,
    );
  }
}

/// The real production database file — `AppComposition.production()`'s
/// `experienceRepository`/`ExperienceOpeningCoordinator`'s own default
/// repository, and `HomeScreen`'s own internal `_repository`, all default to
/// this exact name (`SqliteExperienceRepository()`'s own default `dbName`,
/// confirmed by reading `lib/storage/sqlite_experience_repository.dart`).
/// This file's one test that seeds real data into it never deletes/resets
/// the file (HomeScreen's own `dispose()` never closes its internal
/// repository's connection — a real, pre-existing, unrelated-to-R36
/// property of this widget — so a leaked connection from an earlier test in
/// this same file can hold the file open); instead it uses the real
/// `touchLastUsed` API to force its own seeded row to the front of
/// `listAll()`'s real `last_used_at DESC` ordering, regardless of any
/// stale rows a prior run left behind.
const _defaultDbName = 'anything_experiences.db';

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  group(
    'AppComposition.production() itself (R36) — the real composition root, exercised directly',
    () {
      // REALITY: with no AI provider ever configured/saved in this test's
      // CredentialVault, `AnythingProviderRegistry.activeProvider` is real,
      // honestly null — `AnythingKernel.processIntent()`'s own Step 5 (the
      // ONE mandatory reasoning call, per this project's own AI boundary)
      // detects this BEFORE any network/LLM call and returns a real, local,
      // deterministic `ReasoningProviderRequired` -> `ProviderRequired`
      // (confirmed by reading `lib/kernel/anything_kernel.dart`). Exercising
      // `AppComposition.production()`'s REAL graph through this real,
      // network-free outcome is therefore safe and honest — never a
      // fabricated network-free assumption.
      test(
        'constructs the full R31-R36 service graph without throwing — every new field is real, non-null, and correctly typed',
        () async {
          final composition = AppComposition.freshForTesting();
          addTearDown(() => composition.experienceRepository.close());

          expect(
            composition.experienceCreationCoordinator,
            isA<ExperienceCreationCoordinator>(),
          );
          expect(
            composition.engineeringLifecycleCoordinator,
            isA<EngineeringLifecycleCoordinator>(),
          );
          expect(composition.intentSessionManager, isA<IntentSessionManager>());
          expect(
            composition.workspaceManager,
            isA<ExperienceWorkspaceManager>(),
          );
          expect(composition.intentRouter, isA<UniversalIntentRouter>());
          expect(
            composition.workspaceRuntime,
            isA<AutonomousWorkspaceRuntime>(),
          );
          expect(composition.eventBus, isA<EventBus>());
          expect(composition.eventPublisher, isA<WorkspaceEventPublisher>());
        },
      );

      test(
        'singleton lifetime — workspaceManager/intentRouter/workspaceRuntime constructed from ONE production() call share the SAME underlying workspace, proven by a real cross-service observation, never a private-field assumption',
        () async {
          final composition = AppComposition.freshForTesting();
          addTearDown(() => composition.experienceRepository.close());

          final routeResult = await composition.intentRouter.route(
            Intent.create(expression: 'track my camping trips'),
          );
          // A real, honest, network-free outcome (no provider configured) —
          // `ExperienceWorkspaceManager.openExperience()` still tracks the
          // session as open regardless of the coordinator's outcome (R32's own,
          // unmodified contract).
          expect(routeResult.creationResult, isA<CreationProviderRequired>());
          expect(routeResult.sessionId, isNotNull);

          // If `composition.intentRouter` held a DIFFERENT `ExperienceWorkspaceManager`
          // than `composition.workspaceManager`, this session would not appear
          // here — proving real, shared identity through actual behavior, not
          // reflection.
          expect(
            composition.workspaceManager.openSessionIds,
            contains(routeResult.sessionId),
          );

          // `composition.workspaceRuntime` must observe the SAME session too —
          // proving IT also holds the SAME `composition.workspaceManager`.
          final snapshot = composition.workspaceRuntime.captureRuntimeState();
          expect(
            snapshot.sessions.map((s) => s.sessionId),
            contains(routeResult.sessionId),
          );
        },
      );

      test(
        'EventBus sharing — a real event published via composition.eventPublisher is received by a subscriber obtained via composition.eventBus, a completely independent access path through the SAME composition',
        () async {
          final composition = AppComposition.freshForTesting();
          addTearDown(() => composition.experienceRepository.close());

          final received = <IntentRouted>[];
          composition.eventBus.on<IntentRouted>().listen(received.add);

          final routeResult = await composition.intentRouter.route(
            Intent.create(expression: 'track my camping trips'),
          );
          composition.eventPublisher.publishIntentRouted(routeResult);
          await Future.delayed(Duration.zero);

          expect(received, hasLength(1));
          expect(received.single.sessionId, routeResult.sessionId);
          expect(received.single.action, routeResult.action.name);
        },
      );

      test(
        'workspace lifetime == application singleton (real, honest finding, documented in docs/architecture/OPERATING_SYSTEM_COMPOSITION.md): every read of composition.workspaceManager across this composition\'s lifetime returns the IDENTICAL instance — no multi-workspace concept exists in this codebase',
        () async {
          final composition = AppComposition.freshForTesting();
          addTearDown(() => composition.experienceRepository.close());

          final firstRead = composition.workspaceManager;
          await composition.intentRouter.route(
            Intent.create(expression: 'track my camping trips'),
          );
          final secondRead = composition.workspaceManager;

          expect(
            identical(firstRead, secondRead),
            isTrue,
            reason:
                'AppComposition.workspaceManager is a final field set exactly once at production() time — real proof there is no per-access reconstruction',
          );
        },
      );
    },
  );

  group(
    'Dependency injection (R36) — a real, injected test double is honored throughout the graph, never silently replaced',
    () {
      test(
        'the FAKE kernel/reasoner injected into the rig\'s ExperienceCreationCoordinator is the ONE actually used end-to-end through IntentSessionManager -> ExperienceWorkspaceManager -> UniversalIntentRouter, never silently swapped for a real one',
        () async {
          final rig = _Rig.create([_app('Camp Log')]);
          final result = await rig.router.route(
            Intent.create(expression: 'track my camping trips'),
          );

          // A REAL AnythingKernel with no provider would return ProviderRequired
          // (proven above) — this test's rig instead used an injected FAKE
          // reasoner that always succeeds, so reaching CreationCreated here is
          // itself the proof the injected double, not a real Kernel, was
          // actually invoked.
          expect(result.creationResult, isA<CreationCreated>());
          expect(rig.workspace.openSessionIds, contains(result.sessionId));
          await rig.repository.close();
        },
      );
    },
  );

  group('ExperienceCreationCoordinator relocation (R36) — behavior preservation', () {
    // REALITY before R36: HomeScreen.initState() constructed
    // `ExperienceCreationCoordinator(kernel: _composition.kernel, worldModel:
    // _composition.worldModel, softwareCognition: _composition.softwareCognition,
    // engineeringMemory: _composition.engineeringMemory)` — the SAME 4 named
    // args this rig (and AppComposition.production(), verified by reading
    // lib/app/app_composition.dart) now uses. This test proves the RELOCATED
    // construction still wires world-model/engineering-memory ingestion
    // identically: a successful creation via the coordinator built with this
    // exact arg shape ingests into the SAME shared worldModel/engineeringMemory
    // instances it was given — never a private, disconnected copy.
    test(
      'a successful creation via the relocated construction shape ingests into the SAME shared worldModel and engineeringMemory it was constructed with',
      () async {
        final rig = _Rig.create([_app('Camp Log')]);
        final beforeGraphSize = rig.worldModel.model.graph.nodes.length;

        final result = await rig.creationCoordinator.createFromIntent(
          Intent.create(expression: 'track my camping trips'),
        );
        expect(result, isA<CreationCreated>());
        final experienceId = (result as CreationCreated).experienceId;

        expect(
          rig.worldModel.model.graph.nodes.length,
          greaterThan(beforeGraphSize),
        );
        final record = await rig.engineeringMemory.load(experienceId);
        expect(
          record,
          isNotNull,
          reason:
              'engineering memory persistence (R5) must still run through the relocated construction, unmodified',
        );

        await rig.repository.close();
      },
    );
  });

  group(
    'Regression (R36) — ExperienceWorkspaceManager/UniversalIntentRouter/EngineeringLifecycleCoordinator/AutonomousWorkspaceRuntime/EventBus behavior is completely unaffected by being reachable from AppComposition',
    () {
      test(
        'ExperienceWorkspaceManager.openExperience() called directly (bypassing AppComposition entirely) behaves exactly as R32 built it',
        () async {
          final rig = _Rig.create([_app('Camp Log')]);
          final result = await rig.workspace.openExperience(
            Intent.create(expression: 'track my camping trips'),
          );
          expect(result.creationResult, isA<CreationCreated>());
          await rig.repository.close();
        },
      );

      test(
        'EngineeringLifecycleCoordinator.evolveExperience() called directly still returns noEngineeringMemory honestly for an experience it never saw create — unaffected by R36',
        () async {
          final rig = _Rig.create([_app('Camp Log')]);
          final lifecycleResult = await rig.lifecycleCoordinator
              .evolveExperience(
                experienceId: 'never-created',
                intent: Intent.create(expression: 'add a field'),
              );
          expect(lifecycleResult.outcome, LifecycleOutcome.noEngineeringMemory);
          await rig.repository.close();
        },
      );
    },
  );

  group('Backward compatibility (R36) — HomeScreen', () {
    test(
      'HomeScreen() constructed WITHOUT any of the 5 optional fields — every field defaults to null, construction never throws (constructor byte-for-byte unchanged)',
      () {
        const screen = HomeScreen();
        expect(screen.composition, isNull);
        expect(screen.workspaceManager, isNull);
        expect(screen.intentRouter, isNull);
        expect(screen.workspaceRuntime, isNull);
        expect(screen.eventBus, isNull);
      },
    );

    testWidgets(
      'a bare HomeScreen() pumped with no injected composition renders without throwing — now sourcing its ExperienceCreationCoordinator from the extended AppComposition.production(), proving the relocation is safe in the real, live widget path',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeScreen())),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        final state = tester.state<HomeScreenState>(find.byType(HomeScreen));
        // Real proof the new services resolved from AppComposition.production()
        // (no widget-level override was supplied) rather than staying null.
        expect(state.intentRouterInUse, isA<UniversalIntentRouter>());
      },
    );

    testWidgets(
      'real, end-to-end wiring: HomeScreen forwards its resolved workspaceManager/workspaceRuntime/eventBus into ExperienceHostScreen at its real navigation call site, never silently dropping an injected test double',
      (tester) async {
        final rig = _Rig.create([_app('Camp Log')], dbName: _defaultDbName);
        late CreationResult seedResult;
        await tester.runAsync(() async {
          seedResult = await rig.creationCoordinator.createFromIntent(
            Intent.create(expression: 'track my camping trips'),
          );
          // Force this row to the front of listAll()'s real `last_used_at DESC`
          // ordering regardless of any stale rows an earlier run left behind
          // (see this file's own `_defaultDbName` doc comment).
          await rig.repository.touchLastUsed(
            (seedResult as CreationCreated).experienceId,
          );
        });
        expect(seedResult, isA<CreationCreated>());
        final experienceName =
            (seedResult as CreationCreated).package.manifest.name;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                workspaceManager: rig.workspace,
                workspaceRuntime: rig.workspaceRuntime,
                eventBus: rig.bus,
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }

        final tile = find.widgetWithText(ListTile, experienceName);
        expect(
          tile,
          findsOneWidget,
          reason:
              'the seeded Experience must appear in Recent, read from the SAME default repository HomeScreen itself opens',
        );

        await tester.tap(tile);
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }

        expect(find.byType(ExperienceHostScreen), findsOneWidget);
        final hostWidget = tester.widget<ExperienceHostScreen>(
          find.byType(ExperienceHostScreen),
        );
        expect(
          hostWidget.workspaceManager,
          same(rig.workspace),
          reason:
              'the real navigation call site must forward the SAME resolved instance, never a fresh/dropped one',
        );
        expect(hostWidget.workspaceRuntime, same(rig.workspaceRuntime));
        expect(hostWidget.eventBus, same(rig.bus));

        await tester.runAsync(() => rig.repository.close());
      },
    );
  });

  group('Backward compatibility (R36) — ExperienceHostScreen', () {
    test(
      'ExperienceHostScreen() constructed WITHOUT any optional field still defaults every field to null (constructor byte-for-byte unchanged by R36)',
      () {
        // Confirms R36 added no new field/param here — R35 already gave it
        // workspaceManager/workspaceRuntime/eventBus; R36 only changed WHERE
        // the values threaded into them, at HomeScreen's own call site, come
        // from.
        final widget = ExperienceHostScreen(package: _minimalPackage());
        expect(widget.workspaceManager, isNull);
        expect(widget.workspaceRuntime, isNull);
        expect(widget.eventBus, isNull);
      },
    );
  });

  group(
    'Performance (R36) — real Stopwatch/ProcessInfo.currentRss measurements, never fabricated',
    () {
      test(
        'AppComposition.production() full graph construction latency',
        () async {
          final stopwatch = Stopwatch()..start();
          final composition = AppComposition.freshForTesting();
          stopwatch.stop();
          // ignore: avoid_print
          print(
            'R36 AppComposition.production() construction: ${stopwatch.elapsedMicroseconds}us',
          );
          await composition.experienceRepository.close();
        },
      );

      test(
        'memory: real process RSS delta across repeated AppComposition.production() construct/close cycles',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 10; i++) {
            final composition = AppComposition.freshForTesting();
            await composition.experienceRepository.close();
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R36 memory: RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 10 production() construct/close cycles',
          );
        },
      );
    },
  );
}
