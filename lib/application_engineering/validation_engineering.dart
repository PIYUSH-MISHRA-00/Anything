/// Validation Engineering — entity/relationship/action/transition-level
/// validation rules, complementing V2's field-level ValidationPlanner.
library;

import '../software_architect/architecture_candidate.dart';
import '../software_architect/confidence.dart';
import 'engineering_types.dart';

enum EngineeringValidationScope { entity, relationship, action, transition }

class EngineeringValidationRule {
  final EngineeringValidationScope scope;
  final String subjectId;
  final bool satisfied;
  final EngineeringDecision decision;

  const EngineeringValidationRule({
    required this.scope,
    required this.subjectId,
    required this.satisfied,
    required this.decision,
  });
}

class ValidationEngineering {
  const ValidationEngineering();

  List<EngineeringValidationRule> plan({
    required ArchitectureCandidate candidate,
    required List<EventGraph> eventGraphs,
    required List<StateMachineDefinition> stateMachines,
  }) {
    final rules = <EngineeringValidationRule>[];

    for (final entity in candidate.entities) {
      final satisfied = entity.fieldCount > 0;
      rules.add(
        EngineeringValidationRule(
          scope: EngineeringValidationScope.entity,
          subjectId: entity.entityId,
          satisfied: satisfied,
          decision: EngineeringDecision(
            id: 'validation:entity:${entity.entityId}',
            category: EngineeringDecisionCategory.validation,
            subjectId: entity.entityId,
            decision: satisfied
                ? '${entity.name} has persistable fields'
                : '${entity.name} has no fields',
            rationale:
                'An entity with zero fields cannot be meaningfully displayed or persisted.',
            confidence: Confidence.full,
          ),
        ),
      );
    }

    for (final rel in candidate.relationships) {
      rules.add(
        EngineeringValidationRule(
          scope: EngineeringValidationScope.relationship,
          subjectId: '${rel.fromEntityId}.${rel.fieldId}',
          satisfied: true, // RelationshipPlanner always assigns a policy
          decision: EngineeringDecision(
            id: 'validation:relationship:${rel.fromEntityId}.${rel.fieldId}',
            category: EngineeringDecisionCategory.validation,
            subjectId: '${rel.fromEntityId}.${rel.fieldId}',
            decision: 'Delete policy is explicitly ${rel.deletePolicy.name}',
            rationale:
                'Every relationship must have an explicit delete policy — never left undefined.',
            confidence: Confidence.full,
          ),
        ),
      );
    }

    for (final graph in eventGraphs) {
      for (final action in graph.actions) {
        final satisfied = action.effects.isNotEmpty;
        rules.add(
          EngineeringValidationRule(
            scope: EngineeringValidationScope.action,
            subjectId: action.id,
            satisfied: satisfied,
            decision: EngineeringDecision(
              id: 'validation:action:${action.id}',
              category: EngineeringDecisionCategory.validation,
              subjectId: action.id,
              decision: satisfied
                  ? '${action.name} has at least one effect'
                  : '${action.name} has no effect',
              rationale:
                  'An action with no effect is a dead end — it would do nothing when triggered.',
              confidence: Confidence.full,
            ),
          ),
        );
      }
    }

    for (final machine in stateMachines) {
      for (final transition in machine.transitions) {
        final satisfied = transition.from != transition.to;
        rules.add(
          EngineeringValidationRule(
            scope: EngineeringValidationScope.transition,
            subjectId: '${machine.entityId}:${transition.eventId}',
            satisfied: satisfied,
            decision: EngineeringDecision(
              id: 'validation:transition:${machine.entityId}:${transition.eventId}',
              category: EngineeringDecisionCategory.validation,
              subjectId: '${machine.entityId}:${transition.eventId}',
              decision: satisfied
                  ? 'Transition changes state'
                  : 'Transition is a no-op self-loop',
              rationale:
                  'A transition from a state to itself carries no information and likely indicates a planning defect.',
              confidence: Confidence.full,
            ),
          ),
        );
      }
    }

    return rules;
  }
}
