/// Vision V3 AEE — BindingEngineering (typed BindingGraph using exactly the
/// real runtime's stable identifier conventions) and ValidationEngineering
/// (entity/relationship/action/transition-level rules).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/behavior_engineering.dart';
import 'package:anything/application_engineering/binding_engineering.dart';
import 'package:anything/application_engineering/engineering_types.dart';
import 'package:anything/application_engineering/validation_engineering.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

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
    ],
    actions: [
      const SemanticAction(id: 'add_inspection', name: 'Add Inspection', targetEntityId: 'inspection'),
    ],
    requiredCapabilities: const ['clock'],
  );
}

void main() {
  const architecturePlanner = ArchitecturePlanner();
  const behaviorEngineering = BehaviorEngineering();
  final candidate = architecturePlanner.plan(_hiveApp());

  group('BindingEngineering', () {
    const bindingEngineering = BindingEngineering();

    test('uses the real runtime identifier conventions, not an invented scheme', () {
      final result = bindingEngineering.plan(candidate);
      final viewToState = result.graph.edgesOfKind(BindingKind.viewToState);
      expect(viewToState.any((e) => e.toId == 'form_notes'), isTrue);

      final stateToData = result.graph.edgesOfKind(BindingKind.stateToData);
      expect(stateToData.any((e) => e.fromId == 'state:inspection' && e.toId == 'inspection'), isTrue);

      final dataToRuntime = result.graph.edgesOfKind(BindingKind.dataToRuntime);
      expect(dataToRuntime.any((e) => e.fromId == 'inspection' && e.toId == 'ExperienceDataRuntime'), isTrue);

      final capabilityToRuntime = result.graph.edgesOfKind(BindingKind.capabilityToRuntime);
      expect(capabilityToRuntime.any((e) => e.fromId == 'clock' && e.toId == 'CapabilityPlatform'), isTrue);
    });

    test('search-enabled entities bind to the real searchTerm state id', () {
      final result = bindingEngineering.plan(candidate);
      final searchBinding = result.graph.edgesOfKind(BindingKind.viewToState)
          .where((e) => e.toId == 'searchTerm');
      expect(searchBinding, isNotEmpty);
    });
  });

  group('ValidationEngineering', () {
    const validationEngineering = ValidationEngineering();

    test('entity with fields is satisfied; action with effects is satisfied', () {
      final behaviors = behaviorEngineering.plan(candidate);
      final rules = validationEngineering.plan(
        candidate: candidate,
        eventGraphs: behaviors.map((b) => b.eventGraph).toList(),
        stateMachines: behaviors.map((b) => b.stateMachine).toList(),
      );
      final entityRule = rules.firstWhere(
        (r) => r.scope == EngineeringValidationScope.entity && r.subjectId == 'inspection',
      );
      expect(entityRule.satisfied, isTrue);

      final actionRules = rules.where((r) => r.scope == EngineeringValidationScope.action);
      expect(actionRules, isNotEmpty);
      expect(actionRules.every((r) => r.satisfied), isTrue);
    });

    test('detects a self-loop transition as an unsatisfied rule', () {
      final behaviors = behaviorEngineering.plan(candidate);
      final brokenMachine = StateMachineDefinition(
        entityId: 'inspection',
        transitions: const [
          Transition(eventId: 'evt:inspection:noop', from: GenericState.idle, to: GenericState.idle),
        ],
      );
      final rules = validationEngineering.plan(
        candidate: candidate,
        eventGraphs: behaviors.map((b) => b.eventGraph).toList(),
        stateMachines: [brokenMachine],
      );
      final transitionRule = rules.firstWhere(
        (r) => r.scope == EngineeringValidationScope.transition,
      );
      expect(transitionRule.satisfied, isFalse);
    });

    test('every relationship has an explicit delete policy recorded', () {
      final behaviors = behaviorEngineering.plan(candidate);
      final rules = validationEngineering.plan(
        candidate: candidate,
        eventGraphs: behaviors.map((b) => b.eventGraph).toList(),
        stateMachines: behaviors.map((b) => b.stateMachine).toList(),
      );
      final relationshipRules = rules.where((r) => r.scope == EngineeringValidationScope.relationship);
      expect(relationshipRules.every((r) => r.satisfied), isTrue);
    });
  });
}
