/// Specification Review — cross-references the final AppBlueprint against
/// the ArchitectureCandidate and EngineeringCandidate that produced it,
/// the first point in the pipeline where all three are checked together.
/// StateReviewer/NavigationReviewer/BindingReviewer/BehaviorReviewer each
/// own one graph; SpecificationReviewer owns cross-graph blueprint checks
/// (orphan entities, missing CRUD, dead actions/events) and delegates the
/// rest.
library;

import '../../application_engineering/engineering_types.dart' show BindingKind;
import '../../software_architect/architecture_types.dart' show StateKind;
import '../../software_architect/confidence.dart';
import '../../synthesis/app_blueprint.dart' show BlueprintViewType;
import '../review_context.dart';
import '../review_types.dart';

class StateReviewer {
  const StateReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final issues = <ReviewIssue>[];
    final boundStateIds = context.engineering.bindingGraph.edgesOfKind(BindingKind.stateToData).map((e) => e.fromId).toSet();

    for (final state in context.architecture.states) {
      if (state.kind != StateKind.reactive) continue; // only reactive state has an expected binding
      if (!boundStateIds.contains(state.stateId)) {
        issues.add(
          ReviewIssue(
            id: 'state:dead:${state.stateId}',
            category: ReviewCategory.state,
            severity: ReviewSeverity.warning,
            reason: '"${state.stateId}" is declared reactive state with no binding to any data source',
            evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.states', affectedNodeId: state.stateId),
            recommendation: const ReviewRecommendation(description: 'Confirm this state is intentional, or remove it'),
            confidence: Confidence.full,
          ),
        );
      }
    }
    return issues;
  }
}

class NavigationReviewer {
  const NavigationReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final nav = context.architecture.navigation;
    final issues = <ReviewIssue>[];
    final edgeReachable = <String>{nav.entryScreenId, ...nav.edges.map((e) => e.toScreenId)};

    // CreationEngine gives every non-form view a real bottom-navigation
    // entry once there is more than one view (see
    // CreationEngine._buildInterfaceFromBlueprint) — a second, real
    // reachability path this graph alone doesn't record. Only form
    // screens (reachable solely via an explicit "Add"/"Edit" trigger)
    // can ever be genuinely unreachable.
    final formViews = context.blueprint.views.where((v) => v.viewType == BlueprintViewType.form);
    final formScreenIds = formViews.map((v) => v.id).toSet();
    final bottomNavExists = context.blueprint.views.length > 1;

    // CreationEngine wires a real "Add <Entity>" button — which routes to
    // that entity's form screen — on every list AND dashboard view for the
    // same entity (see CreationEngine._buildInterfaceFromBlueprint). A form
    // screen is reachable if any such anchor view exists for its entity.
    final entitiesWithCreateAnchor = context.blueprint.views
        .where((v) => v.viewType == BlueprintViewType.list || v.viewType == BlueprintViewType.dashboard)
        .map((v) => v.sourceEntityId)
        .whereType<String>()
        .toSet();
    final formEntityByScreenId = {for (final v in formViews) v.id: v.sourceEntityId};

    for (final screenId in nav.screenIds) {
      if (edgeReachable.contains(screenId)) continue;
      final isFormScreen = formScreenIds.contains(screenId);
      if (!isFormScreen && bottomNavExists) continue;
      if (isFormScreen && entitiesWithCreateAnchor.contains(formEntityByScreenId[screenId])) continue;

      issues.add(
        ReviewIssue(
          id: 'navigation:unreachable:$screenId',
          category: ReviewCategory.navigation,
          severity: ReviewSeverity.critical,
          reason: 'Screen "$screenId" has no incoming navigation edge and is not the entry screen',
          evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.navigation', affectedNodeId: screenId),
          recommendation: const ReviewRecommendation(description: 'Add a navigation edge to this screen, or remove it'),
          confidence: Confidence.full,
        ),
      );
    }
    return issues;
  }
}

class BindingReviewer {
  const BindingReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final issues = <ReviewIssue>[];
    final entityIds = context.architecture.entities.map((e) => e.entityId).toSet();

    for (final edge in context.engineering.bindingGraph.edgesOfKind(BindingKind.stateToData)) {
      if (!entityIds.contains(edge.toId)) {
        issues.add(
          ReviewIssue(
            id: 'binding:dead:${edge.fromId}->${edge.toId}',
            category: ReviewCategory.binding,
            severity: ReviewSeverity.critical,
            reason: 'Binding "${edge.fromId} -> ${edge.toId}" targets an entity not in this architecture',
            evidence: ReviewEvidence(affectedGraph: 'EngineeringCandidate.bindingGraph', affectedNodeId: '${edge.fromId}->${edge.toId}'),
            recommendation: const ReviewRecommendation(description: 'Drop the dead binding', autoApplicable: true),
            confidence: Confidence.full,
          ),
        );
      }
    }
    return issues;
  }
}

class BehaviorReviewer {
  const BehaviorReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final issues = <ReviewIssue>[];
    for (final behavior in context.engineering.behaviors) {
      final eventedActionIds = behavior.eventGraph.events.map((e) => e.actionId).toSet();
      for (final action in behavior.eventGraph.actions) {
        if (!eventedActionIds.contains(action.id)) {
          issues.add(
            ReviewIssue(
              id: 'behavior:dead:${action.id}',
              category: ReviewCategory.behavior,
              severity: ReviewSeverity.warning,
              reason: 'Action "${action.id}" is declared but no event ever triggers it',
              evidence: ReviewEvidence(affectedGraph: 'EngineeringCandidate.behaviors', affectedNodeId: action.id),
              recommendation: const ReviewRecommendation(description: 'Add a triggering event, or remove the unreachable action'),
              confidence: Confidence.full,
            ),
          );
        }
      }
    }
    return issues;
  }
}

class SpecificationReviewer {
  const SpecificationReviewer({
    this.stateReviewer = const StateReviewer(),
    this.navigationReviewer = const NavigationReviewer(),
    this.bindingReviewer = const BindingReviewer(),
    this.behaviorReviewer = const BehaviorReviewer(),
  });

  final StateReviewer stateReviewer;
  final NavigationReviewer navigationReviewer;
  final BindingReviewer bindingReviewer;
  final BehaviorReviewer behaviorReviewer;

  List<ReviewIssue> review(ReviewContext context) {
    final issues = <ReviewIssue>[
      ...stateReviewer.review(context),
      ...navigationReviewer.review(context),
      ...bindingReviewer.review(context),
      ...behaviorReviewer.review(context),
    ];

    final blueprint = context.blueprint;
    final architectureEntityIds = context.architecture.entities.map((e) => e.entityId).toSet();

    // Orphan entities: in the blueprint but not in the approved architecture.
    for (final entity in blueprint.entities) {
      if (!architectureEntityIds.contains(entity.id)) {
        issues.add(
          ReviewIssue(
            id: 'specification:orphan:${entity.id}',
            category: ReviewCategory.specification,
            severity: ReviewSeverity.critical,
            reason: 'Blueprint entity "${entity.id}" has no corresponding architecture decision',
            evidence: ReviewEvidence(affectedGraph: 'AppBlueprint.entities', affectedNodeId: entity.id),
            recommendation: const ReviewRecommendation(description: 'Reconcile the blueprint with the approved architecture'),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Missing CRUD: architecture says an entity can be created, but the
    // blueprint declares no create-type action for it.
    final createActionEntities = blueprint.actions
        .where((a) => a.actionType.name == 'create')
        .map((a) => a.targetEntityId)
        .toSet();
    for (final interaction in context.architecture.interactions) {
      if (interaction.canCreate && !createActionEntities.contains(interaction.entityId)) {
        issues.add(
          ReviewIssue(
            id: 'specification:missingCrud:${interaction.entityId}',
            category: ReviewCategory.specification,
            severity: ReviewSeverity.critical,
            reason: 'Architecture allows creating "${interaction.entityId}" but the blueprint declares no create action',
            evidence: ReviewEvidence(affectedGraph: 'AppBlueprint.actions', affectedNodeId: interaction.entityId),
            recommendation: const ReviewRecommendation(description: 'Add the missing create action to the blueprint'),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Dead actions: a blueprint action with no engineered event node.
    final allEventIds = context.engineering.behaviors.expand((b) => b.eventGraph.events).map((e) => e.actionId).toSet();
    for (final action in blueprint.actions) {
      if (!allEventIds.contains('action:${action.targetEntityId}:${action.actionType.name}') &&
          !allEventIds.any((id) => id.contains(action.targetEntityId))) {
        issues.add(
          ReviewIssue(
            id: 'specification:deadAction:${action.id}',
            category: ReviewCategory.specification,
            severity: ReviewSeverity.info,
            reason: 'Blueprint action "${action.id}" has no matching engineered event for its entity',
            evidence: ReviewEvidence(affectedGraph: 'AppBlueprint.actions', affectedNodeId: action.id),
            recommendation: const ReviewRecommendation(description: 'Confirm this action is still needed'),
            confidence: const Confidence(score: 0.5, reason: 'Event-id matching is structural, not a guaranteed 1:1 mapping.'),
          ),
        );
      }
    }

    return issues;
  }
}
