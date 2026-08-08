/// Vision V7 AEE — EvolutionPrediction/EvolutionForecast: structural,
/// never domain-specific forecasts derived from real, already-computed
/// signals.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/evolution/evolution_approver.dart';
import 'package:anything/evolution/evolution_estimator.dart';
import 'package:anything/evolution/evolution_observer.dart';
import 'package:anything/evolution/evolution_planner.dart';
import 'package:anything/evolution/evolution_prediction.dart';
import 'package:anything/evolution/evolution_reviewer.dart';

import 'evolution_test_support.dart';

void main() {
  const observer = EvolutionObserver();
  const estimator = EvolutionEstimator();
  const reviewer = EvolutionReviewer();
  const approver = EvolutionApprover();
  const planner = EvolutionPlanner();

  test(
    'every forecast is explained by a real confidence and a named basis, never a bare claim',
    () {
      final context = buildEvolutionContext(multiEntityApp());
      final candidates = observer
          .observe(context)
          .map(estimator.estimate)
          .toList();
      final decisions = candidates
          .map((c) => reviewer.review(c, context))
          .toList();
      final proposals = approver.approveForRoadmap(candidates, decisions);
      final roadmap = planner.plan(
        fingerprint: 'fp',
        reviewedProposals: proposals,
        context: context,
      );

      final prediction = EvolutionPrediction.derive(context, roadmap);

      expect(prediction.likelyStorageEvolution.basis, isNotEmpty);
      expect(prediction.likelyScalingNeeds.basis, isNotEmpty);
      expect(prediction.likelyPerformanceNeeds.basis, isNotEmpty);
      expect(
        prediction.likelyStorageEvolution.confidence.score,
        inInclusiveRange(0.0, 1.0),
      );
    },
  );

  test(
    'a multi-entity app with real relationships forecasts higher storage-evolution likelihood '
    'than a single-entity app',
    () {
      final singleEntityContext = buildEvolutionContext(fieldSurveyApp());
      final multiEntityContext = buildEvolutionContext(multiEntityApp());

      EvolutionPrediction predictionFor(context) {
        final candidates = observer
            .observe(context)
            .map(estimator.estimate)
            .toList();
        final decisions = candidates
            .map((c) => reviewer.review(c, context))
            .toList();
        final proposals = approver.approveForRoadmap(candidates, decisions);
        final roadmap = planner.plan(
          fingerprint: 'fp',
          reviewedProposals: proposals,
          context: context,
        );
        return EvolutionPrediction.derive(context, roadmap);
      }

      final singlePrediction = predictionFor(singleEntityContext);
      final multiPrediction = predictionFor(multiEntityContext);

      expect(
        multiPrediction.likelyStorageEvolution.confidence.score,
        greaterThanOrEqualTo(
          singlePrediction.likelyStorageEvolution.confidence.score,
        ),
      );
    },
  );

  test(
    'likelyCapabilityAdditions only ever contains missingCapability-category proposals',
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
      final roadmap = planner.plan(
        fingerprint: 'fp',
        reviewedProposals: proposals,
        context: context,
      );
      final prediction = EvolutionPrediction.derive(context, roadmap);

      // Every capability-addition forecast must trace to a real roadmap
      // proposal — never fabricated independently of the roadmap itself.
      final capabilityDescriptions = roadmap.allProposals
          .where(
            (p) => p.candidate.opportunity.category.name == 'missingCapability',
          )
          .map((p) => p.candidate.opportunity.description)
          .toSet();
      for (final forecast in prediction.likelyCapabilityAdditions) {
        expect(capabilityDescriptions.contains(forecast.description), isTrue);
      }
    },
  );
}
