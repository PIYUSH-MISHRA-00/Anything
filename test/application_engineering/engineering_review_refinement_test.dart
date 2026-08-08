/// Vision V3 AEE — EngineeringReview (detects dangling bindings, behavior
/// inconsistencies, unsatisfied validations, low confidence) and
/// EngineeringRefinement (auto-fixes what's fixable, terminates within a
/// bounded iteration budget — mirrors software_architect's proven-
/// terminating RefinementPlanner design).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/behavior_engineering.dart';
import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/application_engineering/engineering_refinement.dart';
import 'package:anything/application_engineering/engineering_review.dart';
import 'package:anything/application_engineering/engineering_types.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/confidence.dart';
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

void main() {
  const architecturePlanner = ArchitecturePlanner();
  const engineeringPlanner = EngineeringPlanner();
  const review = EngineeringReview();

  test('a clean candidate produces no critical issues', () {
    final app = _hiveApp();
    final candidate = architecturePlanner.plan(app);
    final engineered = engineeringPlanner.plan(
      EngineeringContext(architecture: candidate, app: app),
    );
    final result = review.review(engineered);
    expect(result.hasCriticalIssues, isFalse);
  });

  test('flags a dangling binding as critical and auto-fixable', () {
    final app = _hiveApp();
    final candidate = architecturePlanner.plan(app);
    final engineered = engineeringPlanner.plan(
      EngineeringContext(architecture: candidate, app: app),
    );
    final broken = engineered.copyWith(
      bindingGraph: BindingGraph(
        edges: [
          ...engineered.bindingGraph.edges,
          const BindingEdge(
            kind: BindingKind.stateToData,
            fromId: 'state:ghost',
            toId: 'ghost_entity',
          ),
        ],
      ),
    );
    final result = review.review(broken);
    expect(result.hasCriticalIssues, isTrue);
    final issue = result.issues.firstWhere(
      (i) => i.category == EngineeringIssueCategory.danglingBinding,
    );
    expect(issue.autoFixable, isTrue);
  });

  test(
    'flags a behavior inconsistency (transition with no declared event) as critical and auto-fixable',
    () {
      final app = _hiveApp();
      final candidate = architecturePlanner.plan(app);
      final engineered = engineeringPlanner.plan(
        EngineeringContext(architecture: candidate, app: app),
      );
      final entityId = engineered.behaviors.first.eventGraph.entityId;
      final brokenBehavior = BehaviorEngineeringResult(
        eventGraph: engineered.behaviors.first.eventGraph,
        stateMachine: StateMachineDefinition(
          entityId: entityId,
          transitions: [
            ...engineered.behaviors.first.stateMachine.transitions,
            Transition(
              eventId: 'evt:$entityId:ghost',
              from: GenericState.idle,
              to: GenericState.saving,
            ),
          ],
        ),
        decision: engineered.behaviors.first.decision,
      );
      final broken = engineered.copyWith(behaviors: [brokenBehavior]);
      final result = review.review(broken);
      expect(result.hasCriticalIssues, isTrue);
      final issue = result.issues.firstWhere(
        (i) => i.category == EngineeringIssueCategory.behaviorInconsistency,
      );
      expect(issue.autoFixable, isTrue);
    },
  );

  test('refinement fixes a dangling binding and reaches approved', () {
    final app = _hiveApp();
    final candidate = architecturePlanner.plan(app);
    final engineered = engineeringPlanner.plan(
      EngineeringContext(architecture: candidate, app: app),
    );
    final broken = engineered.copyWith(
      bindingGraph: BindingGraph(
        edges: [
          ...engineered.bindingGraph.edges,
          const BindingEdge(
            kind: BindingKind.stateToData,
            fromId: 'state:ghost',
            toId: 'ghost_entity',
          ),
        ],
      ),
    );
    final plan = const EngineeringRefinement().refine(broken);
    expect(plan.outcome, EngineeringRefinementOutcome.approved);
    expect(plan.finalReview.hasCriticalIssues, isFalse);
    expect(
      plan.finalCandidate.bindingGraph.edges.any(
        (e) => e.toId == 'ghost_entity',
      ),
      isFalse,
    );
  });

  test(
    'refinement terminates (budgetExhausted) when critical issues cannot be auto-fixed',
    () {
      final app = _hiveApp();
      final candidate = architecturePlanner.plan(app);
      final engineered = engineeringPlanner.plan(
        EngineeringContext(architecture: candidate, app: app),
      );
      // Low overall confidence is critical but has no autoFixable path.
      final unfixable = engineered.copyWith(
        overallConfidence: const Confidence(
          score: 0.1,
          reason: 'forced for test',
        ),
      );
      final plan = const EngineeringRefinement().refine(unfixable);
      expect(plan.outcome, isNot(EngineeringRefinementOutcome.approved));
    },
  );
}
