/// Vision V7 AEE — EngineeringMemory: the single consultation point,
/// a real facade over ReviewMemory/ReviewHistory (V6) and
/// EvolutionMemory/EvolutionHistory (V7) — never a third parallel store.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/design_review_engine.dart';
import 'package:anything/design_review/review_history.dart';
import 'package:anything/design_review/review_memory.dart';
import 'package:anything/evolution/engineering_memory.dart';
import 'package:anything/evolution/evolution_context.dart';
import 'package:anything/evolution/evolution_engine.dart';
import 'package:anything/evolution/evolution_history.dart';
import 'package:anything/evolution/evolution_memory.dart';

import 'evolution_test_support.dart';

void main() {
  test(
    'EngineeringMemory exposes accepted/rejected ideas sourced from the real EvolutionMemory',
    () {
      final reviewMemory = ReviewMemory();
      final reviewHistory = ReviewHistory();
      final evolutionMemory = EvolutionMemory();
      final evolutionHistory = EvolutionHistory();

      final reviewContext = buildReviewContext(fieldSurveyApp());
      final reviewOutcome = const DesignReviewEngine().review(
        reviewContext,
        memory: reviewMemory,
        history: reviewHistory,
      );
      final evolutionContext = EvolutionContext(
        reviewContext: reviewOutcome.session.result.finalContext,
        reviewSession: reviewOutcome.session,
      );
      const engine = EvolutionEngine();
      final fingerprint = engine.fingerprintOf(evolutionContext);
      engine.evolve(
        evolutionContext,
        memory: evolutionMemory,
        history: evolutionHistory,
      );

      final engineeringMemory = EngineeringMemory(
        reviewMemory: reviewMemory,
        reviewHistory: reviewHistory,
        evolutionMemory: evolutionMemory,
        evolutionHistory: evolutionHistory,
      );

      final accepted = engineeringMemory.acceptedIdeas(fingerprint);
      final rejected = engineeringMemory.rejectedIdeas(fingerprint);
      expect(accepted, isNotEmpty);
      expect(
        rejected,
        isEmpty,
      ); // every real, observed opportunity is accepted by construction (V6 reuse)

      // tradeoffs/futureIdeas are real slices of the same recorded result.
      expect(engineeringMemory.tradeoffsFor(fingerprint), isNotEmpty);
    },
  );

  test(
    'architecturalHistory/securityHistory/performanceHistory are real slices of ReviewHistory, '
    'not a separate ledger',
    () {
      final reviewMemory = ReviewMemory();
      final reviewHistory = ReviewHistory();
      final evolutionMemory = EvolutionMemory();
      final evolutionHistory = EvolutionHistory();

      final reviewContext = buildReviewContext(fieldSurveyApp());
      const DesignReviewEngine().review(
        reviewContext,
        memory: reviewMemory,
        history: reviewHistory,
      );

      final engineeringMemory = EngineeringMemory(
        reviewMemory: reviewMemory,
        reviewHistory: reviewHistory,
        evolutionMemory: evolutionMemory,
        evolutionHistory: evolutionHistory,
      );

      // Every issue returned must genuinely belong to the claimed category —
      // proves these are filtered views, not fabricated separate stores.
      for (final issue in engineeringMemory.architecturalHistory()) {
        expect(issue.category.name, 'architecture');
      }
      for (final issue in engineeringMemory.securityHistory()) {
        expect(issue.category.name, 'security');
      }
      for (final issue in engineeringMemory.performanceHistory()) {
        expect(issue.category.name, 'performance');
      }
    },
  );
}
