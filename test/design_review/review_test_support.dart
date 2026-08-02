/// Shared test scaffolding for Vision V6 SCARE tests — builds a real,
/// full ReviewContext by running the actual V2-V5 pipeline (Requirement
/// Extraction -> Feature Discovery -> Solution Reasoning -> blueprint
/// conversion), never a hand-rolled fake. Not a test file itself.
library;

import 'package:anything/application_engineering/accessibility_performance_security_engineering.dart'
    show AccessibilityEngineeringResult, SecurityEngineeringResult;
import 'package:anything/application_engineering/engineering_candidate.dart';
import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/design_review/review_context.dart';
import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/dependency_types.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart' show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_to_blueprint.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/solution_reasoning/solution_explorer.dart';
import 'package:anything/solution_reasoning/solution_types.dart';
import 'package:anything/solution_reasoning/solution_variation_types.dart' show EngineeringVariation;
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

IntentUnderstanding testUnderstanding() {
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

/// "Field Survey Log" — zero footprint in lib/. 3 views (list/form/detail)
/// + an http capability, matching the fixture already established for
/// Vision V5's own tests.
SemanticApp fieldSurveyApp() {
  return SemanticApp(
    name: 'Field Survey Log',
    purpose: 'Track field survey entries',
    entities: [
      const SemanticEntity(
        id: 'entry',
        name: 'Entry',
        displayField: 'title',
        fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(id: 'entries_list', name: 'Entries', purpose: 'list', sourceEntityId: 'entry', viewType: BlueprintViewType.list, isDefault: true),
      SemanticView(id: 'entries_form', name: 'Add Entry', purpose: 'form', sourceEntityId: 'entry', viewType: BlueprintViewType.form),
      SemanticView(id: 'entries_detail', name: 'Entry Detail', purpose: 'detail', sourceEntityId: 'entry', viewType: BlueprintViewType.detail),
    ],
    actions: const [SemanticAction(id: 'add_entry', name: 'Add Entry', targetEntityId: 'entry')],
    requiredCapabilities: const ['http'],
  );
}

/// "Equipment Lending Tracker" — three independent entities (Person,
/// Equipment, Loan) each with their own top-level list screen. Loan
/// references both others. Exercises the real, pre-existing
/// NavigationPlanner limitation this milestone's NavigationReviewer had
/// to be taught about: only the entry entity's own list/detail/form
/// screens get an inferred NavigationGraph edge — every other top-level
/// list screen is reachable only through CreationEngine's real bottom
/// navigation (built later, from every non-form view), never through an
/// explicit graph edge.
SemanticApp multiEntityApp() {
  return SemanticApp(
    name: 'Equipment Lending Tracker',
    purpose: 'Manage equipment lending',
    entities: [
      const SemanticEntity(id: 'person', name: 'Person', fields: [SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true)]),
      const SemanticEntity(id: 'equipment', name: 'Equipment', fields: [SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true)]),
      const SemanticEntity(
        id: 'loan',
        name: 'Loan',
        fields: [
          SemanticField(id: 'personId', name: 'Person', type: BlueprintFieldType.reference, referenceEntityId: 'person'),
          SemanticField(id: 'equipmentId', name: 'Equipment', type: BlueprintFieldType.reference, referenceEntityId: 'equipment'),
        ],
      ),
    ],
    views: [
      const SemanticView(id: 'people_list', name: 'People', purpose: 'list', sourceEntityId: 'person', viewType: BlueprintViewType.list, isDefault: true),
      const SemanticView(id: 'equipment_list', name: 'Equipment', purpose: 'list', sourceEntityId: 'equipment', viewType: BlueprintViewType.list),
      const SemanticView(id: 'loans_list', name: 'Loans', purpose: 'list', sourceEntityId: 'loan', viewType: BlueprintViewType.list),
    ],
    actions: [
      const SemanticAction(id: 'add_person', name: 'Add Person', targetEntityId: 'person'),
      const SemanticAction(id: 'add_equipment', name: 'Add Equipment', targetEntityId: 'equipment'),
      const SemanticAction(id: 'add_loan', name: 'Add Loan', targetEntityId: 'loan'),
    ],
  );
}

/// "OrbitMetrics Dashboard" — one entity with a `dashboard`-type entry view
/// (not `list`) plus a separate form view. Exercises a real bug caught by
/// this milestone's own regression run: CreationEngine only wired an
/// "Add entity" button (the real click-path to a form screen) on `list`
/// views, never on `dashboard` views, leaving the form screen genuinely
/// unreachable in the generated app. Fixed by adding the same button to
/// the dashboard case in CreationEngine and teaching NavigationReviewer
/// that both list AND dashboard views anchor their entity's form.
SemanticApp dashboardApp() {
  return SemanticApp(
    name: 'OrbitMetrics Dashboard',
    purpose: 'Dashboard for OrbitMetrics project data',
    entities: [
      const SemanticEntity(
        id: 'metric_entry',
        name: 'MetricEntry',
        fields: [SemanticField(id: 'value', name: 'Value', type: BlueprintFieldType.decimal, required: true)],
      ),
    ],
    views: const [
      SemanticView(
        id: 'metrics_dashboard',
        name: 'Metrics Dashboard',
        purpose: 'View metrics',
        sourceEntityId: 'metric_entry',
        viewType: BlueprintViewType.dashboard,
        isDefault: true,
      ),
      SemanticView(id: 'add_metric', name: 'Add Metric', purpose: 'Record a new metric', sourceEntityId: 'metric_entry', viewType: BlueprintViewType.form),
    ],
    actions: const [SemanticAction(id: 'add_metric_action', name: 'Add Metric', targetEntityId: 'metric_entry')],
  );
}

/// Never actually invoked: `ArchitectureToBlueprintConverter.convert()`
/// only calls `SynthesisPlanner.convertToBlueprint()`, a pure function of
/// the already-approved SemanticApp that never calls `.reason()`.
class UnusedReasoner implements ApplicationReasoner {
  const UnusedReasoner();
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    throw UnimplementedError('Not expected to be called by blueprint conversion.');
  }
}

ReviewContext buildReviewContext(SemanticApp app) {
  final requirements = const RequirementExtractor().extract(app: app, understanding: testUnderstanding());
  final featureGraph = const FeatureDiscoveryEngine().plan(FeatureDiscoveryContext(app: app, requirements: requirements));
  final dependencyGraph = const DependencyGraphBuilder().build(featureGraph.nodes.map((n) => n.candidate).toList());
  final explorationResult = const SolutionExplorer().explore(
    app: app,
    context: SolutionExplorationContext(app: app, featureGraph: featureGraph, dependencyGraph: dependencyGraph),
  );
  final selected = explorationResult.decision!.selected;
  final blueprint = const ArchitectureToBlueprintConverter().convert(
    originalApp: app,
    approved: selected.architecture,
    reasonerForConversion: const UnusedReasoner(),
  );

  return ReviewContext(
    app: app,
    requirements: requirements,
    featureGraph: featureGraph,
    dependencyGraph: dependencyGraph,
    solution: selected,
    blueprint: blueprint,
  );
}

/// Rebuilds a ReviewContext with a deliberately-broken EngineeringCandidate
/// — the standard way these tests manufacture a specific defect for a
/// reviewer to catch, since EngineeringCandidate has no public mutator.
ReviewContext withEngineering(ReviewContext context, EngineeringCandidate engineeringCandidate) {
  final oldSolution = context.solution;
  final oldPlan = oldSolution.engineeringVariation.plan;
  final newPlan = EngineeringPlan(finalCandidate: engineeringCandidate, reviewHistory: oldPlan.reviewHistory, outcome: oldPlan.outcome);
  return _withSolution(context, _copySolutionWith(oldSolution, engineeringVariation: EngineeringVariation(plan: newPlan)));
}

/// Rebuilds a ReviewContext with a deliberately-broken ArchitectureCandidate.
ReviewContext withArchitecture(ReviewContext context, ArchitectureCandidate architecture) {
  return _withSolution(context, _copySolutionWith(context.solution, architecture: architecture));
}

/// Rebuilds a ReviewContext with a deliberately-broken DependencyGraph.
ReviewContext withDependencyGraph(ReviewContext context, DependencyGraph graph) {
  return ReviewContext(
    app: context.app,
    requirements: context.requirements,
    featureGraph: context.featureGraph,
    dependencyGraph: graph,
    solution: context.solution,
    blueprint: context.blueprint,
  );
}

SolutionCandidate _copySolutionWith(
  SolutionCandidate old, {
  ArchitectureCandidate? architecture,
  EngineeringVariation? engineeringVariation,
}) {
  return SolutionCandidate(
    id: old.id,
    label: old.label,
    architecture: architecture ?? old.architecture,
    architectureVariation: old.architectureVariation,
    engineeringVariation: engineeringVariation ?? old.engineeringVariation,
    navigationVariation: old.navigationVariation,
    capabilityVariation: old.capabilityVariation,
    offlineVariation: old.offlineVariation,
    synchronizationVariation: old.synchronizationVariation,
    storageVariation: old.storageVariation,
    stateVariation: old.stateVariation,
    dependencies: old.dependencies,
    complexity: old.complexity,
    tradeoffs: old.tradeoffs,
    score: old.score,
    confidence: old.confidence,
    explanation: old.explanation,
  );
}

/// EngineeringCandidate.copyWith() (V3) only supports overriding
/// iteration/behaviors/bindingGraph/bindingDecision/validations/
/// overallConfidence — security/accessibility aren't included, so tests
/// that need to manufacture a defect in either reconstruct the full
/// candidate directly, copying every other field unchanged.
EngineeringCandidate withSecurityDecisions(EngineeringCandidate engineering, SecurityEngineeringResult security) {
  return EngineeringCandidate(
    id: engineering.id,
    iteration: engineering.iteration,
    behaviors: engineering.behaviors,
    data: engineering.data,
    navigation: engineering.navigation,
    interaction: engineering.interaction,
    bindingGraph: engineering.bindingGraph,
    bindingDecision: engineering.bindingDecision,
    validations: engineering.validations,
    persistence: engineering.persistence,
    offline: engineering.offline,
    synchronization: engineering.synchronization,
    lifecycle: engineering.lifecycle,
    performance: engineering.performance,
    accessibility: engineering.accessibility,
    security: security,
    overallConfidence: engineering.overallConfidence,
  );
}

EngineeringCandidate withAccessibilityDecisions(EngineeringCandidate engineering, AccessibilityEngineeringResult accessibility) {
  return EngineeringCandidate(
    id: engineering.id,
    iteration: engineering.iteration,
    behaviors: engineering.behaviors,
    data: engineering.data,
    navigation: engineering.navigation,
    interaction: engineering.interaction,
    bindingGraph: engineering.bindingGraph,
    bindingDecision: engineering.bindingDecision,
    validations: engineering.validations,
    persistence: engineering.persistence,
    offline: engineering.offline,
    synchronization: engineering.synchronization,
    lifecycle: engineering.lifecycle,
    performance: engineering.performance,
    accessibility: accessibility,
    security: engineering.security,
    overallConfidence: engineering.overallConfidence,
  );
}

ReviewContext _withSolution(ReviewContext context, SolutionCandidate solution) {
  return ReviewContext(
    app: context.app,
    requirements: context.requirements,
    featureGraph: context.featureGraph,
    dependencyGraph: context.dependencyGraph,
    solution: solution,
    blueprint: context.blueprint,
  );
}
