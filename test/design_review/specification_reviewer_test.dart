/// Vision V6 SCARE — SpecificationReviewer and its sub-reviewers
/// (StateReviewer/NavigationReviewer/BindingReviewer/BehaviorReviewer):
/// the first checks to cross-reference the final AppBlueprint against the
/// ArchitectureCandidate and EngineeringCandidate that produced it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/behavior_engineering.dart' show BehaviorEngineeringResult;
import 'package:anything/application_engineering/engineering_types.dart';
import 'package:anything/design_review/review_types.dart';
import 'package:anything/design_review/reviewers/specification_reviewer.dart';

import 'review_test_support.dart';

void main() {
  final context = buildReviewContext(fieldSurveyApp());

  test('a real, approved design produces no critical specification issues', () {
    const reviewer = SpecificationReviewer();
    final issues = reviewer.review(context);
    expect(issues.any((i) => i.severity == ReviewSeverity.critical), isFalse);
  });

  group('NavigationReviewer', () {
    const reviewer = NavigationReviewer();

    test('every real screen is reachable', () {
      final issues = reviewer.review(context);
      expect(issues.any((i) => i.category == ReviewCategory.navigation), isFalse);
    });

    test(
      'a multi-entity app\'s independent top-level list screens are reachable via the real bottom navigation, not flagged unreachable',
      () {
        // Regression guard: NavigationGraph only infers edges within one
        // entity's own list/detail/form views — a second entity's list
        // screen (e.g. "Equipment", "Loans") has no NavigationGraph edge
        // pointing to it at all, yet CreationEngine genuinely makes it
        // reachable via a real bottom navigation bar (every non-form view
        // gets an entry once there is more than one view). This exact
        // false positive was caught against a real multi-entity app
        // during this milestone's own regression run and fixed by
        // cross-referencing the blueprint's view types.
        final multiEntityContext = buildReviewContext(multiEntityApp());
        final issues = reviewer.review(multiEntityContext);
        expect(issues, isEmpty);
    });

    test(
      'a dashboard-type entry view anchors its entity\'s form screen, same as a list view',
      () {
        // Regression guard: CreationEngine only wired a real "Add <Entity>"
        // button (the click-path to a form screen) on list-type views.
        // A dashboard-type entry view with a sibling form got no such
        // anchor, leaving the form genuinely unreachable. Fixed by wiring
        // the same button for dashboard views and teaching this reviewer
        // that both view types anchor their entity's form.
        final dashboardContext = buildReviewContext(dashboardApp());
        final issues = reviewer.review(dashboardContext);
        expect(issues, isEmpty);
    });
  });

  group('BehaviorReviewer', () {
    const reviewer = BehaviorReviewer();

    test('a real engineered behavior plan has no unreachable actions', () {
      final issues = reviewer.review(context);
      expect(issues.any((i) => i.category == ReviewCategory.behavior), isFalse);
    });

    test('an action with no triggering event is flagged dead', () {
      final behavior = context.engineering.behaviors.first;
      final brokenEventGraph = EventGraph(
        entityId: behavior.eventGraph.entityId,
        events: const [], // no events at all -> every action becomes unreachable
        actions: behavior.eventGraph.actions,
      );
      final brokenBehavior = BehaviorEngineeringResult(
        eventGraph: brokenEventGraph,
        stateMachine: behavior.stateMachine,
        decision: behavior.decision,
      );
      final brokenEngineering = context.engineering.copyWith(behaviors: [brokenBehavior]);
      final issues = reviewer.review(withEngineering(context, brokenEngineering));
      expect(issues.any((i) => i.id.startsWith('behavior:dead:')), isTrue);
    });
  });
}
