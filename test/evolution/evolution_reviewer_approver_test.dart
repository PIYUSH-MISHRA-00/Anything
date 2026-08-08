/// Vision V7 AEE — EvolutionReviewer (reuses SCARE directly, never
/// duplicates review logic) and EvolutionApprover (promotes only
/// accepted candidates to roadmap-eligible proposals, never executes).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/evolution/evolution_approver.dart';
import 'package:anything/evolution/evolution_candidate.dart';
import 'package:anything/evolution/evolution_estimator.dart';
import 'package:anything/evolution/evolution_observer.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_reviewer.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/software_architect/confidence.dart';

import 'evolution_test_support.dart';

void main() {
  const observer = EvolutionObserver();
  const estimator = EvolutionEstimator();
  const reviewer = EvolutionReviewer();
  const approver = EvolutionApprover();

  group('EvolutionReviewer', () {
    test(
      'every real, observed candidate is accepted (its evidence is real by construction)',
      () {
        final context = buildEvolutionContext(fieldSurveyApp());
        final candidates = observer
            .observe(context)
            .map(estimator.estimate)
            .toList();
        for (final candidate in candidates) {
          final decision = reviewer.review(candidate, context);
          expect(
            decision.kind,
            EvolutionDecisionKind.accepted,
            reason: candidate.opportunity.id,
          );
        }
      },
    );

    test(
      'a candidate whose sourceReviewIssueId no longer exists is rejected',
      () {
        final context = buildEvolutionContext(fieldSurveyApp());
        final fake = EvolutionCandidate(
          id: 'candidate:fake',
          opportunity: EvolutionOpportunity(
            id: 'evolution:missingAccessibility:fake',
            category: EvolutionOpportunityCategory.missingAccessibility,
            description: 'fake',
            reason: const EvolutionReason(
              summary: 'fake',
              evidence: EvolutionEvidence(
                affectedGraph: 'test',
                affectedNodeId: 'test',
                sourceReviewIssueId: 'issue:does-not-exist',
              ),
              confidence: Confidence.full,
            ),
          ),
          cost: const EvolutionCost(),
          risk: const EvolutionRisk(),
          benefit: const EvolutionBenefit(
            engineeringValue: Confidence.full,
            userValue: Confidence.full,
            maintenanceValue: Confidence.full,
            performanceValue: Confidence.full,
            securityValue: Confidence.full,
            accessibilityValue: Confidence.full,
            offlineValue: Confidence.full,
            futureValue: Confidence.full,
          ),
        );
        final decision = reviewer.review(fake, context);
        expect(decision.kind, EvolutionDecisionKind.rejected);
      },
    );

    test(
      'a candidate whose referenced entity no longer exists in the architecture is rejected',
      () {
        final context = buildEvolutionContext(fieldSurveyApp());
        final fake = EvolutionCandidate(
          id: 'candidate:fake2',
          opportunity: EvolutionOpportunity(
            id: 'evolution:missingNavigation:ghost-entity',
            category: EvolutionOpportunityCategory.missingNavigation,
            description: 'fake',
            reason: const EvolutionReason(
              summary: 'fake',
              evidence: EvolutionEvidence(
                affectedGraph: 'test',
                affectedNodeId: 'ghost-entity',
              ),
              confidence: Confidence.full,
            ),
          ),
          cost: const EvolutionCost(),
          risk: const EvolutionRisk(),
          benefit: const EvolutionBenefit(
            engineeringValue: Confidence.full,
            userValue: Confidence.full,
            maintenanceValue: Confidence.full,
            performanceValue: Confidence.full,
            securityValue: Confidence.full,
            accessibilityValue: Confidence.full,
            offlineValue: Confidence.full,
            futureValue: Confidence.full,
          ),
        );
        final decision = reviewer.review(fake, context);
        expect(decision.kind, EvolutionDecisionKind.rejected);
      },
    );
  });

  group('EvolutionApprover', () {
    test(
      'only accepted candidates become roadmap-eligible proposals, and none are pre-approved for execution',
      () {
        final context = buildEvolutionContext(fieldSurveyApp());
        final candidates = observer
            .observe(context)
            .map(estimator.estimate)
            .toList();
        final decisions = candidates
            .map((c) => reviewer.review(c, context))
            .toList();
        final proposals = approver.approveForRoadmap(candidates, decisions);

        expect(
          proposals.length,
          decisions
              .where((d) => d.kind == EvolutionDecisionKind.accepted)
              .length,
        );
        for (final proposal in proposals) {
          expect(proposal.approvedForExecution, isFalse);
        }
      },
    );
  });
}
