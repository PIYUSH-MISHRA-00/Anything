/// Engineering-to-Blueprint augmentation — the concrete link between
/// AEE's typed StateMachine model and the real, executable
/// BehaviorGraph/StateSchema the existing, unmodified BehaviorInterpreter
/// already runs.
///
/// This does not touch CreationEngine's existing blueprint-driven
/// interface/behavior/state building at all — it runs strictly *after*
/// CreationEngine has already built a real BehaviorGraph/StateSchema from
/// the blueprint, and appends new nodes/edges/variables on top. When no
/// EngineeringPlan is supplied, nothing here runs and the package is
/// byte-for-byte what CreationEngine always produced — zero risk to any
/// existing caller.
///
/// Concretely: for every action in the blueprint, a new `stateWrite`
/// BehaviorNode is added and wired via a new BehaviorEdge from that
/// action's *already-existing* event node (`'${action.id}_event'`,
/// created by CreationEngine._buildBehaviorFromBlueprint) — so the
/// state-machine transition genuinely fires whenever
/// BehaviorInterpreter dispatches that event, through the same
/// cycle-safe, budget-bounded traversal M2 already certified. One
/// `<entityId>_status` StateVariable is added per entity so the
/// transition has somewhere real to land.
library;

import '../creation/experience_package.dart';
import '../synthesis/app_blueprint.dart';
import 'engineering_plan.dart';
import 'engineering_types.dart';

class EngineeringToBlueprintAugmenter {
  const EngineeringToBlueprintAugmenter();

  /// Maps a blueprint action type to the GenericState it represents while
  /// in flight — never a domain-specific name.
  static const Map<BlueprintActionType, GenericState> _inFlightState = {
    BlueprintActionType.create: GenericState.saving,
    BlueprintActionType.update: GenericState.saving,
    BlueprintActionType.setValue: GenericState.saving,
    BlueprintActionType.increment: GenericState.saving,
    BlueprintActionType.decrement: GenericState.saving,
    BlueprintActionType.changeStatus: GenericState.saving,
    BlueprintActionType.clearValue: GenericState.saving,
    BlueprintActionType.delete: GenericState.deleting,
    BlueprintActionType.toggle: GenericState.saving,
    BlueprintActionType.navigate: GenericState.idle,
  };

  /// Augment [behavior]/[state] (already built by CreationEngine from
  /// [blueprint]) with real status-tracking derived from [plan]. Returns
  /// the same objects unchanged if [plan] is null or was not approved.
  ({BehaviorGraph behavior, StateSchema state}) augment({
    required AppBlueprint blueprint,
    required BehaviorGraph behavior,
    required StateSchema state,
    required EngineeringPlan? plan,
  }) {
    if (plan == null || plan.outcome != EngineeringRefinementOutcome.approved) {
      return (behavior: behavior, state: state);
    }

    final entityIds = blueprint.entities.map((e) => e.id).toSet();
    final newVariables = <StateVariable>[
      ...state.variables,
      for (final entityId in entityIds)
        StateVariable(
          id: '${entityId}_status',
          type: 'string',
          defaultValue: 'idle',
        ),
    ];

    final existingEventIds = behavior.nodes.map((n) => n.id).toSet();
    final newNodes = <BehaviorNode>[...behavior.nodes];
    final newEdges = <BehaviorEdge>[...behavior.edges];

    for (final action in blueprint.actions) {
      final eventNodeId = '${action.id}_event';
      if (!existingEventIds.contains(eventNodeId)) {
        continue; // nothing to attach to
      }
      final target = _inFlightState[action.actionType];
      if (target == null || target == GenericState.idle) continue;

      final statusNodeId = '${action.id}_status_write';
      newNodes.add(
        BehaviorNode(
          id: statusNodeId,
          type: 'stateWrite',
          config: {
            'stateId': '${action.targetEntityId}_status',
            'value': target.name,
          },
        ),
      );
      newEdges.add(BehaviorEdge(from: eventNodeId, to: statusNodeId));
    }

    return (
      behavior: BehaviorGraph(nodes: newNodes, edges: newEdges),
      state: StateSchema(variables: newVariables),
    );
  }
}
