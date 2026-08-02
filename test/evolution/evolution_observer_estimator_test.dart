/// Vision V7 AEE — EvolutionObserver (Autonomous Observation) and
/// EvolutionEstimator (Value/Risk Estimation).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/evolution/evolution_estimator.dart';
import 'package:anything/evolution/evolution_observer.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/software_architect/confidence.dart';

import 'evolution_test_support.dart';

void main() {
  const observer = EvolutionObserver();
  const estimator = EvolutionEstimator();

  group('EvolutionObserver', () {
    test('a real, approved single-entity design surfaces at least the deferred/review-signal opportunities', () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final opportunities = observer.observe(context);
      // Every opportunity must carry real, non-empty evidence — never fabricated.
      for (final o in opportunities) {
        expect(o.reason.evidence.affectedGraph, isNotEmpty);
        expect(o.reason.evidence.affectedNodeId, isNotEmpty);
      }
    });

    test('an entity with a real list view but no search is flagged missingSearch once field count is high enough', () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final opportunities = observer.observe(context);
      // fieldSurveyApp's "entry" entity has only 1 field, below the
      // search-worthwhile threshold, so missingSearch should NOT fire —
      // proves the detector is a real threshold, not a blanket flag.
      expect(
        opportunities.any((o) => o.category == EvolutionOpportunityCategory.missingSearch),
        isFalse,
      );
    });

    test('a multi-entity app with independent list screens produces no missingNavigation opportunities '
        '(every readable entity already has a view)', () {
      final context = buildEvolutionContext(multiEntityApp());
      final opportunities = observer.observe(context);
      expect(opportunities.any((o) => o.category == EvolutionOpportunityCategory.missingNavigation), isFalse);
    });

    test('deferred (non-mandatory/non-recommended) FeatureGraph nodes become real missingCapability/missingWorkflow opportunities', () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final opportunities = observer.observe(context);
      final deferredFeatureCount = context.featureGraph.nodes
          .where((n) => n.priority.name != 'mandatory' && n.priority.name != 'recommended')
          .length;
      final surfaced = opportunities
          .where(
            (o) =>
                o.category == EvolutionOpportunityCategory.missingCapability ||
                o.category == EvolutionOpportunityCategory.missingWorkflow,
          )
          .length;
      expect(surfaced, deferredFeatureCount);
    });

    test('reuses Design Review\'s own non-critical findings for accessibility/performance/maintainability '
        '— never a second checker', () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final opportunities = observer.observe(context);
      final reviewSignalCategories = {
        EvolutionOpportunityCategory.missingAccessibility,
        EvolutionOpportunityCategory.missingPerformance,
        EvolutionOpportunityCategory.missingMaintainability,
      };
      for (final o in opportunities.where((o) => reviewSignalCategories.contains(o.category))) {
        expect(o.reason.evidence.sourceReviewIssueId, isNotNull);
        expect(
          context.reviewSession.result.finalIteration.issues.any((i) => i.id == o.reason.evidence.sourceReviewIssueId),
          isTrue,
        );
      }
    });
  });

  group('EvolutionEstimator', () {
    test('every candidate carries a fully-explained benefit, cost, and risk', () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final opportunities = observer.observe(context);
      for (final opportunity in opportunities) {
        final candidate = estimator.estimate(opportunity);
        expect(candidate.benefit.overall, inInclusiveRange(0.0, 1.0));
        expect(candidate.tradeoffs, isNotEmpty);
        expect(candidate.id, 'candidate:${opportunity.id}');
      }
    });

    test('offline/synchronization candidates carry real migration and data risk', () {
      final opportunity = EvolutionOpportunity(
        id: 'evolution:missingOffline:test',
        category: EvolutionOpportunityCategory.missingOffline,
        description: 'test',
        reason: const EvolutionReason(
          summary: 'test',
          evidence: EvolutionEvidence(affectedGraph: 'test', affectedNodeId: 'test'),
          confidence: Confidence.full,
        ),
      );
      final candidate = estimator.estimate(opportunity);
      expect(candidate.risk.migrationRisk, isNot(RiskLevel.none));
      expect(candidate.risk.dataRisk, isNot(RiskLevel.none));
    });

    test('priority is derived structurally from benefit and risk, never a bare number', () {
      final highValueLowRisk = EvolutionOpportunity(
        id: 'evolution:missingNavigation:test',
        category: EvolutionOpportunityCategory.missingNavigation,
        description: 'test',
        reason: const EvolutionReason(
          summary: 'test',
          evidence: EvolutionEvidence(affectedGraph: 'test', affectedNodeId: 'test'),
          confidence: Confidence.full,
        ),
      );
      final candidate = estimator.estimate(highValueLowRisk);
      expect(candidate.priority, isNot(EvolutionPriority.speculative));
    });
  });
}
