/// EvolutionMemory — accepted/rejected proposals, tradeoffs, and future
/// improvements, retrievable by the structural fingerprint of the design
/// that produced them. Persisted on the Kernel instance, mirroring
/// ReviewMemory (V6): a later request producing the exact same structural
/// shape within the same Kernel lifetime reuses this record rather than
/// re-deriving every opportunity from scratch.
library;

import 'evolution_history.dart';
import 'evolution_result.dart';
import 'evolution_types.dart';

class EvolutionMemory {
  final List<EvolutionResult> _results = [];

  void record(EvolutionResult result) => _results.add(result);

  /// The most recent result recorded for this exact structural
  /// fingerprint, if any.
  EvolutionResult? recall(String fingerprint) {
    for (var i = _results.length - 1; i >= 0; i--) {
      if (_results[i].roadmap.fingerprint == fingerprint) return _results[i];
    }
    return null;
  }

  List<EvolutionDecision> decisionsFor(String fingerprint) {
    return _results
        .where((r) => r.roadmap.fingerprint == fingerprint)
        .expand((r) => r.cycle.iterations)
        .expand((i) => i.decisions)
        .toList();
  }

  List<EvolutionSnapshot> get snapshots => _results.map(snapshotOf).toList();

  int get resultCount => _results.length;
}
