/// Vision V5 MSRA — SolutionExplorer: Architecture Exploration -> Multi-
/// Solution Generation -> Tradeoff Analysis -> Review -> Refinement ->
/// Selection. Never exactly one candidate.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/solution_reasoning/solution_explorer.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/solution_reasoning/solution_variation_types.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _requirementExtractor = RequirementExtractor();
const _featureEngine = FeatureDiscoveryEngine();
const _explorer = SolutionExplorer();

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

/// "Field Survey Log" — zero footprint in lib/. 3 views (list/form/detail)
/// + an http capability, so all four variation axes are exercised: Balanced,
/// Minimal, Flat Navigation (>=3 screens), and Offline First (network-using
/// baseline).
SemanticApp _fieldSurveyApp() {
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
      SemanticView(
        id: 'entries_form',
        name: 'Add Entry',
        purpose: 'form',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.form,
      ),
      SemanticView(
        id: 'entries_detail',
        name: 'Entry Detail',
        purpose: 'detail',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.detail,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_entry',
        name: 'Add Entry',
        targetEntityId: 'entry',
      ),
    ],
    requiredCapabilities: const ['http'],
  );
}

/// "Single Screen Note" — a minimal app with only one view, so Flat
/// Navigation shouldn't apply, and no network capability, so Offline
/// First shouldn't apply either — exercising the floor case of exactly
/// the two always-generated candidates (Balanced, Minimal).
SemanticApp _singleScreenApp() {
  return SemanticApp(
    name: 'Single Screen Note',
    purpose: 'A single note',
    entities: [
      const SemanticEntity(
        id: 'note',
        name: 'Note',
        fields: [
          SemanticField(
            id: 'text',
            name: 'Text',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
  );
}

SolutionExplorationContext _contextFor(SemanticApp app) {
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
  return SolutionExplorationContext(
    app: app,
    featureGraph: featureGraph,
    dependencyGraph: dependencyGraph,
  );
}

void main() {
  test('generates at least two candidates — never exactly one', () {
    final app = _singleScreenApp();
    final result = _explorer.explore(app: app, context: _contextFor(app));
    expect(result.error, isNull);
    expect(result.history!.finalCandidates.length, greaterThanOrEqualTo(2));
  });

  test(
    'generates Flat Navigation and Offline First when structurally applicable',
    () {
      final app = _fieldSurveyApp();
      final result = _explorer.explore(app: app, context: _contextFor(app));
      expect(result.error, isNull);
      final labels = result.history!.finalCandidates
          .map((c) => c.label)
          .toSet();
      expect(labels, contains('Balanced'));
      expect(labels, contains('Minimal'));
      expect(labels, contains('Flat Navigation'));
      expect(labels, contains('Offline First'));
    },
  );

  test(
    'does NOT generate Flat Navigation or Offline First when not applicable',
    () {
      final app = _singleScreenApp();
      final result = _explorer.explore(app: app, context: _contextFor(app));
      final labels = result.history!.finalCandidates
          .map((c) => c.label)
          .toSet();
      expect(labels, isNot(contains('Flat Navigation')));
      expect(labels, isNot(contains('Offline First')));
    },
  );

  test(
    'candidates genuinely differ in navigation topology and offline strategy',
    () {
      final app = _fieldSurveyApp();
      final result = _explorer.explore(app: app, context: _contextFor(app));
      final flat = result.history!.finalCandidates.firstWhere(
        (c) => c.label == 'Flat Navigation',
      );
      final balanced = result.history!.finalCandidates.firstWhere(
        (c) => c.label == 'Balanced',
      );
      expect(flat.navigationVariation.topology, NavigationTopology.flat);
      expect(
        balanced.navigationVariation.topology,
        NavigationTopology.hierarchical,
      );

      final offlineFirst = result.history!.finalCandidates.firstWhere(
        (c) => c.label == 'Offline First',
      );
      expect(offlineFirst.offlineVariation.strategy.name, 'fullyOffline');
    },
  );

  test(
    'returns a decision with a selected candidate and real rejected alternatives',
    () {
      final app = _fieldSurveyApp();
      final result = _explorer.explore(app: app, context: _contextFor(app));
      final decision = result.decision!;
      expect(decision.selected, isNotNull);
      expect(
        decision.rejected.length,
        result.history!.finalCandidates.length - 1,
      );
      expect(decision.rationale, isNotEmpty);
    },
  );

  test('every candidate carries a complete 15-dimension tradeoff table', () {
    final app = _fieldSurveyApp();
    final result = _explorer.explore(app: app, context: _contextFor(app));
    for (final c in result.history!.finalCandidates) {
      expect(c.tradeoffs, hasLength(15));
    }
  });
}
