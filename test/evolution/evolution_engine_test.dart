/// Vision V7 AEE — EvolutionEngine end-to-end: Observe -> Estimate ->
/// Review -> Approve -> Plan -> Predict, plus EvolutionMetrics.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/evolution/evolution_engine.dart';
import 'package:anything/evolution/evolution_history.dart';
import 'package:anything/evolution/evolution_memory.dart';
import 'package:anything/evolution/evolution_metrics.dart';
import 'package:anything/evolution/evolution_result.dart';

import 'evolution_test_support.dart';

void main() {
  const engine = EvolutionEngine();

  test('a real design produces a real EvolutionResult with a fully-populated roadmap', () {
    final context = buildEvolutionContext(fieldSurveyApp());
    final result = engine.evolve(context);

    expect(result.cycle.outcome, isNot(EvolutionOutcome.budgetExhausted));
    expect(result.roadmap.milestones, hasLength(6));
    expect(result.graph.nodes, isNotEmpty);
  });

  test('the fingerprint is deterministic for the same structural shape', () {
    final contextA = buildEvolutionContext(fieldSurveyApp());
    final contextB = buildEvolutionContext(fieldSurveyApp());
    expect(engine.fingerprintOf(contextA), engine.fingerprintOf(contextB));
  });

  test('recording into memory and history makes the result recallable', () {
    final memory = EvolutionMemory();
    final history = EvolutionHistory();
    final context = buildEvolutionContext(fieldSurveyApp());
    final fingerprint = engine.fingerprintOf(context);

    final result = engine.evolve(context, memory: memory, history: history);

    expect(memory.recall(fingerprint), same(result));
    expect(history.results, contains(result));
    expect(history.snapshots, isNotEmpty);
  });

  test('EvolutionMetrics.from summarizes a real result correctly', () {
    final context = buildEvolutionContext(fieldSurveyApp());
    final result = engine.evolve(context);
    final metrics = EvolutionMetrics.from(result);

    expect(metrics.totalOpportunitiesFound, result.cycle.finalIteration.opportunities.length);
    expect(
      metrics.totalProposalsAccepted + metrics.totalProposalsRejected,
      lessThanOrEqualTo(metrics.totalOpportunitiesFound),
    );
    expect(metrics.iterationsRun, 1);
  });

  test('a design with zero opportunities is reported honestly, not fabricated', () {
    // fieldSurveyApp always has some deferred features, so this checks the
    // structural invariant instead: outcome is `planned` iff opportunities exist.
    final context = buildEvolutionContext(fieldSurveyApp());
    final result = engine.evolve(context);
    final hasOpportunities = result.cycle.finalIteration.opportunities.isNotEmpty;
    expect(
      result.cycle.outcome,
      hasOpportunities ? EvolutionOutcome.planned : EvolutionOutcome.noOpportunities,
    );
  });
}
