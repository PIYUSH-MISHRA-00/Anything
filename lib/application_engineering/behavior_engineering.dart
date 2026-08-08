/// Behavior Engineering — generates a real EventGraph + generic
/// StateMachineDefinition per entity from the approved ArchitectureCandidate.
///
/// Every Action's Effects use exactly the operation vocabulary
/// BehaviorInterpreter already executes (dataMutation/dataQuery/stateWrite/
/// navigation/capabilityInvocation) — this models what the existing,
/// certified runtime does, it does not invent a new execution primitive.
/// States are always the generic vocabulary (GenericState); nothing here
/// is entity-name-aware.
library;

import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_types.dart';
import '../software_architect/confidence.dart';
import 'engineering_types.dart';

class BehaviorEngineeringResult {
  final EventGraph eventGraph;
  final StateMachineDefinition stateMachine;
  final EngineeringDecision decision;

  const BehaviorEngineeringResult({
    required this.eventGraph,
    required this.stateMachine,
    required this.decision,
  });
}

class BehaviorEngineering {
  const BehaviorEngineering();

  List<BehaviorEngineeringResult> plan(ArchitectureCandidate candidate) {
    return candidate.entities.map((entity) {
      final interaction = candidate.interactions
          .where((i) => i.entityId == entity.entityId)
          .firstOrNull;
      return _planForEntity(entity, interaction);
    }).toList();
  }

  BehaviorEngineeringResult _planForEntity(
    EntityDecision entity,
    InteractionDecision? interaction,
  ) {
    final events = <Event>[];
    final actions = <Action>[];
    final transitions = <Transition>[];

    void addCrud(String verb, EffectKind effectKind, GenericState working) {
      final eventId = 'evt:${entity.entityId}:$verb';
      final actionId = 'action:${entity.entityId}:$verb';
      events.add(
        Event(id: eventId, name: '$verb ${entity.name}', actionId: actionId),
      );
      actions.add(
        Action(
          id: actionId,
          name: '$verb ${entity.name}',
          entityId: entity.entityId,
          trigger: const Trigger(kind: TriggerKind.userAction, sourceId: 'ui'),
          effects: [
            Effect(
              kind: effectKind,
              targetId: entity.entityId,
              description: '$verb record(s)',
            ),
          ],
        ),
      );
      transitions.add(
        Transition(eventId: eventId, from: GenericState.idle, to: working),
      );
      transitions.add(
        Transition(
          eventId: '$eventId:done',
          from: working,
          to: GenericState.completed,
        ),
      );
      transitions.add(
        Transition(
          eventId: '$eventId:failed',
          from: working,
          to: GenericState.error,
        ),
      );
    }

    if (interaction?.canCreate ?? false) {
      addCrud('create', EffectKind.dataMutation, GenericState.saving);
    }
    if (interaction?.canUpdate ?? false) {
      addCrud('update', EffectKind.dataMutation, GenericState.saving);
    }
    if (interaction?.canDelete ?? false) {
      addCrud('delete', EffectKind.dataMutation, GenericState.deleting);
    }
    // Read is always available — every generated entity has a list view.
    addCrud('read', EffectKind.dataQuery, GenericState.loading);

    if (interaction?.supportsSearch ?? false) {
      addCrud('search', EffectKind.dataQuery, GenericState.searching);
    }
    if (interaction?.supportsFilter ?? false) {
      addCrud('filter', EffectKind.dataQuery, GenericState.filtering);
    }
    if (interaction?.supportsSort ?? false) {
      addCrud('sort', EffectKind.dataQuery, GenericState.sorting);
    }

    final eventGraph = EventGraph(
      entityId: entity.entityId,
      events: events,
      actions: actions,
    );
    final stateMachine = StateMachineDefinition(
      entityId: entity.entityId,
      transitions: transitions,
    );

    return BehaviorEngineeringResult(
      eventGraph: eventGraph,
      stateMachine: stateMachine,
      decision: EngineeringDecision(
        id: 'behavior:${entity.entityId}',
        category: EngineeringDecisionCategory.behavior,
        subjectId: entity.entityId,
        decision:
            '${actions.length} action(s), ${transitions.length} state transition(s) '
            'for ${entity.name}',
        rationale:
            'Derived from InteractionDecision (CRUD/search/filter/sort flags); '
            'every action maps to a real BehaviorInterpreter operation '
            '(dataMutation/dataQuery), every state is generic '
            '(GenericState), never entity-specific.',
        confidence: interaction != null
            ? Confidence.full
            : const Confidence(
                score: 0.6,
                reason:
                    'No InteractionDecision found for this entity; assumed read-only.',
                risk: RiskLevel.low,
              ),
      ),
    );
  }
}
