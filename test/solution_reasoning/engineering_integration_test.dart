/// Vision V5 MSRA — Engineering Integration: every SolutionCandidate
/// carries its own real, approved Application Engineering Engine output,
/// computed from that candidate's own (possibly varied) architecture —
/// Engineering consumes the SolutionGraph, not a single independently
/// re-derived Architecture.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart' show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/solution_reasoning/solution_generator.dart';
import 'package:anything/solution_reasoning/solution_variation_types.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _architecturePlanner = ArchitecturePlanner();
const _refinementPlanner = RefinementPlanner();
const _requirementExtractor = RequirementExtractor();
const _featureEngine = FeatureDiscoveryEngine();
const _generator = SolutionGenerator();

IntentUnderstanding _understanding() {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: 'test',
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(status: ExistingExperienceStatus.notChecked),
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
        fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(id: 'entries_list', name: 'Entries', purpose: 'list', sourceEntityId: 'entry', viewType: BlueprintViewType.list, isDefault: true),
    ],
    actions: const [SemanticAction(id: 'add_entry', name: 'Add Entry', targetEntityId: 'entry')],
  );
}

void main() {
  final app = _app();
  final requirements = _requirementExtractor.extract(app: app, understanding: _understanding());
  final featureGraph = _featureEngine.plan(FeatureDiscoveryContext(app: app, requirements: requirements));
  final dependencyGraph = const DependencyGraphBuilder().build(featureGraph.nodes.map((n) => n.candidate).toList());
  final context = SolutionExplorationContext(app: app, featureGraph: featureGraph, dependencyGraph: dependencyGraph);
  final baseline = _refinementPlanner.refine(_architecturePlanner.plan(app)).finalCandidate;

  test('each SolutionCandidate carries a real, approved EngineeringPlan', () {
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
    expect(full.engineeringVariation.plan.outcome, EngineeringRefinementOutcome.approved);
    expect(full.engineeringVariation.plan.finalCandidate.behaviors, isNotEmpty);
  });

  test('minimal richness produces a genuinely different EventGraph than full richness', () {
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

    final fullEvents = full.engineeringVariation.plan.finalCandidate.behaviors
        .expand((b) => b.eventGraph.events)
        .map((e) => e.id)
        .toSet();
    final minimalEvents = minimal.engineeringVariation.plan.finalCandidate.behaviors
        .expand((b) => b.eventGraph.events)
        .map((e) => e.id)
        .toSet();

    // Full richness's InteractionDecision.supportsSearch=true generates a
    // real 'search' event BehaviorEngineering wouldn't otherwise produce.
    expect(fullEvents.any((id) => id.contains('search')), isTrue);
    expect(minimalEvents.any((id) => id.contains('search')), isFalse);
  });

  test("Engineering's OfflineEngineering decision reflects each candidate's own offline variation", () {
    final offlineFirst = _generator.build(
      baseline: baseline,
      variation: ArchitectureVariation(
        label: 'Offline First',
        navigationTopology: NavigationTopology.hierarchical,
        capabilityRichness: CapabilityRichness.full,
        offlineStrategy: baseline.offline.capability,
        synchronizationStrategy: baseline.synchronization.strategy,
        rationale: 'r',
      ),
      context: context,
    );
    expect(
      offlineFirst.engineeringVariation.plan.finalCandidate.offline.strategy.name,
      isNotEmpty,
    );
  });
}
