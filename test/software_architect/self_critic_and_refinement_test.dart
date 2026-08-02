/// V2 ASAE — SelfCritic, ConfidenceAnalyzer, and RefinementPlanner tests.
///
/// Constructs ArchitectureCandidate fixtures directly (not through
/// ArchitecturePlanner) so each defect scenario is precisely controlled.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_review.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/confidence_analyzer.dart';
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/self_critic.dart';

ArchitectureDecision _decision(String id, {double score = 1.0}) =>
    ArchitectureDecision(
      id: id,
      category: ArchitectureDecisionCategory.data,
      subjectId: id,
      decision: 'd',
      rationale: 'r',
      confidence: Confidence(score: score, reason: 'test'),
    );

NavigationGraph _emptyNav() => NavigationGraph(
  entryScreenId: 'home',
  screenIds: const ['home'],
  edges: const [],
  decision: _decision('nav'),
);

SecurityDecision _security() => SecurityDecision(
  networkMode: NetworkMode.none,
  requiresCredentialVault: false,
  decision: _decision('sec'),
);

OfflineDecision _offline() => OfflineDecision(
  capability: OfflineCapability.fullyOffline,
  decision: _decision('off'),
);

SynchronizationDecision _sync() => SynchronizationDecision(
  strategy: SyncStrategy.none,
  decision: _decision('sync'),
);

EntityDecision _entity(String id, String name, {int fieldCount = 1}) =>
    EntityDecision(
      entityId: id,
      name: name,
      fieldCount: fieldCount,
      storage: StorageKind.sqlite,
      storageDecision: _decision('storage:$id'),
    );

ArchitectureCandidate _baseCandidate({
  List<EntityDecision> entities = const [],
  List<RelationshipDecision> relationships = const [],
  NavigationGraph? navigation,
  List<CapabilityDecision> capabilities = const [],
  double overallScore = 1.0,
}) {
  return ArchitectureCandidate(
    id: 'candidate-1',
    appName: 'Test App',
    entities: entities,
    relationships: relationships,
    navigation: navigation ?? _emptyNav(),
    capabilities: capabilities,
    security: _security(),
    offline: _offline(),
    synchronization: _sync(),
    overallConfidence: Confidence(score: overallScore, reason: 'test'),
  );
}

void main() {
  group('SelfCritic', () {
    const critic = SelfCritic();

    test('a clean candidate passes with no issues', () {
      final candidate = _baseCandidate(
        entities: [_entity('e1', 'Alpha'), _entity('e2', 'Beta')],
      );
      final review = critic.review(candidate);
      expect(review.passed, isTrue);
      expect(review.hasCriticalIssues, isFalse);
    });

    test(
      'duplicate entity names are detected as a critical, auto-fixable issue',
      () {
        final candidate = _baseCandidate(
          entities: [_entity('e1', 'Alpha'), _entity('e2', 'Alpha')],
        );
        final review = critic.review(candidate);
        expect(review.hasCriticalIssues, isTrue);
        final issue = review.issues.firstWhere(
          (i) => i.category == IssueCategory.duplicateEntity,
        );
        expect(issue.severity, IssueSeverity.critical);
        expect(issue.autoFixable, isTrue);
      },
    );

    test('an entity with zero fields is a warning, not critical', () {
      final candidate = _baseCandidate(
        entities: [_entity('e1', 'Empty', fieldCount: 0)],
      );
      final review = critic.review(candidate);
      expect(review.hasCriticalIssues, isFalse);
      expect(
        review.issues.any((i) => i.category == IssueCategory.poorStorage),
        isTrue,
      );
    });

    test(
      'a relationship referencing a non-existent entity is critical and auto-fixable',
      () {
        final candidate = _baseCandidate(
          entities: [_entity('e1', 'Alpha')],
          relationships: [
            RelationshipDecision(
              fromEntityId: 'e1',
              toEntityId: 'nonexistent',
              fieldId: 'ref',
              deletePolicy: RelationshipDeletePolicy.setNull,
              decision: _decision('rel'),
            ),
          ],
        );
        final review = critic.review(candidate);
        expect(review.hasCriticalIssues, isTrue);
        final issue = review.autoFixableIssues.single;
        expect(issue.subjectId, 'e1.ref');
      },
    );

    test(
      'multiple disconnected screens with no edges is a navigation warning',
      () {
        final candidate = _baseCandidate(
          navigation: NavigationGraph(
            entryScreenId: 's1',
            screenIds: const ['s1', 's2'],
            edges: const [],
            decision: _decision('nav'),
          ),
        );
        final review = critic.review(candidate);
        expect(
          review.issues.any((i) => i.category == IssueCategory.navigationIssue),
          isTrue,
        );
      },
    );

    test('unresolved capability is a warning', () {
      final candidate = _baseCandidate(
        capabilities: [
          CapabilityDecision(
            capabilityId: 'bluetooth',
            resolved: false,
            decision: _decision('cap'),
          ),
        ],
      );
      final review = critic.review(candidate);
      expect(
        review.issues.any((i) => i.category == IssueCategory.missingCapability),
        isTrue,
      );
      expect(review.hasCriticalIssues, isFalse);
    });

    test('very low overall confidence is critical', () {
      final candidate = _baseCandidate(overallScore: 0.1);
      final review = critic.review(candidate);
      expect(review.hasCriticalIssues, isTrue);
      expect(
        review.issues.any((i) => i.category == IssueCategory.lowConfidence),
        isTrue,
      );
    });
  });

  group('ConfidenceAnalyzer', () {
    const analyzer = ConfidenceAnalyzer();

    test('is the real mean of all decision confidences', () {
      final candidate = _baseCandidate(
        entities: [
          EntityDecision(
            entityId: 'e1',
            name: 'A',
            fieldCount: 1,
            storage: StorageKind.sqlite,
            storageDecision: _decision('d1', score: 1.0),
          ),
          EntityDecision(
            entityId: 'e2',
            name: 'B',
            fieldCount: 1,
            storage: StorageKind.sqlite,
            storageDecision: _decision('d2', score: 0.5),
          ),
        ],
      );
      final overall = analyzer.analyze(candidate);
      // Includes entity decisions + nav/security/offline/sync (all 1.0) —
      // just assert it's strictly between the min and max, i.e. a real mean.
      expect(overall.score, greaterThan(0.5));
      expect(overall.score, lessThan(1.0));
    });
  });

  group('RefinementPlanner', () {
    test(
      'approves a clean candidate on the first pass (0 refinement iterations)',
      () {
        final planner = RefinementPlanner(
          confidenceAnalyzer: const ConfidenceAnalyzer(),
        );
        final candidate = _baseCandidate(entities: [_entity('e1', 'Alpha')]);
        final report = planner.refine(candidate);
        expect(report.outcome, RefinementOutcome.approved);
        expect(report.reviewHistory, hasLength(1));
        expect(report.finalCandidate.iteration, 0);
      },
    );

    test('fixes duplicate entity names within the iteration budget', () {
      final planner = RefinementPlanner(
        confidenceAnalyzer: const ConfidenceAnalyzer(),
      );
      final candidate = _baseCandidate(
        entities: [_entity('e1', 'Alpha'), _entity('e2', 'Alpha')],
      );
      final report = planner.refine(candidate);
      expect(report.outcome, RefinementOutcome.approved);
      expect(
        report.finalCandidate.entities.map((e) => e.name).toSet(),
        hasLength(2),
      );
      expect(report.reviewHistory.length, greaterThan(1));
    });

    test('drops a dangling relationship and approves', () {
      final planner = RefinementPlanner(
        confidenceAnalyzer: const ConfidenceAnalyzer(),
      );
      final candidate = _baseCandidate(
        entities: [_entity('e1', 'Alpha')],
        relationships: [
          RelationshipDecision(
            fromEntityId: 'e1',
            toEntityId: 'ghost',
            fieldId: 'ref',
            deletePolicy: RelationshipDeletePolicy.setNull,
            decision: _decision('rel'),
          ),
        ],
      );
      final report = planner.refine(candidate);
      expect(report.outcome, RefinementOutcome.approved);
      expect(report.finalCandidate.relationships, isEmpty);
    });

    test(
      'terminates deterministically at the iteration budget when nothing more is fixable',
      () {
        // Unresolved capability + low confidence: neither is auto-fixable,
        // so the loop must break immediately rather than spin.
        final planner = RefinementPlanner(
          confidenceAnalyzer: const ConfidenceAnalyzer(),
          maxIterations: 3,
        );
        final candidate = _baseCandidate(overallScore: 0.05);
        final report = planner.refine(candidate);
        expect(report.outcome, RefinementOutcome.refinementRequired);
        // Only one review ran because there was nothing auto-fixable to try.
        expect(report.reviewHistory, hasLength(1));
      },
    );

    test(
      'maxIterations bounds the loop even if fixes keep the issue alive',
      () {
        // A pathological candidate that regenerates a duplicate every fix
        // attempt would otherwise loop forever; prove the hard iteration cap
        // still applies by using a very low budget.
        final planner = RefinementPlanner(
          confidenceAnalyzer: const ConfidenceAnalyzer(),
          maxIterations: 1,
        );
        final candidate = _baseCandidate(
          entities: [
            _entity('e1', 'Alpha'),
            _entity('e2', 'Alpha'),
            _entity('e3', 'Alpha'),
          ],
        );
        final report = planner.refine(candidate);
        expect(report.finalCandidate.iteration, lessThanOrEqualTo(1));
        expect(report.reviewHistory.length, lessThanOrEqualTo(2));
      },
    );
  });
}
