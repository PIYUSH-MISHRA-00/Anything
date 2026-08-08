/// Vision V5 MSRA — SolutionComparison: pairwise dominance/equivalence/
/// alternative SolutionGraph edges, computed from real score+complexity
/// comparisons, never guessed.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/feature_discovery/feature_types.dart'
    show ComplexityLevel, FeatureComplexity;
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/solution_reasoning/solution_comparison.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/solution_reasoning/solution_generator.dart';
import 'package:anything/solution_reasoning/solution_score.dart';
import 'package:anything/solution_reasoning/solution_types.dart';
import 'package:anything/solution_reasoning/solution_variation_types.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _architecturePlanner = ArchitecturePlanner();
const _refinementPlanner = RefinementPlanner();
const _requirementExtractor = RequirementExtractor();
const _featureEngine = FeatureDiscoveryEngine();
const _generator = SolutionGenerator();
const _comparison = SolutionComparison();

IntentUnderstanding _understanding() {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: 'test',
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(
      status: ExistingExperienceStatus.notChecked,
    ),
    desiredOutcome: '',
    confidence: 0.9,
    networkNeed: NetworkNeed.none,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

SemanticApp _app() {
  return SemanticApp(
    name: 'Field Survey Log',
    purpose: 'p',
    entities: [
      const SemanticEntity(
        id: 'entry',
        name: 'Entry',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
          ),
        ],
      ),
    ],
  );
}

SolutionScore _uniformScore(double v) {
  final c = Confidence(score: v, reason: 'test');
  return SolutionScore(
    overall: c,
    engineering: c,
    architecture: c,
    maintainability: c,
    runtime: c,
    performance: c,
    security: c,
    offline: c,
    userExperience: c,
    accessibility: c,
    futureEvolution: c,
  );
}

SolutionCandidate _fixture(
  SolutionCandidate base, {
  required String id,
  required double score,
  required ComplexityLevel level,
}) {
  final complexity = FeatureComplexity(
    implementation: level,
    engineering: level,
    runtime: level,
    memoryCost: level,
    storageCost: level,
    batteryCost: level,
    networkCost: level,
    maintenanceCost: level,
    modificationCost: level,
  );
  return SolutionCandidate(
    id: id,
    label: id,
    architecture: base.architecture,
    architectureVariation: base.architectureVariation,
    engineeringVariation: base.engineeringVariation,
    navigationVariation: base.navigationVariation,
    capabilityVariation: base.capabilityVariation,
    offlineVariation: base.offlineVariation,
    synchronizationVariation: base.synchronizationVariation,
    storageVariation: base.storageVariation,
    stateVariation: base.stateVariation,
    dependencies: base.dependencies,
    complexity: complexity,
    tradeoffs: base.tradeoffs,
    score: _uniformScore(score),
    confidence: base.confidence,
    explanation: base.explanation,
  );
}

void main() {
  final app = _app();
  final requirements = _requirementExtractor.extract(
    app: app,
    understanding: _understanding(),
  );
  final featureGraph = _featureEngine.plan(
    FeatureDiscoveryContext(app: app, requirements: requirements),
  );
  final dependencyGraph = const DependencyGraphBuilder().build(
    featureGraph.nodes.map((n) => n.candidate).toList(),
  );
  final context = SolutionExplorationContext(
    app: app,
    featureGraph: featureGraph,
    dependencyGraph: dependencyGraph,
  );
  final baseline = _refinementPlanner
      .refine(_architecturePlanner.plan(app))
      .finalCandidate;
  final real = _generator.build(
    baseline: baseline,
    variation: ArchitectureVariation(
      label: 'Balanced',
      navigationTopology: NavigationTopology.hierarchical,
      capabilityRichness: CapabilityRichness.full,
      offlineStrategy: baseline.offline.capability,
      synchronizationStrategy: baseline.synchronization.strategy,
      rationale: 'r',
    ),
    context: context,
  );

  test(
    'a higher-scoring, no-more-complex candidate dominates a lower-scoring one',
    () {
      final a = _fixture(real, id: 'a', score: 0.9, level: ComplexityLevel.low);
      final b = _fixture(real, id: 'b', score: 0.5, level: ComplexityLevel.low);
      final result = _comparison.compare([a, b]);
      final edge = result.graph.edgesFrom('a').single;
      expect(edge.kind, SolutionRelationKind.dominates);
      expect(edge.toCandidateId, 'b');
    },
  );

  test('equal score and equal complexity are equivalentTo', () {
    final a = _fixture(
      real,
      id: 'a',
      score: 0.7,
      level: ComplexityLevel.medium,
    );
    final b = _fixture(
      real,
      id: 'b',
      score: 0.7,
      level: ComplexityLevel.medium,
    );
    final result = _comparison.compare([a, b]);
    expect(
      result.graph.edgesFrom('a').single.kind,
      SolutionRelationKind.equivalentTo,
    );
  });

  test(
    'a higher score but also higher complexity is a genuine alternative, not dominance',
    () {
      final a = _fixture(
        real,
        id: 'a',
        score: 0.9,
        level: ComplexityLevel.high,
      );
      final b = _fixture(real, id: 'b', score: 0.5, level: ComplexityLevel.low);
      final result = _comparison.compare([a, b]);
      final aToB = result.graph
          .edgesFrom('a')
          .singleWhere((e) => e.toCandidateId == 'b');
      expect(aToB.kind, SolutionRelationKind.alternativeTo);
    },
  );

  test('every node carries its real overall score', () {
    final a = _fixture(real, id: 'a', score: 0.8, level: ComplexityLevel.low);
    final result = _comparison.compare([a]);
    expect(result.graph.nodeById('a')!.overallScore, 0.8);
  });
}
