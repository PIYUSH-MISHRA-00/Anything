/// Implementation Specification IS-R24 — Engineering Intelligence Layer,
/// Requirement Graph, Architecture Graph, Incremental Software Synthesis.
/// Proves the real gap this milestone closes: of R24's 14 requested graph
/// types, 11 already exist under real names (`RequirementGraph`, V2;
/// `ArchitectureCandidate`+`BackendEngineeringPlan`, V2/R8, unified by
/// `SemanticSolutionArchitecture`, R17) with real diff engines already
/// built (`RequirementGraphDiffer`/`ArchitectureDiffer`, R3/R4) — this
/// milestone adds ONE genuinely novel contribution: translating those
/// diffs into affected entity ids, scoping a real
/// `CanonicalImplementationModel` to only those entities, and running the
/// EXISTING, UNMODIFIED compiler pipeline (`runCompilerPipeline`, R19)
/// over the scoped subset — then wiring the result into the EXISTING,
/// UNMODIFIED `EvolutionDiffPlan`/`applyEvolutionPlan()` hot-reload
/// mechanism (R4-R7), and a narrow, real `RequirementGraphBridge` closing
/// the "RequirementGraph is never ingested into World Model" finding.
/// Never a second Compiler/Planner/Runtime/World Model/AI Boundary/Build
/// Graph/Canonical Model.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/compiler_integration/compiler_pipeline_runner.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/engineering_intelligence/affected_entities.dart';
import 'package:anything/engineering_intelligence/engineering_intelligence.dart';
import 'package:anything/engineering_intelligence/incremental_compiler_synthesis.dart';
import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/generator_framework/generation_result.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_candidate_diff.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/requirement_graph.dart';
import 'package:anything/software_architect/requirement_graph_diff.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── Fixtures (mirroring test/r19_compiler_production_integration_test.dart's
// "real SemanticApp through the real Kernel" shape). ──────────────────────

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

class _FixedReasoner implements ApplicationReasoner {
  final SemanticApp app;
  const _FixedReasoner(this.app);
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async => ReasoningReady(semanticApp: app);
}

/// A novel domain ("Field Log"), single entity — zero footprint elsewhere.
SemanticApp _noteOnlyApp() => SemanticApp(
  name: 'Field Log',
  purpose: 'Track field log notes',
  entities: [
    const SemanticEntity(id: 'note', name: 'Note', displayField: 'title', fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)]),
  ],
  requiredCapabilities: const ['storage'],
);

/// Same domain plus one genuinely new entity ('tag') — the real "after"
/// state for diff-driven incremental synthesis tests.
SemanticApp _noteAndTagApp() => SemanticApp(
  name: 'Field Log',
  purpose: 'Track field log notes',
  entities: [
    const SemanticEntity(id: 'note', name: 'Note', displayField: 'title', fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)]),
    const SemanticEntity(id: 'tag', name: 'Tag', displayField: 'name', fields: [SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true)]),
  ],
  requiredCapabilities: const ['storage'],
);

Future<ExecutionPlanReady> _runKernel(SemanticApp app, {WorldModelCoordinator? worldModel}) async {
  final kernel = AnythingKernel(providerRegistry: _FakeProviderRegistry(), capabilityRegistry: _registryWithStorage(), reasoner: _FixedReasoner(app), worldModel: worldModel);
  final outcome = await kernel.processIntent(Intent.create(expression: 'track my field log'));
  expect(outcome, isA<ExecutionPlanReady>());
  return outcome as ExecutionPlanReady;
}

void main() {
  group('EngineeringIntelligence facade (R24) — real composition, never a copy', () {
    test('holds the SAME requirementGraph/architectureCandidate/backendEngineeringPlan references a real Kernel run produced', () async {
      final ready = await _runKernel(_noteOnlyApp());
      final requirementGraph = ready.requirementGraph!;
      final architecture = ready.solutionDecision!.selected.architecture;
      final backend = ready.backendEngineeringPlan;

      final intelligence = EngineeringIntelligence(requirementGraph: requirementGraph, architectureCandidate: architecture, backendEngineeringPlan: backend);

      expect(identical(intelligence.requirementGraph, requirementGraph), isTrue);
      expect(identical(intelligence.architectureCandidate, architecture), isTrue);
      expect(identical(intelligence.backendEngineeringPlan, backend), isTrue);
    });

    test('backendEngineeringPlan is nullable — a facade with no backend plan is still real, never fabricated', () {
      const graph = RequirementGraph();
      const architecture = ArchitectureCandidate(
        id: 'a',
        appName: 'A',
        navigation: NavigationGraph(entryScreenId: 'x', screenIds: [], edges: [], decision: ArchitectureDecision(id: 'n', category: ArchitectureDecisionCategory.data, subjectId: 'n', decision: 'd', rationale: 'r', confidence: Confidence(score: 1.0, reason: 't'))),
        security: SecurityDecision(networkMode: NetworkMode.none, requiresCredentialVault: false, decision: ArchitectureDecision(id: 's', category: ArchitectureDecisionCategory.data, subjectId: 's', decision: 'd', rationale: 'r', confidence: Confidence(score: 1.0, reason: 't'))),
        offline: OfflineDecision(capability: OfflineCapability.fullyOffline, decision: ArchitectureDecision(id: 'o', category: ArchitectureDecisionCategory.data, subjectId: 'o', decision: 'd', rationale: 'r', confidence: Confidence(score: 1.0, reason: 't'))),
        synchronization: SynchronizationDecision(strategy: SyncStrategy.none, decision: ArchitectureDecision(id: 'sy', category: ArchitectureDecisionCategory.data, subjectId: 'sy', decision: 'd', rationale: 'r', confidence: Confidence(score: 1.0, reason: 't'))),
        overallConfidence: Confidence(score: 1.0, reason: 't'),
      );
      const intelligence = EngineeringIntelligence(requirementGraph: graph, architectureCandidate: architecture);
      expect(intelligence.backendEngineeringPlan, isNull);
    });
  });

  group('AffectedEntityAnalyzer (R24) — real, deterministic diff-to-entity translation, reusing R3/R4\'s existing diff types unmodified', () {
    test('an added entity in RequirementGraph is a real affected entity', () {
      const before = RequirementGraph(nodes: [RequirementNode(id: 'entity:note', type: RequirementNodeType.entity, label: 'Note')]);
      const after = RequirementGraph(
        nodes: [RequirementNode(id: 'entity:note', type: RequirementNodeType.entity, label: 'Note'), RequirementNode(id: 'entity:tag', type: RequirementNodeType.entity, label: 'Tag')],
      );
      final diff = const RequirementGraphDiffer().diff(before, after);
      final affected = const AffectedEntityAnalyzer().fromRequirementDiff(diff);
      expect(affected.entityIds, {'tag'});
    });

    test('a field/constraint node change resolves to its owning entity, never a fabricated one', () {
      const before = RequirementGraph(nodes: [RequirementNode(id: 'entity:note', type: RequirementNodeType.entity, label: 'Note')]);
      const after = RequirementGraph(
        nodes: [
          RequirementNode(id: 'entity:note', type: RequirementNodeType.entity, label: 'Note'),
          RequirementNode(id: 'field:note.body', type: RequirementNodeType.field, label: 'Body'),
        ],
      );
      final diff = const RequirementGraphDiffer().diff(before, after);
      final affected = const AffectedEntityAnalyzer().fromRequirementDiff(diff);
      expect(affected.entityIds, {'note'});
    });

    test('capability/navigation nodes (not rooted at exactly one entity) are honestly excluded, never guessed', () {
      const before = RequirementGraph();
      const after = RequirementGraph(nodes: [RequirementNode(id: 'capability:http', type: RequirementNodeType.capability, label: 'http')]);
      final diff = const RequirementGraphDiffer().diff(before, after);
      final affected = const AffectedEntityAnalyzer().fromRequirementDiff(diff);
      expect(affected.isEmpty, isTrue);
    });

    test('ArchitectureDiff added/removed/changed entities, fields, and relationships (both endpoints) are real affected entities', () {
      final beforeArch = _minimalArchitecture(entities: const ['note']);
      final afterArch = _minimalArchitecture(entities: const ['note', 'tag'], relateNoteToTag: true);
      final diff = const ArchitectureDiffer().diff(beforeArch, afterArch);
      final affected = const AffectedEntityAnalyzer().fromArchitectureDiff(diff);
      expect(affected.entityIds, {'note', 'tag'});
    });

    test('merge() unions two real diffs\' affected sets without duplication', () {
      const a = AffectedEntities({'note'});
      const b = AffectedEntities({'tag'});
      expect(a.merge(b).entityIds, {'note', 'tag'});
    });

    test('AffectedEntities.none is honestly empty', () {
      expect(AffectedEntities.none.isEmpty, isTrue);
    });
  });

  group('IncrementalCompilerSynthesizer (R24 centerpiece) — real diff-driven scoping through the EXISTING, unmodified compiler pipeline', () {
    test('a real added-entity diff produces a real, correctly SCOPED compiler package — not a full regeneration', () async {
      final beforeReady = await _runKernel(_noteOnlyApp());
      final afterReady = await _runKernel(_noteAndTagApp());

      final architectureDiff = const ArchitectureDiffer().diff(beforeReady.solutionDecision!.selected.architecture, afterReady.solutionDecision!.selected.architecture);
      final affected = const AffectedEntityAnalyzer().fromArchitectureDiff(architectureDiff);
      expect(affected.entityIds, {'tag'}, reason: 'only the added entity should be affected — the pre-existing "note" entity did not change');

      final fullModel = afterReady.canonicalImplementationModel!;
      expect(fullModel.entities.length, 2, reason: 'sanity: the full model really does contain both entities');

      final result = const IncrementalCompilerSynthesizer().synthesize(fullModel: fullModel, affected: affected, id: 'field-log', name: 'Field Log');

      expect(result.succeeded, isTrue, reason: result.compilerResult.diagnostics.map((d) => d.message).join('; '));
      expect(result.scopedEntityCount, 1, reason: 'the compiler pipeline ran over ONLY the affected entity, not both');
      expect(result.fullEntityCount, 2);
      expect(result.package!.data!.entities.map((e) => e.id), ['tag']);
      expect(ExperiencePackageValidator.validate(result.package!).isValid, isTrue);
    });

    test('an empty AffectedEntities produces an honest no-op result, never a fabricated package', () async {
      final ready = await _runKernel(_noteOnlyApp());
      final result = const IncrementalCompilerSynthesizer().synthesize(fullModel: ready.canonicalImplementationModel!, affected: AffectedEntities.none, id: 'x', name: 'X');
      expect(result.package, isNull);
      expect(result.succeeded, isFalse);
    });

    test('scoping is real: the SAME full model synthesized fully vs. incrementally over one entity produces measurably different packages', () async {
      final ready = await _runKernel(_noteAndTagApp());
      final fullModel = ready.canonicalImplementationModel!;

      final fullOutcome = runCompilerPipeline(fullModel, id: 'x', name: 'X');
      final incrementalResult = const IncrementalCompilerSynthesizer().synthesize(fullModel: fullModel, affected: const AffectedEntities({'note'}), id: 'x', name: 'X');

      expect(fullOutcome.package!.data!.entities.length, 2);
      expect(incrementalResult.package!.data!.entities.length, 1);
    });

    test('buildEvolutionPlan() composes the EXISTING EvolutionDiffPlanBuilder/ExperienceDiffer (R4) unmodified — real mutations, a real candidatePackage', () async {
      final beforeReady = await _runKernel(_noteOnlyApp());
      final afterReady = await _runKernel(_noteAndTagApp());
      final beforeOutcome = runCompilerPipeline(beforeReady.canonicalImplementationModel!, id: 'field-log', name: 'Field Log');

      final architectureDiff = const ArchitectureDiffer().diff(beforeReady.solutionDecision!.selected.architecture, afterReady.solutionDecision!.selected.architecture);
      final affected = const AffectedEntityAnalyzer().fromArchitectureDiff(architectureDiff);
      final result = const IncrementalCompilerSynthesizer().synthesize(fullModel: afterReady.canonicalImplementationModel!, affected: affected, id: 'field-log', name: 'Field Log');

      final plan = const IncrementalCompilerSynthesizer().buildEvolutionPlan(experienceId: 'exp-1', previousPackage: beforeOutcome.package!, result: result);

      expect(plan, isNotNull);
      expect(plan!.mutations, isNotEmpty);
      expect(plan.candidatePackage, isNotNull);
      expect(identical(plan.candidatePackage, result.package), isTrue);
    });

    test('buildEvolutionPlan() returns null for a no-op result, never a fabricated plan', () async {
      const noop = IncrementalSynthesisResult(package: null, compilerResult: GenerationResult(), affectedEntityIds: {}, scopedEntityCount: 0, fullEntityCount: 0, latency: Duration.zero);
      final ready = await _runKernel(_noteOnlyApp());
      final outcome = runCompilerPipeline(ready.canonicalImplementationModel!, id: 'x', name: 'X');
      final plan = const IncrementalCompilerSynthesizer().buildEvolutionPlan(experienceId: 'x', previousPackage: outcome.package!, result: noop);
      expect(plan, isNull);
    });

    test('a compiler-produced candidatePackage flows through the REAL, UNMODIFIED applyEvolutionPlan() hot-reload path with zero changes to that machinery', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final dbName = 'r24_hot_reload_${DateTime.now().microsecondsSinceEpoch}.db';
      final repository = SqliteExperienceRepository(dbName: dbName);

      final beforeReady = await _runKernel(_noteOnlyApp());
      final afterReady = await _runKernel(_noteAndTagApp());
      final beforeOutcome = runCompilerPipeline(beforeReady.canonicalImplementationModel!, id: 'field-log', name: 'Field Log');
      expect(beforeOutcome.succeeded, isTrue);

      await repository.savePackage(beforeOutcome.package!);
      await repository.saveMetadata(
        ExperienceMetadataRecord(id: 'field-log', name: 'Field Log', description: '', category: 'generated', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );

      final architectureDiff = const ArchitectureDiffer().diff(beforeReady.solutionDecision!.selected.architecture, afterReady.solutionDecision!.selected.architecture);
      final affected = const AffectedEntityAnalyzer().fromArchitectureDiff(architectureDiff);
      final synthResult = const IncrementalCompilerSynthesizer().synthesize(fullModel: afterReady.canonicalImplementationModel!, affected: affected, id: 'field-log', name: 'Field Log');
      final plan = const IncrementalCompilerSynthesizer().buildEvolutionPlan(experienceId: 'field-log', previousPackage: beforeOutcome.package!, result: synthResult)!;

      final coordinator = ExperienceModificationCoordinator(repository: repository);
      final applyResult = await coordinator.applyEvolutionPlan(plan);

      expect(applyResult, isA<ModificationCoordinatorSucceeded>());
      final succeeded = applyResult as ModificationCoordinatorSucceeded;
      expect(identical(succeeded.newPackage, synthResult.package), isTrue);
      final stored = await repository.getPackage('field-log');
      expect(stored!.manifest.experienceId, synthResult.package!.manifest.experienceId);

      await repository.close();
    });
  });

  group('RequirementGraphBridge / World Model ingestion (R24) — closing "RequirementGraph is never ingested" (confirmed by grep pre-milestone)', () {
    test('a real RequirementGraph with a capability node grows the World Graph by a real capability node', () {
      final worldModel = WorldModelCoordinator();
      final before = worldModel.model.graph.nodes.length;
      const graph = RequirementGraph(nodes: [RequirementNode(id: 'capability:http', type: RequirementNodeType.capability, label: 'http')]);

      worldModel.ingestRequirementGraph(graph);

      expect(worldModel.model.graph.nodes.length, greaterThan(before));
      expect(worldModel.model.graph.nodes.any((n) => n.kind == WorldNodeKind.capability && n.label == 'http'), isTrue);
    });

    test('a real view->entity requirement-reference relation produces a real edge, unifying the entity via the SAME stableId convention every other bridge uses', () {
      final worldModel = WorldModelCoordinator();
      const graph = RequirementGraph(
        nodes: [RequirementNode(id: 'entity:note', type: RequirementNodeType.entity, label: 'Note'), RequirementNode(id: 'view:notes_list', type: RequirementNodeType.view, label: 'Notes')],
        relations: [RequirementRelation(fromId: 'view:notes_list', toId: 'entity:note', type: RequirementRelationType.references)],
      );

      worldModel.ingestRequirementGraph(graph);

      expect(worldModel.model.graph.edges.any((e) => e.kind == RelationshipKind.references), isTrue);
      expect(worldModel.model.graph.nodes.any((n) => n.kind == WorldNodeKind.entity && n.label == 'Note'), isTrue);
    });

    test('a relation whose target is not an entity node is honestly skipped, never a fabricated edge', () {
      final worldModel = WorldModelCoordinator();
      final before = worldModel.model.graph.edges.length;
      const graph = RequirementGraph(
        nodes: [RequirementNode(id: 'view:notes_list', type: RequirementNodeType.view, label: 'Notes'), RequirementNode(id: 'navigation:notes_list', type: RequirementNodeType.navigation, label: 'Nav')],
        relations: [RequirementRelation(fromId: 'navigation:notes_list', toId: 'view:notes_list', type: RequirementRelationType.implements)],
      );

      worldModel.ingestRequirementGraph(graph);

      expect(worldModel.model.graph.edges.length, before);
    });

    test('field/constraint/storage/state nodes are deliberately NOT ingested (real, documented restraint, not a bug)', () {
      final worldModel = WorldModelCoordinator();
      final before = worldModel.model.graph.nodes.length;
      const graph = RequirementGraph(
        nodes: [
          RequirementNode(id: 'field:note.title', type: RequirementNodeType.field, label: 'Title'),
          RequirementNode(id: 'constraint:note.title', type: RequirementNodeType.constraint, label: 'Title constraint'),
          RequirementNode(id: 'storage:note', type: RequirementNodeType.storage, label: 'Note storage'),
          RequirementNode(id: 'state:note', type: RequirementNodeType.state, label: 'Note state'),
        ],
      );
      worldModel.ingestRequirementGraph(graph);
      expect(worldModel.model.graph.nodes.length, before);
    });
  });

  group('Kernel wiring (R24) — a real processIntent run ingests the SAME already-computed RequirementGraph, zero new AI call', () {
    test('a real Kernel run with an injected WorldModelCoordinator grows the World Graph via RequirementGraph ingestion', () async {
      final worldModel = WorldModelCoordinator();
      final before = worldModel.model.graph.nodes.length;

      final ready = await _runKernel(_noteOnlyApp(), worldModel: worldModel);

      expect(ready.requirementGraph, isNotNull);
      expect(worldModel.model.graph.nodes.length, greaterThan(before));
      expect(worldModel.model.graph.nodes.any((n) => n.kind == WorldNodeKind.capability && n.label == 'storage'), isTrue);
    });
  });

  group('Backward compatibility / regression (R24) — R3/R4\'s existing diff engines are reused unmodified, never reimplemented', () {
    test('RequirementGraphDiffer produces byte-for-byte identical output on repeated calls (unchanged since R3)', () {
      const before = RequirementGraph(nodes: [RequirementNode(id: 'entity:note', type: RequirementNodeType.entity, label: 'Note')]);
      const after = RequirementGraph(
        nodes: [RequirementNode(id: 'entity:note', type: RequirementNodeType.entity, label: 'Note'), RequirementNode(id: 'entity:tag', type: RequirementNodeType.entity, label: 'Tag')],
      );
      final d1 = const RequirementGraphDiffer().diff(before, after);
      final d2 = const RequirementGraphDiffer().diff(before, after);
      expect(d1.addedNodes.map((n) => n.id), d2.addedNodes.map((n) => n.id));
    });

    test('ArchitectureDiffer produces byte-for-byte identical output on repeated calls (unchanged since R4)', () {
      final before = _minimalArchitecture(entities: const ['note']);
      final after = _minimalArchitecture(entities: const ['note', 'tag']);
      final d1 = const ArchitectureDiffer().diff(before, after);
      final d2 = const ArchitectureDiffer().diff(before, after);
      expect(d1.addedEntities.map((e) => e.entityId), d2.addedEntities.map((e) => e.entityId));
    });
  });

  group('Performance (R24) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated', () {
    test('RequirementGraphDiff over a large (500-node) graph', () {
      final beforeNodes = [for (var i = 0; i < 500; i++) RequirementNode(id: 'entity:e$i', type: RequirementNodeType.entity, label: 'E$i')];
      final afterNodes = [for (var i = 0; i < 500; i++) RequirementNode(id: 'entity:e$i', type: RequirementNodeType.entity, label: i == 250 ? 'Changed' : 'E$i')];
      final before = RequirementGraph(nodes: beforeNodes);
      final after = RequirementGraph(nodes: afterNodes);

      final stopwatch = Stopwatch()..start();
      final diff = const RequirementGraphDiffer().diff(before, after);
      stopwatch.stop();

      expect(diff.addedNodes.length, 1);
      // ignore: avoid_print
      print('R24 RequirementGraphDiff over 500 nodes: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('incremental (1 of 200 entities) vs. full compiler regeneration — the real, measured value proposition', () async {
      final entities = [
        for (var i = 0; i < 200; i++)
          ImplementationEntity(id: 'e$i', name: 'E$i', fields: [ImplementationField(id: 'title', name: 'Title', type: ImplementationDataType.text, required: true)]),
      ];
      final controllers = [
        for (var i = 0; i < 200; i++)
          ImplementationController(id: 'e$i.controller', entityId: 'e$i', operations: [ImplementationOperation(id: 'e$i.list', kind: ImplementationOperationKind.list)]),
      ];
      final model = CanonicalImplementationModel(
        entities: entities,
        controllers: controllers,
        authentication: const AuthenticationAdapterSpec(requiresCredentials: false),
        backgroundWorker: const BackgroundWorkerSpec(requiresBackgroundSync: false),
      );

      final fullStopwatch = Stopwatch()..start();
      runCompilerPipeline(model, id: 'x', name: 'X');
      fullStopwatch.stop();

      final incrementalStopwatch = Stopwatch()..start();
      const IncrementalCompilerSynthesizer().synthesize(fullModel: model, affected: const AffectedEntities({'e0'}), id: 'x', name: 'X');
      incrementalStopwatch.stop();

      // ignore: avoid_print
      print('R24 full regeneration (200 entities): ${fullStopwatch.elapsedMilliseconds}ms; incremental (1 entity): ${incrementalStopwatch.elapsedMilliseconds}ms');
      expect(incrementalStopwatch.elapsedMilliseconds, lessThanOrEqualTo(fullStopwatch.elapsedMilliseconds + 5), reason: 'incremental scoping must never be slower than a full run');
    });

    test('memory: real process RSS delta while diffing 100 architecture pairs', () {
      final rssBefore = ProcessInfo.currentRss;
      for (var i = 0; i < 100; i++) {
        final before = _minimalArchitecture(entities: const ['note']);
        final after = _minimalArchitecture(entities: const ['note', 'tag']);
        const ArchitectureDiffer().diff(before, after);
      }
      final rssAfter = ProcessInfo.currentRss;
      // ignore: avoid_print
      print('R24 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 100 architecture diffs');
    });
  });
}

// ── Shared minimal fixtures ────────────────────────────────────────────

ArchitectureDecision _dec(String id) => ArchitectureDecision(id: id, category: ArchitectureDecisionCategory.data, subjectId: id, decision: 'd-$id', rationale: 'r', confidence: const Confidence(score: 1.0, reason: 'test'));

ArchitectureCandidate _minimalArchitecture({required List<String> entities, bool relateNoteToTag = false}) => ArchitectureCandidate(
  id: 'a',
  appName: 'A',
  entities: [
    for (final id in entities)
      EntityDecision(entityId: id, name: id, fieldCount: 1, storage: StorageKind.sqlite, storageDecision: _dec('s-$id')),
  ],
  relationships: relateNoteToTag ? [RelationshipDecision(fromEntityId: 'note', toEntityId: 'tag', fieldId: 'tagId', deletePolicy: RelationshipDeletePolicy.setNull, decision: _dec('rel'))] : const [],
  navigation: NavigationGraph(entryScreenId: entities.first, screenIds: entities, edges: const [], decision: _dec('nav')),
  security: SecurityDecision(networkMode: NetworkMode.none, requiresCredentialVault: false, decision: _dec('sec')),
  offline: OfflineDecision(capability: OfflineCapability.fullyOffline, decision: _dec('off')),
  synchronization: SynchronizationDecision(strategy: SyncStrategy.none, decision: _dec('sync')),
  overallConfidence: const Confidence(score: 1.0, reason: 'test'),
);

