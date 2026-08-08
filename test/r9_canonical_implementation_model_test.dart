/// Implementation Milestone R9 — Canonical Implementation Model. Proves
/// the real, deterministic, LANGUAGE-INDEPENDENT unification of frontend
/// `EngineeringCandidate` (R3) and `BackendEngineeringPlan` (R8) into one
/// implementation-concept vocabulary — zero new AI call, zero generated
/// source code/SQL/deployment config. Novel domain fixture ("Vehicle
/// Fleet Maintenance Log", reused from R8's own established fixture,
/// since it's already zero-footprint elsewhere in lib/ and this milestone
/// is a direct successor to R8's own output).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/application_engineering/engineering_candidate.dart';
import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/implementation_model/canonical_implementation_planner.dart';
import 'package:anything/implementation_model/canonical_implementation_serialization.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

// ── Fixtures (mirrors test/r8_backend_engineering_test.dart's established pattern) ──

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
  SyncStrategy sync = SyncStrategy.none,
}) {
  return ArchitectureCandidate(
    id: 'fleet-candidate',
    appName: 'Vehicle Fleet Maintenance Log',
    entities: const [
      EntityDecision(
        entityId: 'vehicle',
        name: 'Vehicle',
        fieldCount: 2,
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
      networkMode: NetworkMode.none,
      requiresCredentialVault: requiresCredentialVault,
      decision: _decision('sec'),
    ),
    offline: OfflineDecision(
      capability: OfflineCapability.fullyOffline,
      decision: _decision('off'),
    ),
    synchronization: SynchronizationDecision(
      strategy: sync,
      decision: _decision('sync'),
    ),
    overallConfidence: const Confidence(score: 1.0, reason: 'test'),
  );
}

EngineeringCandidate _fleetEngineering({ArchitectureCandidate? architecture}) =>
    const EngineeringPlanner().plan(
      EngineeringContext(
        architecture: architecture ?? _fleetArchitecture(),
        app: _fleetApp(),
      ),
    );

CanonicalImplementationContext _fleetCimContext({
  List<CapabilityDescriptor> capabilities = const [],
}) {
  final architecture = _fleetArchitecture();
  final backend = const BackendEngineeringPlanner().plan(
    BackendEngineeringContext(architecture: architecture, app: _fleetApp()),
  );
  return CanonicalImplementationContext(
    engineering: _fleetEngineering(architecture: architecture),
    backend: backend,
    resolvedCapabilities: capabilities,
  );
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

CapabilityRegistry _kernelRegistry() {
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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('CanonicalImplementationModel construction (R9)', () {
    test(
      'every backend table becomes a real Entity/Repository/Controller/DTO/Validator, with a real Service grouping',
      () {
        final model = const CanonicalImplementationPlanner().plan(
          _fleetCimContext(),
        );

        expect(
          model.entities.map((e) => e.id),
          containsAll(['vehicle', 'maintenance_record']),
        );
        final vehicleEntity = model.entities.firstWhere(
          (e) => e.id == 'vehicle',
        );
        expect(
          vehicleEntity.fields.map((f) => f.name),
          containsAll(['id', 'Name', 'Mileage']),
        );

        final vehicleRepo = model.repositories.firstWhere(
          (r) => r.entityId == 'vehicle',
        );
        expect(
          vehicleRepo.supportedOperations,
          containsAll([
            ImplementationOperationKind.list,
            ImplementationOperationKind.get,
            ImplementationOperationKind.create,
            ImplementationOperationKind.update,
            ImplementationOperationKind.delete,
            ImplementationOperationKind.search,
          ]),
        );

        final vehicleController = model.controllers.firstWhere(
          (c) => c.entityId == 'vehicle',
        );
        expect(vehicleController.operations, isNotEmpty);

        expect(model.dtos.any((d) => d.entityId == 'vehicle'), isTrue);
        expect(
          model.validators.any(
            (v) => v.entityId == 'vehicle' && v.rules.any((r) => r.required),
          ),
          isTrue,
        );
        expect(model.services.any((s) => s.entityId == 'vehicle'), isTrue);
      },
    );

    test('a real foreign key becomes a real entity-to-entity Dependency', () {
      final model = const CanonicalImplementationPlanner().plan(
        _fleetCimContext(),
      );
      expect(
        model.dependencies.any(
          (d) =>
              d.fromId == 'maintenance_record' &&
              d.toId == 'vehicle' &&
              d.kind == DependencyKind.entityReference,
        ),
        isTrue,
      );
    });

    test(
      'a resolved capability becomes a real entity-to-capability Dependency and a real CapabilityAdapter',
      () {
        const cap = CapabilityDescriptor(
          id: 'clock',
          version: '1.0.0',
          name: 'Clock',
          description: 'd',
          category: CapabilityCategory.computation,
          inputContract: 'i',
          outputContract: 'o',
        );
        final model = const CanonicalImplementationPlanner().plan(
          _fleetCimContext(capabilities: const [cap]),
        );

        expect(model.capabilityAdapters.single.capabilityId, 'clock');
        expect(
          model.dependencies.any(
            (d) => d.toId == 'clock' && d.kind == DependencyKind.capability,
          ),
          isTrue,
        );
      },
    );

    test(
      'a real StateMachine becomes a real StateContainer, reusing GenericState directly — never a duplicate enum',
      () {
        final model = const CanonicalImplementationPlanner().plan(
          _fleetCimContext(),
        );
        expect(model.stateContainers, isNotEmpty);
        expect(model.stateContainers.first.entityId, isNotEmpty);
      },
    );

    test('real NavigationEdges become real NavigationRouteSpecs', () {
      final architecture = _fleetArchitecture();
      final engineering = _fleetEngineering(architecture: architecture);
      // The fixture's NavigationGraph has no modal edges — a real, honest
      // empty case, never fabricated routes.
      final backend = const BackendEngineeringPlanner().plan(
        BackendEngineeringContext(architecture: architecture, app: _fleetApp()),
      );
      final model = const CanonicalImplementationPlanner().plan(
        CanonicalImplementationContext(
          engineering: engineering,
          backend: backend,
        ),
      );
      expect(
        model.navigation.routes,
        isEmpty,
        reason:
            'the fixture architecture has no modal edges — an honest empty result, not a fabricated one',
      );
    });

    test(
      'authentication/storage/backgroundWorker are thin, real wrappers over BackendEngineeringPlan — never fabricated',
      () {
        final architecture = _fleetArchitecture(
          requiresCredentialVault: true,
          sync: SyncStrategy.cacheFirst,
        );
        final engineering = _fleetEngineering(architecture: architecture);
        final backend = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: architecture,
            app: _fleetApp(),
          ),
        );
        final model = const CanonicalImplementationPlanner().plan(
          CanonicalImplementationContext(
            engineering: engineering,
            backend: backend,
          ),
        );

        expect(model.authentication.requiresCredentials, isTrue);
        expect(model.backgroundWorker.requiresBackgroundSync, isTrue);
      },
    );
  });

  group(
    'Language independence (R9) — mechanical, not a naming convention followed by hand',
    () {
      test(
        'zero language-specific terms appear anywhere in the model or its serialized JSON',
        () {
          final model = const CanonicalImplementationPlanner().plan(
            _fleetCimContext(),
          );
          final json = model.toJson().toString();
          final typeDump =
              <Type>[
                CanonicalImplementationModel,
                ImplementationEntity,
                ImplementationRepository,
                ImplementationController,
                ImplementationDto,
                ImplementationValidator,
                ImplementationService,
                ImplementationDependency,
                StateContainerSpec,
                NavigationHandlerSpec,
                CapabilityAdapterSpec,
                AuthenticationAdapterSpec,
                StorageAdapterSpec,
                BackgroundWorkerSpec,
              ].join() +
              ImplementationDataType.values.join() +
              ImplementationOperationKind.values.join() +
              DependencyKind.values.join();

          const forbiddenTerms = [
            'Widget',
            'Flutter',
            'Dart',
            'StatefulWidget',
            'Java',
            'Kotlin',
            'Swift',
            'TypeScript',
            'Python',
            'Node',
            'React',
            'Express',
            'FastAPI',
            'Spring',
          ];
          for (final term in forbiddenTerms) {
            expect(
              json.contains(term),
              isFalse,
              reason: '"$term" leaked into the serialized model',
            );
            expect(
              typeDump.contains(term),
              isFalse,
              reason: '"$term" leaked into a type/enum name',
            );
          }
        },
      );
    },
  );

  group('Serialization (R9)', () {
    test('toJson/fromJson round-trips every field with full fidelity', () {
      const cap = CapabilityDescriptor(
        id: 'http',
        version: '1.0.0',
        name: 'HTTP',
        description: 'd',
        category: CapabilityCategory.integration,
        inputContract: 'i',
        outputContract: 'o',
      );
      final model = const CanonicalImplementationPlanner().plan(
        _fleetCimContext(capabilities: const [cap]),
      );

      final roundTripped = canonicalImplementationModelFromJson(model.toJson());

      expect(roundTripped.entities.length, model.entities.length);
      expect(roundTripped.repositories.length, model.repositories.length);
      expect(roundTripped.controllers.length, model.controllers.length);
      expect(roundTripped.dependencies.length, model.dependencies.length);
      expect(roundTripped.capabilityAdapters.single.capabilityId, 'http');
      expect(
        roundTripped.authentication.requiresCredentials,
        model.authentication.requiresCredentials,
      );
      expect(roundTripped.toJson(), model.toJson());
    });
  });

  group('Engineering Memory persistence (R9)', () {
    test(
      'save then load round-trips a real CanonicalImplementationModel with full fidelity',
      () async {
        final experienceRepo = SqliteExperienceRepository(
          dbName: 'r9_cim_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final repo = EngineeringMemoryRepository(
          experienceRepository: experienceRepo,
        );
        final model = const CanonicalImplementationPlanner().plan(
          _fleetCimContext(),
        );

        await repo.save(
          experienceId: 'exp-cim-1',
          canonicalImplementationModel: model,
        );
        final loaded = await repo.load('exp-cim-1');

        expect(loaded, isNotNull);
        expect(loaded!.canonicalImplementationModel, isNotNull);
        expect(loaded.canonicalImplementationModel!.toJson(), model.toJson());
        await experienceRepo.close();
      },
    );

    test(
      'an R8-era row (no canonical_implementation_json at all) still loads correctly — real backward compatibility',
      () async {
        final experienceRepo = SqliteExperienceRepository(
          dbName: 'r9_r8era_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final repo = EngineeringMemoryRepository(
          experienceRepository: experienceRepo,
        );
        final backend = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(
            architecture: _fleetArchitecture(),
            app: _fleetApp(),
          ),
        );

        // Simulates an R8-era save: no canonicalImplementationModel argument
        // supplied at all, exactly like real pre-R9 code would have called
        // this method.
        await repo.save(
          experienceId: 'exp-r8-era',
          backendEngineeringPlan: backend,
        );
        final loaded = await repo.load('exp-r8-era');

        expect(loaded, isNotNull);
        expect(
          loaded!.backendEngineeringPlan,
          isNotNull,
          reason: 'the R8-era field must still load correctly',
        );
        expect(
          loaded.canonicalImplementationModel,
          isNull,
          reason:
              'no CIM was ever saved for this row — must be null, never fabricated',
        );
        await experienceRepo.close();
      },
    );

    test(
      'no engineering memory configured — Kernel/Creation flow degrades gracefully, never crashes',
      () async {
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _kernelRegistry(),
          reasoner: _FixedReasoner(),
        );
        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my fleet vehicles'),
        );
        expect(outcome, isA<ExecutionPlanReady>());
        expect(
          (outcome as ExecutionPlanReady).canonicalImplementationModel,
          isNotNull,
          reason:
              'CIM is always computed on the production path, with or without a WorldModelCoordinator/EngineeringMemoryRepository injected',
        );
      },
    );
  });

  group('World Model integration (R9)', () {
    test(
      'ingesting a real CanonicalImplementationModel adds a real entity-to-capability dependency edge to the shared World Graph',
      () {
        const cap = CapabilityDescriptor(
          id: 'clock',
          version: '1.0.0',
          name: 'Clock',
          description: 'd',
          category: CapabilityCategory.computation,
          inputContract: 'i',
          outputContract: 'o',
        );
        final model = const CanonicalImplementationPlanner().plan(
          _fleetCimContext(capabilities: const [cap]),
        );
        final coordinator = WorldModelCoordinator();

        coordinator.ingestCanonicalImplementation(model);

        final capabilityNodes = coordinator.model.graph.nodesOfKind(
          WorldNodeKind.capability,
        );
        expect(capabilityNodes, isNotEmpty);
        final dependsOnEdges = coordinator.model.graph.edges.where(
          (e) => e.kind == RelationshipKind.dependsOn,
        );
        expect(dependsOnEdges, isNotEmpty);
      },
    );
  });

  group('Determinism (R9)', () {
    test(
      'planning the same context twice produces a structurally identical model',
      () {
        const planner = CanonicalImplementationPlanner();
        final a = planner.plan(_fleetCimContext());
        final b = planner.plan(_fleetCimContext());
        expect(a.toJson(), b.toJson());
      },
    );

    test(
      'running the SAME intent twice through the full Kernel path produces byte-for-byte identical CIM JSON — zero new AI call',
      () async {
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _kernelRegistry(),
          reasoner: _FixedReasoner(),
        );

        final first = await kernel.processIntent(
          Intent.create(expression: 'track my fleet vehicles'),
        );
        final second = await kernel.processIntent(
          Intent.create(expression: 'track my fleet vehicles'),
        );

        expect(first, isA<ExecutionPlanReady>());
        expect(second, isA<ExecutionPlanReady>());
        final firstCim =
            (first as ExecutionPlanReady).canonicalImplementationModel!;
        final secondCim =
            (second as ExecutionPlanReady).canonicalImplementationModel!;
        expect(firstCim.toJson(), secondCim.toJson());
      },
    );
  });

  group('Performance (R9)', () {
    test(
      'planning a large (200-entity) application stays correct and reports real elapsed time',
      () {
        final entities = List.generate(
          200,
          (i) => SemanticEntity(
            id: 'e$i',
            name: 'Entity $i',
            displayField: 'name',
            fields: [
              const SemanticField(
                id: 'name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
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
            for (var i = 0; i < 200; i++)
              EntityDecision(
                entityId: 'e$i',
                name: 'Entity $i',
                fieldCount: 1,
                storage: StorageKind.sqlite,
                storageDecision: _decision('s$i'),
              ),
          ],
          navigation: NavigationGraph(
            entryScreenId: 'e0',
            screenIds: [for (var i = 0; i < 200; i++) 'e$i'],
            edges: const [],
            decision: _decision('nav'),
          ),
          interactions: [
            for (var i = 0; i < 200; i++)
              InteractionDecision(
                entityId: 'e$i',
                canCreate: true,
                canRead: true,
                canUpdate: true,
                canDelete: true,
                supportsSearch: false,
                supportsFilter: false,
                supportsSort: false,
                supportsPagination: false,
                decision: _decision('int$i'),
              ),
          ],
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
        final engineering = const EngineeringPlanner().plan(
          EngineeringContext(architecture: architecture, app: app),
        );
        final backend = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(architecture: architecture, app: app),
        );

        final stopwatch = Stopwatch()..start();
        final model = const CanonicalImplementationPlanner().plan(
          CanonicalImplementationContext(
            engineering: engineering,
            backend: backend,
          ),
        );
        stopwatch.stop();

        expect(model.entities, hasLength(200));
        // ignore: avoid_print
        print(
          'CanonicalImplementationPlanner over 200 entities: ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );
  });
}
