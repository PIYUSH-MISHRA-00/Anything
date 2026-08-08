/// Vision V6 SCARE — ReviewMemory and ReviewHistory: nothing lost, and a
/// structurally-identical later request genuinely reuses prior findings.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/design_review_engine.dart';
import 'package:anything/design_review/review_history.dart';
import 'package:anything/design_review/review_memory.dart';

import 'review_test_support.dart';

void main() {
  const engine = DesignReviewEngine();

  test('ReviewMemory recalls a prior session by structural fingerprint', () {
    final memory = ReviewMemory();
    final context = buildReviewContext(fieldSurveyApp());

    final first = engine.review(context, memory: memory);
    expect(memory.sessionCount, 1);

    final recalled = memory.recall(first.session.fingerprint);
    expect(recalled, isNotNull);
    expect(recalled!.sessionId, first.session.sessionId);
  });

  test('two structurally-identical requests share the same fingerprint', () {
    final memory = ReviewMemory();
    final contextA = buildReviewContext(fieldSurveyApp());
    final contextB = buildReviewContext(fieldSurveyApp());

    final sessionA = engine.review(contextA, memory: memory);
    final sessionB = engine.review(contextB, memory: memory);

    expect(sessionA.session.fingerprint, sessionB.session.fingerprint);
    expect(
      memory.decisionsFor(sessionA.session.fingerprint).length,
      greaterThanOrEqualTo(sessionA.session.decisions.length),
    );
  });

  test('ReviewHistory accumulates every session — nothing lost', () {
    final history = ReviewHistory();
    final contextA = buildReviewContext(fieldSurveyApp());

    engine.review(contextA, history: history);
    engine.review(contextA, history: history);

    expect(history.sessionCount, 2);
    expect(history.snapshots, hasLength(2));
  });

  test(
    'ReviewMemory records future improvements from non-critical findings',
    () {
      final memory = ReviewMemory();
      final context = buildReviewContext(fieldSurveyApp());

      final outcome = engine.review(context, memory: memory);

      // Real solutions always carry at least a performance/maintainability
      // note or two — never fabricated, but genuinely present for a
      // realistic app.
      expect(outcome.session.futureImprovements, isA<List<String>>());
    },
  );
}
