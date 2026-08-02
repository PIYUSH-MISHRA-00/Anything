/// Vision V3 AEE — BehaviorEngineering: real EventGraph + generic
/// StateMachineDefinition generation per entity, gated on real
/// InteractionDecision flags, states drawn only from GenericState.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/behavior_engineering.dart';
import 'package:anything/application_engineering/engineering_types.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

/// "Beekeeping Hive Inspection" — a domain with zero footprint anywhere in
/// lib/, used only to prove behavior planning is structural, not domain-aware.
SemanticApp _hiveApp() {
  return SemanticApp(
    name: 'Hive Inspection Log',
    purpose: 'Track beehive inspections',
    entities: [
      const SemanticEntity(
        id: 'inspection',
        name: 'Inspection',
        displayField: 'notes',
        fields: [
          SemanticField(id: 'notes', name: 'Notes', type: BlueprintFieldType.text, required: true),
        ],
      ),
      const SemanticEntity(
        id: 'hive',
        name: 'Hive',
        fields: [
          SemanticField(id: 'label', name: 'Label', type: BlueprintFieldType.text, required: true),
        ],
      ),
    ],
    views: [
      const SemanticView(
        id: 'inspections_list',
        name: 'Inspections',
        purpose: 'list',
        sourceEntityId: 'inspection',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      const SemanticView(
        id: 'inspections_form',
        name: 'Add Inspection',
        purpose: 'form',
        sourceEntityId: 'inspection',
        viewType: BlueprintViewType.form,
      ),
    ],
    actions: [
      const SemanticAction(id: 'add_inspection', name: 'Add Inspection', targetEntityId: 'inspection'),
      const SemanticAction(
        id: 'delete_inspection',
        name: 'Delete Inspection',
        targetEntityId: 'inspection',
        actionType: BlueprintActionType.delete,
      ),
    ],
  );
}

void main() {
  const architecturePlanner = ArchitecturePlanner();
  const behaviorEngineering = BehaviorEngineering();

  test('one EventGraph + StateMachine per entity, always includes read', () {
    final candidate = architecturePlanner.plan(_hiveApp());
    final results = behaviorEngineering.plan(candidate);
    expect(results, hasLength(2));
    for (final r in results) {
      expect(r.eventGraph.actionById('action:${r.eventGraph.entityId}:read'), isNotNull);
    }
  });

  test('CRUD actions are gated on real InteractionDecision flags', () {
    final candidate = architecturePlanner.plan(_hiveApp());
    final results = behaviorEngineering.plan(candidate);
    final inspection = results.firstWhere((r) => r.eventGraph.entityId == 'inspection');
    // add_inspection + delete_inspection actions exist -> create/delete present.
    expect(inspection.eventGraph.actionById('action:inspection:create'), isNotNull);
    expect(inspection.eventGraph.actionById('action:inspection:delete'), isNotNull);
    // No update/toggle/setValue action declared -> no update event.
    expect(inspection.eventGraph.actionById('action:inspection:update'), isNull);

    final hive = results.firstWhere((r) => r.eventGraph.entityId == 'hive');
    // No actions target hive -> only the always-present read.
    expect(hive.eventGraph.actions, hasLength(1));
    expect(hive.eventGraph.actionById('action:hive:read'), isNotNull);
  });

  test('every state transition uses only GenericState — never a domain name', () {
    final candidate = architecturePlanner.plan(_hiveApp());
    final results = behaviorEngineering.plan(candidate);
    for (final r in results) {
      for (final t in r.stateMachine.transitions) {
        expect(GenericState.values, contains(t.from));
        expect(GenericState.values, contains(t.to));
      }
    }
  });

  test('every action effect uses a real BehaviorInterpreter operation kind', () {
    final candidate = architecturePlanner.plan(_hiveApp());
    final results = behaviorEngineering.plan(candidate);
    const realKinds = {EffectKind.dataMutation, EffectKind.dataQuery};
    for (final r in results) {
      for (final action in r.eventGraph.actions) {
        for (final effect in action.effects) {
          expect(realKinds, contains(effect.kind));
        }
      }
    }
  });

  test('create/delete produce done/failed completion transitions', () {
    final candidate = architecturePlanner.plan(_hiveApp());
    final results = behaviorEngineering.plan(candidate);
    final inspection = results.firstWhere((r) => r.eventGraph.entityId == 'inspection');
    expect(inspection.stateMachine.hasTransitionFor('evt:inspection:create'), isTrue);
    expect(inspection.stateMachine.hasTransitionFor('evt:inspection:create:done'), isTrue);
    expect(inspection.stateMachine.hasTransitionFor('evt:inspection:create:failed'), isTrue);
    final done = inspection.stateMachine.transitions.firstWhere(
      (t) => t.eventId == 'evt:inspection:create:done',
    );
    expect(done.to, GenericState.completed);
    final failed = inspection.stateMachine.transitions.firstWhere(
      (t) => t.eventId == 'evt:inspection:create:failed',
    );
    expect(failed.to, GenericState.error);
  });
}
