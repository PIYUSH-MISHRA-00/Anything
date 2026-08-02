/// Vision V6 SCARE — ArchitectureReviewer, DependencyReviewer,
/// EngineeringReviewer: real structural checks beyond what V2's SelfCritic
/// and V3's EngineeringReview already cover.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/reviewers/architecture_reviewer.dart';
import 'package:anything/design_review/reviewers/dependency_reviewer.dart';
import 'package:anything/design_review/reviewers/engineering_reviewer.dart';
import 'package:anything/design_review/review_types.dart';
import 'package:anything/feature_discovery/dependency_types.dart';
import 'package:anything/feature_discovery/feature_types.dart' show FeatureRelationKind;

import 'review_test_support.dart';

void main() {
  final context = buildReviewContext(fieldSurveyApp());

  group('ArchitectureReviewer', () {
    const reviewer = ArchitectureReviewer();

    test('a real, approved architecture produces no critical issues', () {
      final issues = reviewer.review(context);
      expect(issues.any((i) => i.severity == ReviewSeverity.critical), isFalse);
    });

    test('an entity with no interaction plan is flagged unused', () {
      final architecture = context.architecture;
      final strippedInteractions = architecture.interactions.where((i) => i.entityId != 'entry').toList();
      final broken = architecture.copyWith(interactions: strippedInteractions);
      final issues = reviewer.review(withArchitecture(context, broken));
      expect(issues.any((i) => i.id == 'architecture:unused:entry'), isTrue);
    });
  });

  group('DependencyReviewer', () {
    const reviewer = DependencyReviewer();

    test('a real, approved dependency graph produces no critical issues', () {
      final issues = reviewer.review(context);
      expect(issues.any((i) => i.severity == ReviewSeverity.critical), isFalse);
    });

    test('a duplicate dependency edge is flagged redundant and auto-fixable', () {
      final graph = context.dependencyGraph;
      final duplicated = DependencyGraph(nodes: graph.nodes, edges: [...graph.edges, graph.edges.first]);
      final issues = reviewer.review(withDependencyGraph(context, duplicated));
      final issue = issues.firstWhere((i) => i.id.startsWith('dependency:redundant:'));
      expect(issue.severity, ReviewSeverity.warning);
      expect(issue.autoFixable, isTrue);
    });

    test('a dangling dependency edge is flagged missing and auto-fixable', () {
      final graph = context.dependencyGraph;
      final dangling = DependencyGraph(
        nodes: graph.nodes,
        edges: [...graph.edges, const DependencyEdge(fromId: 'ghost-from', toId: 'ghost-to', relation: FeatureRelationKind.requires)],
      );
      final issues = reviewer.review(withDependencyGraph(context, dangling));
      final issue = issues.firstWhere((i) => i.id.startsWith('dependency:missing:'));
      expect(issue.severity, ReviewSeverity.critical);
      expect(issue.autoFixable, isTrue);
    });
  });

  group('EngineeringReviewer', () {
    const reviewer = EngineeringReviewer();

    test('a real, approved engineering candidate produces no critical issues', () {
      final issues = reviewer.review(context);
      expect(issues.any((i) => i.severity == ReviewSeverity.critical), isFalse);
    });
  });
}
