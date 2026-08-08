/// Vision V5 MSRA — SolutionSelector: picks from the Pareto frontier via
/// the ordered tie-break cascade. Never "first candidate wins" — verified
/// by deliberately placing the worse candidate first in the input list.
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
import 'package:anything/solution_reasoning/solution_selector.dart';
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
const _selector = SolutionSelector();

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

SolutionScore _score(
  double overall, {
  double security = 0.5,
  double maintainability = 0.5,
  double offline = 0.5,
  double userExperience = 0.5,
}) {
  Confidence c(double v) => Confidence(score: v, reason: 'test');
  return SolutionScore(
    overall: c(overall),
    engineering: c(overall),
    architecture: c(overall),
    maintainability: c(maintainability),
    runtime: c(overall),
    performance: c(overall),
    security: c(security),
    offline: c(offline),
    userExperience: c(userExperience),
    accessibility: c(overall),
    futureEvolution: c(overall),
  );
}

SolutionCandidate _fixture(
  SolutionCandidate base, {
  required String id,
  required SolutionScore score,
  ComplexityLevel level = ComplexityLevel.low,
  double confidence = 0.9,
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
    score: score,
    confidence: Confidence(score: confidence, reason: 'test'),
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
    'never first-candidate-wins: a worse candidate placed first is not selected',
    () {
      final worse = _fixture(real, id: 'worse', score: _score(0.3));
      final better = _fixture(real, id: 'better', score: _score(0.9));
      final candidates = [worse, better]; // worse is first in the list
      final graph = _comparison.compare(candidates).graph;

      final decision = _selector.select(candidates, graph);

      expect(decision.selected.id, 'better');
      expect(decision.rejected.map((r) => r.candidate.id), contains('worse'));
    },
  );

  test(
    'a dominated candidate is excluded from the Pareto frontier and never selected',
    () {
      final dominated = _fixture(
        real,
        id: 'dominated',
        score: _score(0.5),
        level: ComplexityLevel.high,
      );
      final dominator = _fixture(
        real,
        id: 'dominator',
        score: _score(0.7),
        level: ComplexityLevel.low,
      );
      final candidates = [dominated, dominator];
      final graph = _comparison.compare(candidates).graph;

      final decision = _selector.select(candidates, graph);
      expect(decision.selected.id, 'dominator');
    },
  );

  test(
    'a tie on overall score is broken by security, then maintainability, then offline',
    () {
      final a = _fixture(
        real,
        id: 'a',
        score: _score(0.7, security: 0.9, maintainability: 0.5, offline: 0.5),
      );
      final b = _fixture(
        real,
        id: 'b',
        score: _score(0.7, security: 0.5, maintainability: 0.9, offline: 0.5),
      );
      final candidates = [b, a]; // b (lower security) first in the list
      final graph = _comparison.compare(candidates).graph;

      final decision = _selector.select(candidates, graph);
      expect(decision.selected.id, 'a'); // higher security wins the tie-break
    },
  );

  test('every rejected alternative carries a concrete, non-empty reason', () {
    final worse = _fixture(real, id: 'worse', score: _score(0.3));
    final better = _fixture(real, id: 'better', score: _score(0.9));
    final candidates = [worse, better];
    final graph = _comparison.compare(candidates).graph;

    final decision = _selector.select(candidates, graph);
    for (final r in decision.rejected) {
      expect(r.whyNotSelected, isNotEmpty);
    }
  });
}
