/// Vision V5 MSRA — SolutionReviewer: real, structural defect detection
/// across the full candidate list.
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
import 'package:anything/software_architect/architecture_types.dart'
    show InteractionDecision, OfflineCapability;
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/solution_reasoning/solution_generator.dart';
import 'package:anything/solution_reasoning/solution_reviewer.dart';
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
const _reviewer = SolutionReviewer();

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

SolutionScore _score(double v) {
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

  SolutionCandidate balanced({
    String label = 'Balanced',
    OfflineCapability? offline,
  }) {
    final variation = ArchitectureVariation(
      label: label,
      navigationTopology: NavigationTopology.hierarchical,
      capabilityRichness: CapabilityRichness.full,
      offlineStrategy: offline ?? baseline.offline.capability,
      synchronizationStrategy: baseline.synchronization.strategy,
      rationale: 'r',
    );
    return _generator
        .build(baseline: baseline, variation: variation, context: context)
        .copyWith(score: _score(0.8));
  }

  test('a clean, distinct candidate list produces no critical issues', () {
    final a = balanced(label: 'A');
    final b = _generator
        .build(
          baseline: baseline,
          variation: ArchitectureVariation(
            label: 'B',
            navigationTopology: NavigationTopology.flat,
            capabilityRichness: CapabilityRichness.minimal,
            offlineStrategy: baseline.offline.capability,
            synchronizationStrategy: baseline.synchronization.strategy,
            rationale: 'r',
          ),
          context: context,
        )
        .copyWith(score: _score(0.6));
    final result = _reviewer.review([a, b]);
    expect(result.hasCriticalIssues, isFalse);
  });

  test(
    'two structurally identical variations are flagged duplicate and auto-fixable',
    () {
      final a = balanced(label: 'A');
      final b = balanced(
        label: 'B',
      ); // identical variation axes, different label
      final result = _reviewer.review([a, b]);
      final issue = result.issues.firstWhere(
        (i) => i.category == SolutionIssueCategory.duplicate,
      );
      expect(issue.severity, SolutionIssueSeverity.critical);
      expect(issue.autoFixable, isTrue);
    },
  );

  test(
    'onlineRequired with no network capability is impossible and auto-fixable',
    () {
      final impossible = balanced(
        label: 'Impossible',
        offline: OfflineCapability.onlineRequired,
      );
      final result = _reviewer.review([impossible]);
      final issue = result.issues.firstWhere(
        (i) => i.category == SolutionIssueCategory.impossible,
      );
      expect(issue.severity, SolutionIssueSeverity.critical);
      expect(issue.autoFixable, isTrue);
    },
  );

  test(
    'full richness with no rich interaction is contradictory and auto-fixable',
    () {
      final candidate = balanced(label: 'Contradictory');
      // Manufacture the defect: strip every interaction's search/filter/sort
      // support while the CapabilityVariation still claims "full" — a
      // sanity/regression guard against a hypothetical generator bug, not a
      // condition the real SolutionGenerator produces today.
      final flattenedInteractions = candidate.architecture.interactions
          .map(
            (i) => InteractionDecision(
              entityId: i.entityId,
              canCreate: i.canCreate,
              canRead: i.canRead,
              canUpdate: i.canUpdate,
              canDelete: i.canDelete,
              supportsSearch: false,
              supportsFilter: false,
              supportsSort: false,
              supportsPagination: i.supportsPagination,
              decision: i.decision,
            ),
          )
          .toList();
      final architecture = candidate.architecture.copyWith(
        interactions: flattenedInteractions,
      );
      final contradictory = SolutionCandidate(
        id: 'contradictory',
        label: 'Contradictory',
        architecture: architecture,
        architectureVariation: candidate.architectureVariation,
        engineeringVariation: candidate.engineeringVariation,
        navigationVariation: candidate.navigationVariation,
        capabilityVariation: candidate.capabilityVariation,
        offlineVariation: candidate.offlineVariation,
        synchronizationVariation: candidate.synchronizationVariation,
        storageVariation: candidate.storageVariation,
        stateVariation: candidate.stateVariation,
        dependencies: candidate.dependencies,
        complexity: candidate.complexity,
        confidence: candidate.confidence,
        explanation: candidate.explanation,
        score: _score(0.8),
      );
      final result = _reviewer.review([contradictory]);
      final issue = result.issues.firstWhere(
        (i) => i.category == SolutionIssueCategory.contradictory,
      );
      expect(issue.severity, SolutionIssueSeverity.critical);
      expect(issue.autoFixable, isTrue);
    },
  );

  test('a low-scoring candidate is flagged weak (warning, not critical)', () {
    final weak = balanced(label: 'Weak').copyWith(score: _score(0.2));
    final result = _reviewer.review([weak]);
    final issue = result.issues.firstWhere(
      (i) => i.category == SolutionIssueCategory.weak,
    );
    expect(issue.severity, SolutionIssueSeverity.warning);
  });

  test(
    'two differently-varied candidates that score equivalently are flagged info',
    () {
      final a = _generator
          .build(
            baseline: baseline,
            variation: ArchitectureVariation(
              label: 'A',
              navigationTopology: NavigationTopology.hierarchical,
              capabilityRichness: CapabilityRichness.full,
              offlineStrategy: baseline.offline.capability,
              synchronizationStrategy: baseline.synchronization.strategy,
              rationale: 'r',
            ),
            context: context,
          )
          .copyWith(score: _score(0.7));
      final b = _generator
          .build(
            baseline: baseline,
            variation: ArchitectureVariation(
              label: 'B',
              navigationTopology: NavigationTopology.flat,
              capabilityRichness: CapabilityRichness.minimal,
              offlineStrategy: baseline.offline.capability,
              synchronizationStrategy: baseline.synchronization.strategy,
              rationale: 'r',
            ),
            context: context,
          )
          .copyWith(score: _score(0.7));
      final result = _reviewer.review([a, b]);
      final issue = result.issues.firstWhere(
        (i) => i.category == SolutionIssueCategory.equivalent,
      );
      expect(issue.severity, SolutionIssueSeverity.info);
    },
  );

  test(
    'high engineering complexity without the best score is flagged over-engineered',
    () {
      final best = balanced(label: 'Best').copyWith(score: _score(0.9));
      final expensive = balanced(
        label: 'Expensive',
      ).copyWith(score: _score(0.6));
      final highComplexity = SolutionCandidate(
        id: expensive.id,
        label: expensive.label,
        architecture: expensive.architecture,
        architectureVariation: expensive.architectureVariation,
        engineeringVariation: expensive.engineeringVariation,
        navigationVariation: expensive.navigationVariation,
        capabilityVariation: expensive.capabilityVariation,
        offlineVariation: expensive.offlineVariation,
        synchronizationVariation: expensive.synchronizationVariation,
        storageVariation: expensive.storageVariation,
        stateVariation: expensive.stateVariation,
        dependencies: expensive.dependencies,
        complexity: FeatureComplexity(
          implementation: ComplexityLevel.high,
          engineering: ComplexityLevel.high,
          runtime: ComplexityLevel.high,
          memoryCost: ComplexityLevel.high,
          storageCost: ComplexityLevel.high,
          batteryCost: ComplexityLevel.high,
          networkCost: ComplexityLevel.high,
          maintenanceCost: ComplexityLevel.high,
          modificationCost: ComplexityLevel.high,
        ),
        confidence: expensive.confidence,
        explanation: expensive.explanation,
        score: expensive.score,
      );
      final result = _reviewer.review([best, highComplexity]);
      final issue = result.issues.firstWhere(
        (i) => i.category == SolutionIssueCategory.overEngineered,
      );
      expect(issue.severity, SolutionIssueSeverity.warning);
      expect(issue.subjectId, expensive.id);
    },
  );

  test('a candidate with zero entities is incomplete and auto-fixable', () {
    final complete = balanced(label: 'Complete');
    final emptyArchitecture = complete.architecture.copyWith(
      entities: const [],
    );
    final incomplete = SolutionCandidate(
      id: 'incomplete',
      label: 'Incomplete',
      architecture: emptyArchitecture,
      architectureVariation: complete.architectureVariation,
      engineeringVariation: complete.engineeringVariation,
      navigationVariation: complete.navigationVariation,
      capabilityVariation: complete.capabilityVariation,
      offlineVariation: complete.offlineVariation,
      synchronizationVariation: complete.synchronizationVariation,
      storageVariation: complete.storageVariation,
      stateVariation: complete.stateVariation,
      dependencies: complete.dependencies,
      complexity: complete.complexity,
      confidence: complete.confidence,
      explanation: complete.explanation,
      score: _score(0.8),
    );
    final result = _reviewer.review([incomplete]);
    final issue = result.issues.firstWhere(
      (i) => i.category == SolutionIssueCategory.incomplete,
    );
    expect(issue.severity, SolutionIssueSeverity.critical);
    expect(issue.autoFixable, isTrue);
  });
}
