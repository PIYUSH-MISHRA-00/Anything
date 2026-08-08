/// Vision V3 AEE — EngineeringToBlueprintAugmenter: the concrete
/// "compilation" link between AEE's typed StateMachine model and the real,
/// executable BehaviorGraph/StateSchema the existing, unmodified
/// BehaviorInterpreter already runs. Guards the exact regression already
/// hit once: the new StateVariable's type string must be one
/// ExperienceStateEngine._isValidType actually recognizes ('string', never
/// 'text').
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/application_engineering/engineering_refinement.dart';
import 'package:anything/application_engineering/engineering_to_blueprint.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _augmenter = EngineeringToBlueprintAugmenter();

SemanticApp _hiveApp() {
  return SemanticApp(
    name: 'Hive Inspection Log',
    purpose: 'Track beehive inspections',
    entities: [
      const SemanticEntity(
        id: 'inspection',
        name: 'Inspection',
        fields: [
          SemanticField(
            id: 'notes',
            name: 'Notes',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
  );
}

EngineeringPlan _approvedPlan() {
  final app = _hiveApp();
  final candidate = const ArchitecturePlanner().plan(app);
  final engineered = const EngineeringPlanner().plan(
    EngineeringContext(architecture: candidate, app: app),
  );
  final plan = const EngineeringRefinement().refine(engineered);
  expect(
    plan.outcome,
    EngineeringRefinementOutcome.approved,
    reason: 'fixture must be approved',
  );
  return plan;
}

AppBlueprint _blueprintWithCreateAndDelete() {
  return const AppBlueprint(
    id: 'app',
    name: 'Hive Inspection Log',
    description: 'test',
    entities: [BlueprintEntity(id: 'inspection', name: 'Inspection')],
    actions: [
      BlueprintAction(
        id: 'add_inspection',
        name: 'Add',
        targetEntityId: 'inspection',
      ),
      BlueprintAction(
        id: 'remove_inspection',
        name: 'Remove',
        targetEntityId: 'inspection',
        actionType: BlueprintActionType.delete,
      ),
      BlueprintAction(
        id: 'go_home',
        name: 'Go Home',
        targetEntityId: 'inspection',
        actionType: BlueprintActionType.navigate,
      ),
    ],
  );
}

BehaviorGraph _behaviorWithEventNodesFor(AppBlueprint blueprint) {
  return BehaviorGraph(
    nodes: [
      for (final a in blueprint.actions)
        BehaviorNode(id: '${a.id}_event', type: 'event'),
    ],
  );
}

void main() {
  test(
    'adds a real generic status StateVariable using a recognized type string',
    () {
      final blueprint = _blueprintWithCreateAndDelete();
      final result = _augmenter.augment(
        blueprint: blueprint,
        behavior: _behaviorWithEventNodesFor(blueprint),
        state: const StateSchema(),
        plan: _approvedPlan(),
      );
      final statusVar = result.state.variables.firstWhere(
        (v) => v.id == 'inspection_status',
      );
      expect(
        statusVar.type,
        'string',
      ); // NOT 'text' — ExperienceStateEngine would silently reject that.
      expect(statusVar.defaultValue, 'idle');
    },
  );

  test('wires a stateWrite node to the existing create-action event node', () {
    final blueprint = _blueprintWithCreateAndDelete();
    final behavior = _behaviorWithEventNodesFor(blueprint);
    final result = _augmenter.augment(
      blueprint: blueprint,
      behavior: behavior,
      state: const StateSchema(),
      plan: _approvedPlan(),
    );
    final statusWrite = result.behavior.nodes.firstWhere(
      (n) => n.id == 'add_inspection_status_write',
    );
    expect(statusWrite.type, 'stateWrite');
    expect(statusWrite.config['stateId'], 'inspection_status');
    expect(statusWrite.config['value'], 'saving');
    expect(
      result.behavior.edges.any(
        (e) => e.from == 'add_inspection_event' && e.to == statusWrite.id,
      ),
      isTrue,
    );
  });

  test(
    'delete action transitions to "deleting", navigate is skipped entirely',
    () {
      final blueprint = _blueprintWithCreateAndDelete();
      final behavior = _behaviorWithEventNodesFor(blueprint);
      final result = _augmenter.augment(
        blueprint: blueprint,
        behavior: behavior,
        state: const StateSchema(),
        plan: _approvedPlan(),
      );
      final deleteWrite = result.behavior.nodes.firstWhere(
        (n) => n.id == 'remove_inspection_status_write',
      );
      expect(deleteWrite.config['value'], 'deleting');
      expect(
        result.behavior.nodes.any((n) => n.id == 'go_home_status_write'),
        isFalse,
      );
    },
  );

  test('is a complete no-op when plan is null', () {
    final blueprint = _blueprintWithCreateAndDelete();
    const behavior = BehaviorGraph();
    const state = StateSchema();
    final result = _augmenter.augment(
      blueprint: blueprint,
      behavior: behavior,
      state: state,
      plan: null,
    );
    expect(identical(result.behavior, behavior), isTrue);
    expect(identical(result.state, state), isTrue);
  });

  test('is a complete no-op when the plan was not approved', () {
    final blueprint = _blueprintWithCreateAndDelete();
    const behavior = BehaviorGraph();
    const state = StateSchema();
    final unapproved = _approvedPlan();
    final notApproved = EngineeringPlan(
      finalCandidate: unapproved.finalCandidate,
      reviewHistory: unapproved.reviewHistory,
      outcome: EngineeringRefinementOutcome.refinementRequired,
    );
    final result = _augmenter.augment(
      blueprint: blueprint,
      behavior: behavior,
      state: state,
      plan: notApproved,
    );
    expect(identical(result.behavior, behavior), isTrue);
    expect(identical(result.state, state), isTrue);
  });

  test(
    'skips actions whose event node CreationEngine never actually built',
    () {
      final blueprint = _blueprintWithCreateAndDelete();
      const behavior = BehaviorGraph(); // no event nodes at all
      final result = _augmenter.augment(
        blueprint: blueprint,
        behavior: behavior,
        state: const StateSchema(),
        plan: _approvedPlan(),
      );
      expect(result.behavior.nodes, isEmpty);
    },
  );
}
