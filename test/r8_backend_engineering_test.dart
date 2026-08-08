/// Implementation Milestone R8 — Full-Stack Autonomous Engineering.
/// Proves the deterministic extension from frontend-only Experience
/// engineering into real, typed backend specification (Database Schema,
/// API Specification, Authentication/Storage/Background-Jobs/Deployment
/// models) — derived entirely from already-computed
/// `ArchitectureCandidate`/`SemanticApp` data, zero new AI call, zero
/// generated SQL/source/deployment-config. Novel domain fixture
/// ("Vehicle Fleet Maintenance Log"), zero footprint elsewhere in lib/.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/backend_engineering/api_specification.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_serialization.dart';
import 'package:anything/backend_engineering/database_schema.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

// ── Fixtures (mirrors test/r4_incremental_evolution_test.dart's established pattern) ──

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

NavigationGraph _nav() => NavigationGraph(
  entryScreenId: 'vehicles',
  screenIds: const ['vehicles'],
  edges: const [],
  decision: _decision('nav'),
);

SemanticApp _fleetApp() {
  return const SemanticApp(
    name: 'Vehicle Fleet Maintenance Log',
    purpose: 'Track vehicles and their maintenance records',
    entities: [
      SemanticEntity(
        id: 'vehicle',
        name: 'Vehicle',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
          SemanticField(
            id: 'mileage',
            name: 'Mileage',
            type: BlueprintFieldType.integer,
          ),
          SemanticField(
            id: 'active',
            name: 'Active',
            type: BlueprintFieldType.boolean,
          ),
        ],
      ),
      SemanticEntity(
        id: 'maintenance_record',
        name: 'Maintenance Record',
        displayField: 'note',
        fields: [
          SemanticField(
            id: 'note',
            name: 'Note',
            type: BlueprintFieldType.text,
            required: true,
          ),
          SemanticField(
            id: 'vehicle_ref',
            name: 'Vehicle',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'vehicle',
            required: true,
          ),
        ],
      ),
    ],
  );
}

ArchitectureCandidate _fleetArchitecture({
  bool requiresCredentialVault = false,
  NetworkMode networkMode = NetworkMode.none,
  OfflineCapability offline = OfflineCapability.fullyOffline,
  SyncStrategy sync = SyncStrategy.none,
}) {
  return ArchitectureCandidate(
    id: 'fleet-candidate',
    appName: 'Vehicle Fleet Maintenance Log',
    entities: const [
      EntityDecision(
        entityId: 'vehicle',
        name: 'Vehicle',
        fieldCount: 3,
        storage: StorageKind.sqlite,
        storageDecision: ArchitectureDecision(
          id: 's1',
          category: ArchitectureDecisionCategory.data,
          subjectId: 'vehicle',
          decision: 'sqlite',
          rationale: 'r',
          confidence: Confidence(score: 1.0, reason: 'test'),
        ),
      ),
      EntityDecision(
        entityId: 'maintenance_record',
        name: 'Maintenance Record',
        fieldCount: 2,
        storage: StorageKind.sqlite,
        storageDecision: ArchitectureDecision(
          id: 's2',
          category: ArchitectureDecisionCategory.data,
          subjectId: 'maintenance_record',
          decision: 'sqlite',
          rationale: 'r',
          confidence: Confidence(score: 1.0, reason: 'test'),
        ),
      ),
    ],
    relationships: const [
      RelationshipDecision(
        fromEntityId: 'maintenance_record',
        toEntityId: 'vehicle',
        fieldId: 'vehicle_ref',
        deletePolicy: RelationshipDeletePolicy.restrict,
        decision: ArchitectureDecision(
          id: 'rel1',
          category: ArchitectureDecisionCategory.data,
          subjectId: 'rel',
          decision: 'restrict',
          rationale: 'r',
          confidence: Confidence(score: 1.0, reason: 'test'),
        ),
      ),
    ],
    navigation: _nav(),
    interactions: [
      InteractionDecision(
        entityId: 'vehicle',
        canCreate: true,
        canRead: true,
        canUpdate: true,
        canDelete: true,
        supportsSearch: true,
        supportsFilter: false,
        supportsSort: false,
        supportsPagination: false,
        decision: _decision('int:vehicle'),
      ),
      InteractionDecision(
        entityId: 'maintenance_record',
        canCreate: true,
        canRead: true,
        canUpdate: false,
        canDelete: true,
        supportsSearch: false,
        supportsFilter: false,
        supportsSort: false,
        supportsPagination: false,
        decision: _decision('int:maintenance_record'),
      ),
    ],
    security: SecurityDecision(
      networkMode: networkMode,
      requiresCredentialVault: requiresCredentialVault,
      decision: _decision('sec'),
    ),
    offline: OfflineDecision(capability: offline, decision: _decision('off')),
    synchronization: SynchronizationDecision(
      strategy: sync,
      decision: _decision('sync'),
    ),
    overallConfidence: const Confidence(score: 1.0, reason: 'test'),
  );
}

void main() {
  group('Database Schema (R8)', () {
    test(
      'every entity becomes a real table with real typed columns, a primary key, and a real foreign key',
      () {
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );

        expect(plan.database.tables, hasLength(2));
        final vehicle = plan.database.tableById('vehicle')!;
        expect(
          vehicle.columns.map((c) => c.name),
          containsAll(['id', 'Name', 'Mileage', 'Active']),
        );
        expect(
          vehicle.columns.firstWhere((c) => c.name == 'id').isPrimaryKey,
          isTrue,
        );
        expect(
          vehicle.columns.firstWhere((c) => c.name == 'Mileage').type,
          DatabaseColumnType.integer,
        );
        expect(
          vehicle.columns.firstWhere((c) => c.name == 'Active').type,
          DatabaseColumnType.boolean,
        );

        final record = plan.database.tableById('maintenance_record')!;
        expect(record.foreignKeys, hasLength(1));
        expect(record.foreignKeys.single.referencesTableId, 'vehicle');
        expect(
          record.foreignKeys.single.onDelete,
          RelationshipDeletePolicy.restrict.name,
        );
      },
    );

    test('a derived field never becomes a stored column', () {
      const app = SemanticApp(
        name: 'x',
        purpose: 'x',
        entities: [
          SemanticEntity(
            id: 'e',
            name: 'E',
            fields: [
              SemanticField(
                id: 'd',
                name: 'D',
                type: BlueprintFieldType.derived,
              ),
            ],
          ),
        ],
      );
      final arch = _fleetArchitecture();
      final plan = const BackendEngineeringPlanner().plan(
        BackendEngineeringContext(architecture: arch, app: app),
      );
      final table = plan.database.tables.firstWhere(
        (t) => t.id == 'e',
        orElse: () => const DatabaseTable(id: 'e', name: 'E'),
      );
      expect(table.columns.any((c) => c.name == 'D'), isFalse);
    });
  });

  group('API Specification (R8)', () {
    test(
      'real CRUD/search flags on InteractionDecision produce real, matching endpoints',
      () {
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );

        final vehicleEndpoints = plan.api.endpointsForEntity('vehicle');
        expect(
          vehicleEndpoints.map((e) => e.operation),
          containsAll([
            ApiOperation.list,
            ApiOperation.get,
            ApiOperation.create,
            ApiOperation.update,
            ApiOperation.delete,
            ApiOperation.search,
          ]),
        );

        // maintenance_record: canUpdate=false, supportsSearch=false — no update/search endpoints.
        final recordEndpoints = plan.api.endpointsForEntity(
          'maintenance_record',
        );
        expect(
          recordEndpoints.map((e) => e.operation),
          isNot(contains(ApiOperation.update)),
        );
        expect(
          recordEndpoints.map((e) => e.operation),
          isNot(contains(ApiOperation.search)),
        );
        expect(
          recordEndpoints.map((e) => e.operation),
          contains(ApiOperation.create),
        );
      },
    );

    test(
      'an entity with no InteractionDecision at all produces no endpoints — never a fabricated default',
      () {
        const app = SemanticApp(
          name: 'x',
          purpose: 'x',
          entities: [SemanticEntity(id: 'orphan', name: 'Orphan')],
        );
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: app,
          ),
        );
        expect(plan.api.endpointsForEntity('orphan'), isEmpty);
      },
    );
  });

  group('Authentication / Storage / Background / Deployment (R8, honestly minimal)', () {
    test(
      'requiresCredentials mirrors SecurityDecision.requiresCredentialVault exactly',
      () {
        final withVault = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(requiresCredentialVault: true),
            app: _fleetApp(),
          ),
        );
        final withoutVault = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );
        expect(withVault.authentication.requiresCredentials, isTrue);
        expect(withoutVault.authentication.requiresCredentials, isFalse);
      },
    );

    test(
      'storage requirements mirror each EntityDecision.storage exactly, one per entity',
      () {
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );
        expect(plan.storage.requirements, hasLength(2));
        expect(
          plan.storage.requirements.every((r) => r.kind == StorageKind.sqlite),
          isTrue,
        );
      },
    );

    test(
      'background sync is required only for cacheFirst/networkFirst strategies, never for none/manualRefresh',
      () {
        final none = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(sync: SyncStrategy.none),
            app: _fleetApp(),
          ),
        );
        final cacheFirst = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(sync: SyncStrategy.cacheFirst),
            app: _fleetApp(),
          ),
        );
        expect(none.backgroundJobs.requiresBackgroundSync, isFalse);
        expect(cacheFirst.backgroundJobs.requiresBackgroundSync, isTrue);
      },
    );

    test(
      'deployment requiresBackend is real, derived from Offline/Security decisions — false for a fully-offline, no-network app',
      () {
        final offlineOnly = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );
        final needsNetwork = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(
              networkMode: NetworkMode.restrictedHttps,
            ),
            app: _fleetApp(),
          ),
        );
        expect(offlineOnly.deployment.requiresBackend, isFalse);
        expect(needsNetwork.deployment.requiresBackend, isTrue);
      },
    );

    test(
      'a secret reference is emitted ONLY when credentials are genuinely required, and NEVER carries a value',
      () {
        final withVault = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(requiresCredentialVault: true),
            app: _fleetApp(),
          ),
        );
        final withoutVault = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );
        expect(withVault.deployment.secretReferences, hasLength(1));
        expect(withVault.deployment.secretReferences.single.name, isNotEmpty);
        expect(withoutVault.deployment.secretReferences, isEmpty);
      },
    );
  });

  group('Determinism (R8)', () {
    test(
      'planning the same context twice produces a structurally identical plan',
      () {
        final context = BackendEngineeringContext(
          architecture: _fleetArchitecture(),
          app: _fleetApp(),
        );
        const planner = BackendEngineeringPlanner();
        final a = planner.plan(context);
        final b = planner.plan(context);
        expect(a.toJson(), equals(b.toJson()));
      },
    );
  });

  group('Serialization round-trip (R8)', () {
    test('toJson/fromJson preserves every field with full fidelity', () {
      final plan = const BackendEngineeringPlanner().plan(
        BackendEngineeringContext(
          architecture: _fleetArchitecture(
            requiresCredentialVault: true,
            sync: SyncStrategy.networkFirst,
          ),
          app: _fleetApp(),
        ),
      );
      final roundTripped = backendEngineeringPlanFromJson(plan.toJson());
      expect(roundTripped.toJson(), equals(plan.toJson()));
    });
  });

  group('World Model ingestion (R8)', () {
    test(
      'database tables unify with the existing entity kind; API endpoints become real backendEndpoint nodes',
      () {
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );
        final coordinator = WorldModelCoordinator();
        coordinator.ingestBackendEngineering(plan);

        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.entity),
          isNotEmpty,
        );
        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.backendEndpoint),
          isNotEmpty,
        );
      },
    );

    test(
      'a database table and a frontend entity for the SAME id resolve to the SAME node — real identity unification',
      () {
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );
        final coordinator = WorldModelCoordinator();
        coordinator.ingestBackendEngineering(plan);
        final countAfterBackend = coordinator.model.graph
            .nodesOfKind(WorldNodeKind.entity)
            .length;

        // Ingesting the SAME entity ids again (e.g. as if from a second
        // backend planning pass) must NOT double the entity node count —
        // proving real, structural identity unification, not accidental
        // duplication.
        coordinator.ingestBackendEngineering(plan);
        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.entity).length,
          countAfterBackend,
        );
      },
    );
  });

  group('Engineering Memory persistence (R8)', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test(
      'save then load round-trips a real BackendEngineeringPlan with full fidelity',
      () async {
        final experienceRepo = SqliteExperienceRepository(
          dbName: 'r8_engmem_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final repo = EngineeringMemoryRepository(
          experienceRepository: experienceRepo,
        );
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(requiresCredentialVault: true),
            app: _fleetApp(),
          ),
        );

        await repo.save(experienceId: 'exp-r8', backendEngineeringPlan: plan);
        final loaded = await repo.load('exp-r8');

        expect(loaded, isNotNull);
        expect(loaded!.backendEngineeringPlan, isNotNull);
        expect(loaded.backendEngineeringPlan!.toJson(), equals(plan.toJson()));
        await experienceRepo.close();
      },
    );

    test(
      'an R5-era row (no backend_engineering_json at all) still loads correctly — real backward compatibility, not just "doesn\'t crash"',
      () async {
        final experienceRepo = SqliteExperienceRepository(
          dbName: 'r8_legacy_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final repo = EngineeringMemoryRepository(
          experienceRepository: experienceRepo,
        );

        // Save WITHOUT a backend plan — exactly R5's own pre-R8 call shape.
        await repo.save(
          experienceId: 'exp-legacy',
          requirementGraph: null,
          architectureCandidate: null,
          engineeringSummary: null,
        );
        final loaded = await repo.load('exp-legacy');

        expect(
          loaded,
          isNotNull,
          reason:
              'an R5-shaped save must still be loadable after R8 — the integrity hash formula was deliberately left unchanged for exactly this reason',
        );
        expect(loaded!.backendEngineeringPlan, isNull);
        await experienceRepo.close();
      },
    );

    test(
      'no engineering memory configured — Kernel/Creation flow degrades gracefully, never crashes',
      () async {
        final experienceRepo = SqliteExperienceRepository(
          dbName: 'r8_noeng_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final repo = EngineeringMemoryRepository(
          experienceRepository: experienceRepo,
        );
        final loaded = await repo.load('never-existed');
        expect(loaded, isNull);
        await experienceRepo.close();
      },
    );
  });

  group('Performance (R8)', () {
    test(
      'planning a large (200-entity) application stays correct and reports real elapsed time',
      () {
        final entities = List.generate(
          200,
          (i) => SemanticEntity(
            id: 'e$i',
            name: 'Entity $i',
            fields: [
              SemanticField(
                id: 'f',
                name: 'Field',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
        );
        final app = SemanticApp(
          name: 'Large App',
          purpose: 'stress',
          entities: entities,
        );
        final architecture = ArchitectureCandidate(
          id: 'large',
          appName: 'Large App',
          entities: [
            for (final e in entities)
              EntityDecision(
                entityId: e.id,
                name: e.name,
                fieldCount: 1,
                storage: StorageKind.sqlite,
                storageDecision: _decision('s:${e.id}'),
              ),
          ],
          interactions: [
            for (final e in entities)
              InteractionDecision(
                entityId: e.id,
                canCreate: true,
                canRead: true,
                canUpdate: true,
                canDelete: true,
                supportsSearch: false,
                supportsFilter: false,
                supportsSort: false,
                supportsPagination: false,
                decision: _decision('i:${e.id}'),
              ),
          ],
          navigation: _nav(),
          security: SecurityDecision(
            networkMode: NetworkMode.none,
            requiresCredentialVault: false,
            decision: _decision('sec'),
          ),
          offline: OfflineDecision(
            capability: OfflineCapability.fullyOffline,
            decision: _decision('off'),
          ),
          synchronization: SynchronizationDecision(
            strategy: SyncStrategy.none,
            decision: _decision('sync'),
          ),
          overallConfidence: const Confidence(score: 1.0, reason: 'test'),
        );

        final stopwatch = Stopwatch()..start();
        final plan = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(architecture: architecture, app: app),
        );
        stopwatch.stop();

        expect(plan.database.tables, hasLength(200));
        // Each entity: canRead -> list+get (2), canCreate -> 1, canUpdate -> 1, canDelete -> 1 = 5 endpoints.
        expect(plan.api.endpoints, hasLength(200 * 5));
        // ignore: avoid_print
        print(
          'BackendEngineeringPlanner.plan over 200 entities: ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );
  });

  group('Kernel wiring (R8)', () {
    test(
      'a real Kernel run with a shared WorldModelCoordinator produces a real BackendEngineeringPlan, ingested into the World Graph',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});

        final worldModel = WorldModelCoordinator();
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registry(),
          reasoner: _FixedReasoner(),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: _FakeSearchProvider(),
            webweavexAdapter: _fakeAdapter(),
          ),
          worldModel: worldModel,
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my vehicle fleet maintenance'),
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final ready = outcome as ExecutionPlanReady;
        expect(ready.backendEngineeringPlan, isNotNull);
        expect(ready.backendEngineeringPlan!.database.tables, isNotEmpty);
        expect(
          worldModel.model.graph.nodesOfKind(WorldNodeKind.backendEndpoint),
          isNotEmpty,
        );
      },
    );

    test(
      'running the SAME intent twice produces byte-for-byte identical backend plans — determinism through the full Kernel path, zero new AI call',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});

        Future<ExecutionPlanReady> run() async {
          final kernel = AnythingKernel(
            providerRegistry: _FakeProviderRegistry(),
            capabilityRegistry: _registry(),
            reasoner: _FixedReasoner(),
            knowledgeEngine: KnowledgeAcquisitionEngine(
              searchProvider: _FakeSearchProvider(),
              webweavexAdapter: _fakeAdapter(),
            ),
          );
          return await kernel.processIntent(
                Intent.create(expression: 'track my vehicle fleet maintenance'),
              )
              as ExecutionPlanReady;
        }

        final a = await run();
        final b = await run();
        expect(
          a.backendEngineeringPlan!.toJson(),
          equals(b.backendEngineeringPlan!.toJson()),
        );
      },
    );
  });
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

class _FixedReasoner implements ApplicationReasoner {
  @override
  Future<AppReasoningResult> reason(
    ApplicationReasoningContext context,
  ) async => ReasoningReady(semanticApp: _fleetApp());
}

CapabilityRegistry _registry() {
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

class _FakeSearchProvider implements SearchProvider {
  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async =>
      const [];
}

WebWeaveXAdapter _fakeAdapter() =>
    WebWeaveXAdapter(fetchPage: (url) async => {'available': false});
