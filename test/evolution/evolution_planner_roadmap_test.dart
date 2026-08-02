/// Vision V7 AEE — EvolutionPlanner (ranking + phase placement) and
/// EvolutionRoadmap (Current/Immediate/Next/Later/Future/Experimental).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/evolution/evolution_approver.dart';
import 'package:anything/evolution/evolution_budget.dart';
import 'package:anything/evolution/evolution_estimator.dart';
import 'package:anything/evolution/evolution_observer.dart';
import 'package:anything/evolution/evolution_planner.dart';
import 'package:anything/evolution/evolution_policy.dart';
import 'package:anything/evolution/evolution_reviewer.dart';
import 'package:anything/evolution/evolution_types.dart';

import 'evolution_test_support.dart';

void main() {
  const observer = EvolutionObserver();
  const estimator = EvolutionEstimator();
  const reviewer = EvolutionReviewer();
  const approver = EvolutionApprover();
  const planner = EvolutionPlanner();

  group('EvolutionRoadmap', () {
    test('every roadmap always owns all 6 phases, even when empty', () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final candidates = observer.observe(context).map(estimator.estimate).toList();
      final decisions = candidates.map((c) => reviewer.review(c, context)).toList();
      final proposals = approver.approveForRoadmap(candidates, decisions);
      final roadmap = planner.plan(fingerprint: 'fp', reviewedProposals: proposals, context: context);

      expect(roadmap.milestones.map((m) => m.phase).toSet(), EvolutionPhase.values.toSet());
    });

    test('the roadmap never exceeds EvolutionBudget.maxProposalsOnRoadmap', () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final candidates = observer.observe(context).map(estimator.estimate).toList();
      final decisions = candidates.map((c) => reviewer.review(c, context)).toList();
      final proposals = approver.approveForRoadmap(candidates, decisions);
      const budget = EvolutionBudget(maxProposalsOnRoadmap: 1);
      final roadmap = planner.plan(fingerprint: 'fp', reviewedProposals: proposals, context: context, budget: budget);

      expect(roadmap.allProposals.length, lessThanOrEqualTo(1));
    });
  });

  group('EvolutionPlanner strategy', () {
    test('a conservative strategy never places a proposal in a lower-risk-tolerant phase than aggressive would', () {
      final conservativeContext = buildEvolutionContext(fieldSurveyApp(), strategy: EvolutionStrategy.conservative);
      final aggressiveContext = buildEvolutionContext(fieldSurveyApp(), strategy: EvolutionStrategy.aggressive);

      final conservativeCandidates = observer.observe(conservativeContext).map(estimator.estimate).toList();
      final conservativeDecisions = conservativeCandidates.map((c) => reviewer.review(c, conservativeContext)).toList();
      final conservativeProposals = approver.approveForRoadmap(conservativeCandidates, conservativeDecisions);
      final conservativeRoadmap = planner.plan(
        fingerprint: 'fp',
        reviewedProposals: conservativeProposals,
        context: conservativeContext,
      );

      final aggressiveCandidates = observer.observe(aggressiveContext).map(estimator.estimate).toList();
      final aggressiveDecisions = aggressiveCandidates.map((c) => reviewer.review(c, aggressiveContext)).toList();
      final aggressiveProposals = approver.approveForRoadmap(aggressiveCandidates, aggressiveDecisions);
      final aggressiveRoadmap = planner.plan(
        fingerprint: 'fp',
        reviewedProposals: aggressiveProposals,
        context: aggressiveContext,
      );

      // Same candidates, different policy: aggressive's "immediate" count
      // must be at least the conservative one's, never fewer.
      expect(
        aggressiveRoadmap.proposalsFor(EvolutionPhase.immediate).length,
        greaterThanOrEqualTo(conservativeRoadmap.proposalsFor(EvolutionPhase.immediate).length),
      );
    });
  });
}
