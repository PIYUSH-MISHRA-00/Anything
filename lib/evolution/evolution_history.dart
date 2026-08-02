/// EvolutionHistory — every evolution pass ever run, in order. Nothing is
/// ever removed or overwritten; later modifications reuse this record,
/// mirroring ReviewHistory (V6).
library;

import 'evolution_result.dart';

class EvolutionSnapshot {
  final String fingerprint;
  final int opportunityCount;
  final int proposalCount;
  final EvolutionOutcome outcome;
  final DateTime recordedAt;

  const EvolutionSnapshot({
    required this.fingerprint,
    required this.opportunityCount,
    required this.proposalCount,
    required this.outcome,
    required this.recordedAt,
  });
}

EvolutionSnapshot snapshotOf(EvolutionResult result) => EvolutionSnapshot(
  fingerprint: result.roadmap.fingerprint,
  opportunityCount: result.cycle.finalIteration.opportunities.length,
  proposalCount: result.roadmap.allProposals.length,
  outcome: result.cycle.outcome,
  recordedAt: result.roadmap.generatedAt,
);

class EvolutionHistory {
  final List<EvolutionResult> _results = [];

  void record(EvolutionResult result) => _results.add(result);

  List<EvolutionResult> get results => List.unmodifiable(_results);

  List<EvolutionSnapshot> get snapshots => _results.map(snapshotOf).toList();

  int get resultCount => _results.length;
}
