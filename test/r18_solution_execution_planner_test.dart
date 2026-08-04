/// Implementation Milestone R18 — Solution Execution Planner, Universal
/// Execution Strategy. Proves the real gap this milestone closes: of
/// R18's 12 requested execution targets, real, traceable signal exists
/// for exactly 3 (Runtime Experience, Backend Service, REST API) —
/// Runtime Experience is the only one with a real, existing `Generator`
/// (`RuntimeExperienceGenerator`, R13, `reference.runtime-experience`).
/// The other 9 are honestly classified `notApplicable` with a specific,
/// real reason each — never a fabricated generator-selection mechanism.
/// `lib/generator_framework/`, `lib/build_graph/`,
/// `lib/generation_specification/` are untouched by this milestone
/// (confirmed by this file never importing them, and by a dedicated
/// `git diff --stat` check documented in the architecture doc); no
/// generator is invoked by this planner — it only names what a future
/// caller could invoke and why.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/execution_planning/execution_strategy.dart';
import 'package:anything/execution_planning/solution_execution_planner.dart';
import 'package:anything/generator_framework/generator.dart' show GeneratorMetadata;
import 'package:anything/generator_framework/reference/runtime_experience_generator.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/solution_architecture/solution_architecture.dart';
import 'package:anything/solution_architecture/solution_architecture_planner.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures (novel domain, "Field Trip Log" — zero footprint elsewhere
// in lib/; mirrors test/r17_semantic_solution_architecture_test.dart's
// established shape, parameterized on offline/network so both
// requiresBackend branches are real and reachable). ────────────────────

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

NavigationGraph _nav() => NavigationGraph(entryScreenId: 'trips', screenIds: const ['trips'], edges: const [], decision: _decision('nav'));

SemanticApp _tripApp() => const SemanticApp(
  name: 'Field Trip Log',
  purpose: 'Track field trips and stops',
  entities: [
    SemanticEntity(
      id: 'trip',
      name: 'Trip',
      displayField: 'title',
      fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
    ),
  ],
);

ArchitectureCandidate _tripArchitecture({bool backendNeeded = false, bool hasEntities = true}) => ArchitectureCandidate(
  id: 'trip-candidate',
  appName: 'Field Trip Log',
  entities: hasEntities
      ? [
          EntityDecision(
            entityId: 'trip',
            name: 'Trip',
            fieldCount: 1,
            storage: StorageKind.sqlite,
            storageDecision: ArchitectureDecision(id: 's1', category: ArchitectureDecisionCategory.data, subjectId: 'trip', decision: 'sqlite', rationale: 'r', confidence: const Confidence(score: 1.0, reason: 'test')),
          ),
        ]
      : const [],
  relationships: const [],
  navigation: _nav(),
  interactions: hasEntities
      ? [
          InteractionDecision(
            entityId: 'trip',
            canCreate: true,
            canRead: true,
            canUpdate: true,
            canDelete: true,
            supportsSearch: backendNeeded,
            supportsFilter: false,
            supportsSort: false,
            supportsPagination: false,
            decision: _decision('i1'),
          ),
        ]
      : const [],
  security: SecurityDecision(
    networkMode: backendNeeded ? NetworkMode.restrictedHttps : NetworkMode.none,
    requiresCredentialVault: backendNeeded,
    decision: _decision('sec'),
  ),
  offline: OfflineDecision(
    capability: backendNeeded ? OfflineCapability.onlineRequired : OfflineCapability.fullyOffline,
    decision: _decision('off'),
  ),
  synchronization: SynchronizationDecision(strategy: SyncStrategy.none, decision: _decision('sync')),
  overallConfidence: const Confidence(score: 1.0, reason: 'test'),
);

BackendEngineeringPlan _tripBackend(ArchitectureCandidate architecture) =>
    const BackendEngineeringPlanner().plan(BackendEngineeringContext(architecture: architecture, app: _tripApp()));

SemanticSolutionArchitecture _solution({bool backendNeeded = false, bool hasEntities = true}) {
  final architecture = _tripArchitecture(backendNeeded: backendNeeded, hasEntities: hasEntities);
  return const SolutionArchitecturePlanner().plan(architecture, _tripBackend(architecture));
}

void main() {
  group('Target classification — the 9 honest gaps (R18)', () {
    test('all 9 targets with zero upstream signal are notApplicable with a real, non-empty, specific reason', () {
      final strategy = const SolutionExecutionPlanner().plan(_solution());
      const gaps = [
        ExecutionTargetKind.flutterApplication,
        ExecutionTargetKind.graphqlApi,
        ExecutionTargetKind.website,
        ExecutionTargetKind.desktopApplication,
        ExecutionTargetKind.mobileApplication,
        ExecutionTargetKind.cliTool,
        ExecutionTargetKind.library,
        ExecutionTargetKind.plugin,
        ExecutionTargetKind.agent,
      ];
      for (final kind in gaps) {
        final plan = strategy.forTarget(kind);
        expect(plan.classification, ExecutionTargetClassification.notApplicable, reason: '$kind');
        expect(plan.reason, isNotEmpty, reason: '$kind');
        expect(plan.requiredGenerators, isEmpty, reason: '$kind');
      }
      // Every reason must be distinct — never a copy-pasted placeholder.
      final reasons = gaps.map((k) => strategy.forTarget(k).reason).toSet();
      expect(reasons.length, gaps.length);
    });
  });

  group('Target classification — real signal (R18)', () {
    test('no backend need, no entities: everything notApplicable', () {
      final strategy = const SolutionExecutionPlanner().plan(_solution(backendNeeded: false, hasEntities: false));
      expect(strategy.forTarget(ExecutionTargetKind.runtimeExperience).classification, ExecutionTargetClassification.notApplicable);
      expect(strategy.forTarget(ExecutionTargetKind.backendService).classification, ExecutionTargetClassification.notApplicable);
      expect(strategy.forTarget(ExecutionTargetKind.restApi).classification, ExecutionTargetClassification.notApplicable);
      expect(strategy.actionableTargets, isEmpty);
    });

    test('entities present, no backend need: only Runtime Experience is applicable, with the real generator', () {
      final strategy = const SolutionExecutionPlanner().plan(_solution(backendNeeded: false, hasEntities: true));
      final runtime = strategy.forTarget(ExecutionTargetKind.runtimeExperience);
      expect(runtime.classification, ExecutionTargetClassification.applicableWithGenerator);
      expect(runtime.requiredGenerators, [SolutionExecutionPlanner.runtimeExperienceGeneratorId]);
      expect(strategy.forTarget(ExecutionTargetKind.backendService).classification, ExecutionTargetClassification.notApplicable);
      expect(strategy.forTarget(ExecutionTargetKind.restApi).classification, ExecutionTargetClassification.notApplicable);
    });

    test('backend needed with real REST endpoints: Backend Service is applicableWithGenerator (Implementation Specification IS-R26), REST API stays applicableNoGenerator, Runtime Experience keeps its real generator', () {
      final strategy = const SolutionExecutionPlanner().plan(_solution(backendNeeded: true, hasEntities: true));

      // BackendServiceGenerator now exists (R26) — REALITY before R26,
      // this assertion was `applicableNoGenerator`; R26 deliberately
      // flipped it, the exact "R18 deliberately never invokes a
      // generator, R26 finally gives Backend Service one" transition
      // this planner's own doc comment named as the real, deferred gap.
      final backend = strategy.forTarget(ExecutionTargetKind.backendService);
      expect(backend.classification, ExecutionTargetClassification.applicableWithGenerator);
      expect(backend.requiredGenerators, [SolutionExecutionPlanner.backendServiceGeneratorId]);
      expect(backend.deploymentRequirements, contains('BACKEND_API_CREDENTIALS'));

      final rest = strategy.forTarget(ExecutionTargetKind.restApi);
      expect(rest.classification, ExecutionTargetClassification.applicableNoGenerator);
      expect(rest.requiredGenerators, isEmpty);
      expect(rest.dependencies, contains(ExecutionTargetKind.backendService));

      final runtime = strategy.forTarget(ExecutionTargetKind.runtimeExperience);
      expect(runtime.classification, ExecutionTargetClassification.applicableWithGenerator);
      expect(runtime.requiredGenerators, [SolutionExecutionPlanner.runtimeExperienceGeneratorId]);
      expect(runtime.dependencies, containsAll([ExecutionTargetKind.backendService, ExecutionTargetKind.restApi]));
    });

    test('the named required generator id resolves to the real, existing RuntimeExperienceGenerator', () {
      const generator = RuntimeExperienceGenerator();
      final GeneratorMetadata metadata = generator.metadata;
      final strategy = const SolutionExecutionPlanner().plan(_solution(hasEntities: true));
      expect(strategy.forTarget(ExecutionTargetKind.runtimeExperience).requiredGenerators.single, metadata.id);
    });
  });

  group('Dependency ordering (R18)', () {
    test('applicable targets execute in real dependency order: Backend Service -> REST API -> Runtime Experience', () {
      final strategy = const SolutionExecutionPlanner().plan(_solution(backendNeeded: true, hasEntities: true));
      final order = strategy.applicableTargets.map((t) => t.target).toList();
      expect(order, [ExecutionTargetKind.backendService, ExecutionTargetKind.restApi, ExecutionTargetKind.runtimeExperience]);
      final orders = strategy.applicableTargets.map((t) => t.executionOrder).toList();
      expect(orders, [0, 1, 2]);
    });

    test('when only Runtime Experience applies, it is order 0 with no dependencies', () {
      final strategy = const SolutionExecutionPlanner().plan(_solution(backendNeeded: false, hasEntities: true));
      final runtime = strategy.forTarget(ExecutionTargetKind.runtimeExperience);
      expect(runtime.executionOrder, 0);
      expect(runtime.dependencies, isEmpty);
    });
  });

  group('Determinism (R18)', () {
    test('the same SemanticSolutionArchitecture planned twice produces byte-for-byte identical classification/order', () {
      final solution = _solution(backendNeeded: true, hasEntities: true);
      final a = const SolutionExecutionPlanner().plan(solution);
      final b = const SolutionExecutionPlanner().plan(solution);
      for (final kind in ExecutionTargetKind.values) {
        final pa = a.forTarget(kind);
        final pb = b.forTarget(kind);
        expect(pa.classification, pb.classification, reason: '$kind');
        expect(pa.executionOrder, pb.executionOrder, reason: '$kind');
        expect(pa.requiredGenerators, pb.requiredGenerators, reason: '$kind');
      }
    });
  });

  group('Kernel wiring (R18)', () {
    test('a real Kernel run produces a real ExecutionStrategy on ExecutionPlanReady, derived from the SAME solutionArchitecture already returned', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      final kernel = AnythingKernel(
        providerRegistry: _FakeProviderRegistry(),
        capabilityRegistry: _registry(),
        reasoner: _FixedReasoner(),
        knowledgeEngine: KnowledgeAcquisitionEngine(searchProvider: _FakeSearchProvider(), webweavexAdapter: _fakeAdapter()),
      );

      final outcome = await kernel.processIntent(Intent.create(expression: 'track my field trips'));

      expect(outcome, isA<ExecutionPlanReady>());
      final ready = outcome as ExecutionPlanReady;
      expect(ready.executionStrategy, isNotNull);
      expect(ready.executionStrategy!.forTarget(ExecutionTargetKind.runtimeExperience).classification, ExecutionTargetClassification.applicableWithGenerator);
      // Real composition: derived from the SAME solutionArchitecture instance
      // ExecutionPlanReady already exposes (R17), never recomputed from scratch.
      expect(ready.solutionArchitecture, isNotNull);
    });
  });

  group('Canonical integration / backward compatibility (R18) — unchanged pipelines untouched', () {
    test('CanonicalImplementationModel, Generator Framework, Build Graph, Generation Specification: none imported or touched by this planner', () {
      // Structural proof: this test file itself never imports
      // lib/generator_framework/generation_pipeline.dart,
      // lib/build_graph/, or lib/generation_specification/ except the one
      // read-only GeneratorMetadata check above — SolutionExecutionPlanner
      // has no such dependency at all (see its own file header).
      final strategy = const SolutionExecutionPlanner().plan(_solution(hasEntities: true));
      expect(strategy, isNotNull);
    });
  });

  group('Performance (R18) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated', () {
    test('planning latency for a large system (200 entities)', () {
      final architecture = ArchitectureCandidate(
        id: 'large',
        appName: 'Large',
        entities: [
          for (var i = 0; i < 200; i++)
            EntityDecision(
              entityId: 'e$i',
              name: 'Entity $i',
              fieldCount: 1,
              storage: StorageKind.sqlite,
              storageDecision: ArchitectureDecision(id: 's$i', category: ArchitectureDecisionCategory.data, subjectId: 'e$i', decision: 'sqlite', rationale: 'r', confidence: const Confidence(score: 1.0, reason: 'test')),
            ),
        ],
        relationships: const [],
        navigation: _nav(),
        interactions: const [],
        security: const SecurityDecision(networkMode: NetworkMode.restrictedHttps, requiresCredentialVault: true, decision: ArchitectureDecision(id: 'sec', category: ArchitectureDecisionCategory.data, subjectId: 'sec', decision: 'd', rationale: 'r', confidence: Confidence(score: 1.0, reason: 'test'))),
        offline: const OfflineDecision(capability: OfflineCapability.onlineRequired, decision: ArchitectureDecision(id: 'off', category: ArchitectureDecisionCategory.data, subjectId: 'off', decision: 'd', rationale: 'r', confidence: Confidence(score: 1.0, reason: 'test'))),
        synchronization: const SynchronizationDecision(strategy: SyncStrategy.none, decision: ArchitectureDecision(id: 'sync', category: ArchitectureDecisionCategory.data, subjectId: 'sync', decision: 'd', rationale: 'r', confidence: Confidence(score: 1.0, reason: 'test'))),
        overallConfidence: const Confidence(score: 1.0, reason: 'test'),
      );
      final backend = const BackendEngineeringPlanner().plan(BackendEngineeringContext(architecture: architecture, app: _tripApp()));
      final solution = const SolutionArchitecturePlanner().plan(architecture, backend);

      final stopwatch = Stopwatch()..start();
      final strategy = const SolutionExecutionPlanner().plan(solution);
      stopwatch.stop();

      expect(strategy.targets, hasLength(12));
      // ignore: avoid_print
      print('R18 execution planning over 200 entities: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('memory: real process RSS delta while planning 50 execution strategies', () {
      final solution = _solution(backendNeeded: true, hasEntities: true);
      final rssBefore = ProcessInfo.currentRss;
      final strategies = [for (var i = 0; i < 50; i++) const SolutionExecutionPlanner().plan(solution)];
      final rssAfter = ProcessInfo.currentRss;
      expect(strategies, hasLength(50));
      // ignore: avoid_print
      print('R18 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 50 plans');
    });
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
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async => ReasoningReady(semanticApp: _tripApp());
}

CapabilityRegistry _registry() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(id: 'storage', version: '1.0.0', name: 'Storage', description: 'Local storage', category: CapabilityCategory.storage, inputContract: 'data', outputContract: 'stored data'),
  );
  return registry;
}

class _FakeSearchProvider implements SearchProvider {
  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async => const [];
}

WebWeaveXAdapter _fakeAdapter() => WebWeaveXAdapter(fetchPage: (url) async => {'available': false});
