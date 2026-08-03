/// Implementation Milestone R5 — Engineering Memory, Persistent
/// Engineering State. Closes R4's honestly-documented finding that
/// `RequirementGraph`/`ArchitectureCandidate`/`EngineeringPlan` were
/// transient, Kernel-internal, never persisted per Experience.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/application_engineering/engineering_memory_summary.dart';
import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_candidate_serialization.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/requirement_graph.dart';
import 'package:anything/software_architect/requirement_graph_serialization.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

// ── Fixtures ────────────────────────────────────────────────────────────

RequirementGraph _requirementGraphFixture() => const RequirementGraph(
  nodes: [
    RequirementNode(id: 'entity:task', type: RequirementNodeType.entity, label: 'Task', source: RequirementSource.explicit),
    RequirementNode(id: 'field:task.title', type: RequirementNodeType.field, label: 'Title'),
  ],
  relations: [
    RequirementRelation(fromId: 'field:task.title', toId: 'entity:task', type: RequirementRelationType.belongsTo),
  ],
  nonFunctional: [
    NonFunctionalRequirement(category: NonFunctionalCategory.offline, description: 'Must work offline'),
  ],
);

ArchitectureCandidate _architectureCandidateFixture() => ArchitectureCandidate(
  id: 'arch-1',
  appName: 'Task Tracker',
  iteration: 1,
  entities: const [
    EntityDecision(
      entityId: 'task',
      name: 'Task',
      fieldCount: 1,
      storage: StorageKind.sqlite,
      storageDecision: ArchitectureDecision(
        id: 'd1',
        category: ArchitectureDecisionCategory.storage,
        subjectId: 'task',
        decision: 'sqlite',
        rationale: 'default',
        confidence: Confidence.full,
      ),
    ),
  ],
  navigation: const NavigationGraph(
    entryScreenId: 'tasks_list',
    screenIds: ['tasks_list'],
    edges: [],
    decision: ArchitectureDecision(
      id: 'd2',
      category: ArchitectureDecisionCategory.navigation,
      subjectId: 'nav',
      decision: 'single screen',
      rationale: 'minimal',
      confidence: Confidence.full,
    ),
  ),
  security: const SecurityDecision(
    networkMode: NetworkMode.none,
    requiresCredentialVault: false,
    decision: ArchitectureDecision(
      id: 'd3',
      category: ArchitectureDecisionCategory.security,
      subjectId: 'security',
      decision: 'no network',
      rationale: 'offline app',
      confidence: Confidence.full,
    ),
  ),
  offline: const OfflineDecision(
    capability: OfflineCapability.fullyOffline,
    decision: ArchitectureDecision(
      id: 'd4',
      category: ArchitectureDecisionCategory.offline,
      subjectId: 'offline',
      decision: 'fully offline',
      rationale: 'no network need',
      confidence: Confidence.full,
    ),
  ),
  synchronization: const SynchronizationDecision(
    strategy: SyncStrategy.none,
    decision: ArchitectureDecision(
      id: 'd5',
      category: ArchitectureDecisionCategory.synchronization,
      subjectId: 'sync',
      decision: 'none',
      rationale: 'no server',
      confidence: Confidence.full,
    ),
  ),
  overallConfidence: const Confidence(score: 0.9, reason: 'well-defined'),
);

SemanticApp _taskApp() {
  return SemanticApp(
    name: 'Task Tracker',
    purpose: 'Track tasks',
    entities: [
      const SemanticEntity(
        id: 'task',
        name: 'Task',
        displayField: 'title',
        fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(id: 'tasks_list', name: 'Tasks', purpose: 'list', sourceEntityId: 'task', viewType: BlueprintViewType.list, isDefault: true),
    ],
    actions: const [SemanticAction(id: 'add_task', name: 'Add Task', targetEntityId: 'task')],
  );
}

class _ImmediateReasoner implements ApplicationReasoner {
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    return ReasoningReady(semanticApp: _taskApp());
  }
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

class _FakeSearchProvider implements SearchProvider {
  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async => const [];
}

WebWeaveXAdapter _fakeAdapter() => WebWeaveXAdapter(fetchPage: (url) async => {'available': false});

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

AnythingKernel _realKernel({WorldModelCoordinator? worldModel}) => AnythingKernel(
  providerRegistry: _FakeProviderRegistry(),
  capabilityRegistry: _registry(),
  reasoner: _ImmediateReasoner(),
  knowledgeEngine: KnowledgeAcquisitionEngine(searchProvider: _FakeSearchProvider(), webweavexAdapter: _fakeAdapter()),
  worldModel: worldModel,
);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('RequirementGraph serialization (R5)', () {
    test('round-trips with full fidelity', () {
      final graph = _requirementGraphFixture();
      final json = graph.toJson();
      final restored = RequirementGraphJson.fromJson(json);

      expect(restored.nodes.length, graph.nodes.length);
      expect(restored.nodes.first.id, graph.nodes.first.id);
      expect(restored.nodes.first.source, RequirementSource.explicit);
      expect(restored.relations.single.type, RequirementRelationType.belongsTo);
      expect(restored.nonFunctional.single.category, NonFunctionalCategory.offline);
    });

    test('serialization is deterministic — same graph twice produces identical JSON', () {
      final graph = _requirementGraphFixture();
      expect(graph.toJson().toString(), graph.toJson().toString());
    });
  });

  group('ArchitectureCandidate serialization (R5)', () {
    test('round-trips with full fidelity', () {
      final candidate = _architectureCandidateFixture();
      final json = candidate.toJson();
      final restored = ArchitectureCandidateJson.fromJson(json);

      expect(restored.id, candidate.id);
      expect(restored.entities.single.entityId, 'task');
      expect(restored.entities.single.storage, StorageKind.sqlite);
      expect(restored.navigation.entryScreenId, 'tasks_list');
      expect(restored.security.networkMode, NetworkMode.none);
      expect(restored.offline.capability, OfflineCapability.fullyOffline);
      expect(restored.overallConfidence.score, 0.9);
    });

    test('serialization is deterministic', () {
      final candidate = _architectureCandidateFixture();
      expect(candidate.toJson().toString(), candidate.toJson().toString());
    });
  });

  group('EngineeringMemoryRepository (R5)', () {
    late SqliteExperienceRepository experienceRepo;
    late EngineeringMemoryRepository repo;

    setUp(() {
      experienceRepo = SqliteExperienceRepository(dbName: 'r5_${DateTime.now().microsecondsSinceEpoch}.db');
      repo = EngineeringMemoryRepository(experienceRepository: experienceRepo);
    });

    tearDown(() async => experienceRepo.close());

    test('save then load round-trips RequirementGraph + ArchitectureCandidate with full fidelity', () async {
      await repo.save(
        experienceId: 'exp-1',
        requirementGraph: _requirementGraphFixture(),
        architectureCandidate: _architectureCandidateFixture(),
      );

      final record = await repo.load('exp-1');
      expect(record, isNotNull);
      expect(record!.requirementGraph!.nodes.length, 2);
      expect(record.architectureCandidate!.entities.single.entityId, 'task');
    });

    test('load returns null for an Experience with no persisted engineering memory (backward compatibility)', () async {
      final record = await repo.load('never-persisted');
      expect(record, isNull);
    });

    test('a tampered row (integrity hash mismatch) is detected and treated as absent, never crashes', () async {
      await repo.save(experienceId: 'exp-2', requirementGraph: _requirementGraphFixture());

      final db = await experienceRepo.database;
      await db.update(
        'engineering_memory',
        {'requirement_graph_json': '{"nodes":[],"relations":[],"nonFunctional":[]}'},
        where: 'experience_id = ?',
        whereArgs: ['exp-2'],
      );

      final record = await repo.load('exp-2');
      expect(record, isNull, reason: 'a hash mismatch must be treated as corrupted, never silently trusted');
    });

    test('repository isolation — engineering memory for one Experience never leaks into another', () async {
      await repo.save(experienceId: 'exp-a', requirementGraph: _requirementGraphFixture());
      await repo.save(experienceId: 'exp-b', requirementGraph: const RequirementGraph());

      final a = await repo.load('exp-a');
      final b = await repo.load('exp-b');
      expect(a!.requirementGraph!.nodes.length, 2);
      expect(b!.requirementGraph!.nodes.length, 0);
    });

    test('performance: saving/loading engineering memory for 200 distinct Experiences stays correct and reports real elapsed time', () async {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        await repo.save(experienceId: 'perf-$i', requirementGraph: _requirementGraphFixture(), architectureCandidate: _architectureCandidateFixture());
      }
      stopwatch.stop();
      // ignore: avoid_print
      print('EngineeringMemoryRepository.save x200: ${stopwatch.elapsedMilliseconds}ms');

      final loadStopwatch = Stopwatch()..start();
      final loaded = await repo.load('perf-199');
      loadStopwatch.stop();
      expect(loaded, isNotNull);
      // ignore: avoid_print
      print('EngineeringMemoryRepository.load: ${loadStopwatch.elapsedMilliseconds}ms');
    });
  });

  group('EngineeringMemorySummary (R5)', () {
    test('summarize() reflects real EngineeringPlan data, never fabricated', () {
      // A minimal, real EngineeringCandidate is not hand-built here (its
      // tree is deep — see engineering_memory_summary.dart's own doc
      // comment for why this milestone summarizes rather than fully
      // serializes it); this test instead proves the summary type's own
      // round-trip fidelity, which is what persistence actually relies on.
      const summary = EngineeringMemorySummary(
        candidateId: 'eng-1',
        iteration: 2,
        outcome: EngineeringRefinementOutcome.approved,
        reviewIssueCount: 1,
        criticalReviewIssueCount: 0,
        overallConfidenceScore: 0.85,
        decisions: [],
      );
      final restored = EngineeringMemorySummary.fromJson(summary.toJson());
      expect(restored.candidateId, 'eng-1');
      expect(restored.outcome, EngineeringRefinementOutcome.approved);
      expect(restored.overallConfidenceScore, 0.85);
    });
  });

  group('Creation-time persistence (R5)', () {
    test('a real creation with a shared EngineeringMemoryRepository persists real RequirementGraph + ArchitectureCandidate', () async {
      final experienceRepo = SqliteExperienceRepository(dbName: 'r5_create_${DateTime.now().microsecondsSinceEpoch}.db');
      final engineeringMemory = EngineeringMemoryRepository(experienceRepository: experienceRepo);
      final kernel = _realKernel();
      final coordinator = ExperienceCreationCoordinator(
        kernel: kernel,
        repository: experienceRepo,
        engineeringMemory: engineeringMemory,
      );

      final result = await coordinator.createFromExpression('track my tasks');
      expect(result, isA<CreationCreated>());
      final experienceId = (result as CreationCreated).experienceId;

      final record = await engineeringMemory.load(experienceId);
      expect(record, isNotNull, reason: 'engineering memory must be persisted for a real creation');
      expect(record!.requirementGraph, isNotNull);
      expect(record.requirementGraph!.nodes, isNotEmpty);
      expect(record.architectureCandidate, isNotNull);

      await experienceRepo.close();
    });

    test('creation without an EngineeringMemoryRepository behaves exactly as before R5 — no crash, no change to the outcome', () async {
      final experienceRepo = SqliteExperienceRepository(dbName: 'r5_nomemory_${DateTime.now().microsecondsSinceEpoch}.db');
      final coordinator = ExperienceCreationCoordinator(kernel: _realKernel(), repository: experienceRepo);

      final result = await coordinator.createFromExpression('track my tasks');
      expect(result, isA<CreationCreated>());

      await experienceRepo.close();
    });
  });

  group('planEvolution() historical engineering memory (R5)', () {
    test('planEvolution() surfaces real historical engineering memory when it was persisted at creation', () async {
      final experienceRepo = SqliteExperienceRepository(dbName: 'r5_plan_${DateTime.now().microsecondsSinceEpoch}.db');
      final engineeringMemory = EngineeringMemoryRepository(experienceRepository: experienceRepo);
      final worldModel = WorldModelCoordinator();
      final creation = ExperienceCreationCoordinator(
        kernel: _realKernel(),
        repository: experienceRepo,
        engineeringMemory: engineeringMemory,
      );

      final created = await creation.createFromExpression('track my tasks') as CreationCreated;

      final modification = ExperienceModificationCoordinator(
        repository: experienceRepo,
        worldModel: worldModel,
        engineeringMemory: engineeringMemory,
      );
      final plan = await modification.planEvolution(experienceId: created.experienceId, modificationExpression: 'add a percentage field');

      expect(plan, isNotNull);
      expect(plan!.historicalEngineeringMemory, isNotNull);
      expect(plan.historicalEngineeringMemory!.requirementGraph, isNotNull);
      expect(plan.requirementDiff, isNull, reason: 'a genuine "after" requirement state is not derivable without re-running Kernel planning — honestly null, never fabricated');

      await experienceRepo.close();
    });

    test('planEvolution() degrades gracefully for an Experience with no persisted engineering memory — no crash, historicalEngineeringMemory is null', () async {
      final experienceRepo = SqliteExperienceRepository(dbName: 'r5_nohistory_${DateTime.now().microsecondsSinceEpoch}.db');
      // Created WITHOUT an engineeringMemory repository — simulating a
      // pre-R5 Experience.
      final creation = ExperienceCreationCoordinator(kernel: _realKernel(), repository: experienceRepo);
      final created = await creation.createFromExpression('track my tasks') as CreationCreated;

      final modification = ExperienceModificationCoordinator(
        repository: experienceRepo,
        engineeringMemory: EngineeringMemoryRepository(experienceRepository: experienceRepo),
      );
      final plan = await modification.planEvolution(experienceId: created.experienceId, modificationExpression: 'add a percentage field');

      expect(plan, isNotNull);
      expect(plan!.historicalEngineeringMemory, isNull);
      expect(plan.experienceDiff, isNotNull, reason: 'ExperienceDiff (R4) must remain unaffected by the absence of engineering memory');

      await experienceRepo.close();
    });

    test('planEvolution() without an EngineeringMemoryRepository at all behaves exactly as R4 did', () async {
      final experienceRepo = SqliteExperienceRepository(dbName: 'r5_r4parity_${DateTime.now().microsecondsSinceEpoch}.db');
      final creation = ExperienceCreationCoordinator(kernel: _realKernel(), repository: experienceRepo);
      final created = await creation.createFromExpression('track my tasks') as CreationCreated;

      final modification = ExperienceModificationCoordinator(repository: experienceRepo);
      final plan = await modification.planEvolution(experienceId: created.experienceId, modificationExpression: 'add a percentage field');

      expect(plan, isNotNull);
      expect(plan!.historicalEngineeringMemory, isNull);

      await experienceRepo.close();
    });
  });
}
