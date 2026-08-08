/// Vision V5 MSRA — SolutionScorer: real, deterministic, self-explaining
/// scores (every dimension is a Confidence with a concrete reason) and a
/// complete 15-dimension tradeoff table.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/architecture_types.dart'
    show OfflineCapability;
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/solution_reasoning/solution_generator.dart';
import 'package:anything/solution_reasoning/solution_scorer.dart';
import 'package:anything/solution_reasoning/solution_tradeoff.dart';
import 'package:anything/solution_reasoning/solution_variation_types.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _architecturePlanner = ArchitecturePlanner();
const _refinementPlanner = RefinementPlanner();
const _requirementExtractor = RequirementExtractor();
const _featureEngine = FeatureDiscoveryEngine();
const _generator = SolutionGenerator();
const _scorer = SolutionScorer();

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
    purpose: 'Track field survey entries',
    entities: [
      const SemanticEntity(
        id: 'entry',
        name: 'Entry',
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
    views: const [
      SemanticView(
        id: 'entries_list',
        name: 'Entries',
        purpose: 'list',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_entry',
        name: 'Add Entry',
        targetEntityId: 'entry',
      ),
    ],
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

  test(
    'minimal richness scores higher on maintainability/runtime/performance than full',
    () {
      final full = _generator.build(
        baseline: baseline,
        variation: ArchitectureVariation(
          label: 'Full',
          navigationTopology: NavigationTopology.hierarchical,
          capabilityRichness: CapabilityRichness.full,
          offlineStrategy: baseline.offline.capability,
          synchronizationStrategy: baseline.synchronization.strategy,
          rationale: 'r',
        ),
        context: context,
      );
      final minimal = _generator.build(
        baseline: baseline,
        variation: ArchitectureVariation(
          label: 'Minimal',
          navigationTopology: NavigationTopology.hierarchical,
          capabilityRichness: CapabilityRichness.minimal,
          offlineStrategy: baseline.offline.capability,
          synchronizationStrategy: baseline.synchronization.strategy,
          rationale: 'r',
        ),
        context: context,
      );

      final fullScore = _scorer.score(full);
      final minimalScore = _scorer.score(minimal);

      expect(
        minimalScore.maintainability.score,
        greaterThan(fullScore.maintainability.score),
      );
      expect(minimalScore.runtime.score, greaterThan(fullScore.runtime.score));
      expect(
        fullScore.userExperience.score,
        greaterThan(minimalScore.userExperience.score),
      );
    },
  );

  test(
    'offline scores rank fullyOffline > cacheThenOnline > onlineRequired',
    () {
      ArchitectureVariation withOffline(
        String label,
        OfflineCapability strategy,
      ) => ArchitectureVariation(
        label: label,
        navigationTopology: NavigationTopology.hierarchical,
        capabilityRichness: CapabilityRichness.full,
        offlineStrategy: strategy,
        synchronizationStrategy: baseline.synchronization.strategy,
        rationale: 'r',
      );

      final offlineFirst = _scorer.score(
        _generator.build(
          baseline: baseline,
          variation: withOffline('A', OfflineCapability.fullyOffline),
          context: context,
        ),
      );
      final cacheFirst = _scorer.score(
        _generator.build(
          baseline: baseline,
          variation: withOffline('B', OfflineCapability.cacheThenOnline),
          context: context,
        ),
      );
      final onlineRequired = _scorer.score(
        _generator.build(
          baseline: baseline,
          variation: withOffline('C', OfflineCapability.onlineRequired),
          context: context,
        ),
      );

      expect(offlineFirst.offline.score, greaterThan(cacheFirst.offline.score));
      expect(
        cacheFirst.offline.score,
        greaterThan(onlineRequired.offline.score),
      );
    },
  );

  test('every score is a Confidence with a concrete, non-empty reason', () {
    final candidate = _generator.build(
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
    final score = _scorer.score(candidate);
    for (final c in [
      score.overall,
      score.engineering,
      score.architecture,
      score.maintainability,
      score.runtime,
      score.performance,
      score.security,
      score.offline,
      score.userExperience,
      score.accessibility,
      score.futureEvolution,
    ]) {
      expect(c.reason, isNotEmpty);
      expect(c.score, inInclusiveRange(0.0, 1.0));
    }
  });

  test('tradeoffs cover all 15 TradeoffDimension values exactly once', () {
    final candidate = _generator.build(
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
    final tradeoffs = _scorer.tradeoffs(candidate);
    final dimensions = tradeoffs.map((t) => t.dimension).toSet();
    expect(dimensions, TradeoffDimension.values.toSet());
    expect(tradeoffs, hasLength(TradeoffDimension.values.length));
    for (final t in tradeoffs) {
      expect(t.rationale, isNotEmpty);
      expect(t.description, isNotEmpty);
    }
  });
}
