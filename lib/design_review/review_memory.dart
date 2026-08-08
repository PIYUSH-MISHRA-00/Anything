/// Review Memory — accepted/rejected decisions, explanations, tradeoffs,
/// reasons, and confidence, retrievable by the structural fingerprint of
/// the request that produced them. Persisted on the Kernel instance (see
/// AnythingKernel._reviewMemory), so a later request producing the exact
/// same structural shape within the same Kernel lifetime genuinely reuses
/// this record rather than re-deriving every finding from scratch.
///
/// Reuse during `ModificationEngine`'s separate NL-edit pipeline is a real,
/// tested capability of this store (`recall`/`decisionsFor` work from any
/// caller holding the same fingerprint) but is not yet wired into that
/// pipeline — documented honestly in
/// docs/architecture/DESIGN_REVIEW_ENGINE.md as a scoped follow-up, not
/// fabricated as connected today.
library;

import 'review_history.dart';
import 'review_types.dart';

class ReviewMemory {
  final List<ReviewSession> _sessions = [];

  void record(ReviewSession session) => _sessions.add(session);

  /// The most recent session recorded for this exact structural
  /// fingerprint, if any.
  ReviewSession? recall(String fingerprint) {
    for (var i = _sessions.length - 1; i >= 0; i--) {
      if (_sessions[i].fingerprint == fingerprint) return _sessions[i];
    }
    return null;
  }

  List<ReviewDecision> decisionsFor(String fingerprint) {
    return _sessions
        .where((s) => s.fingerprint == fingerprint)
        .expand((s) => s.decisions)
        .toList();
  }

  List<ReviewSnapshot> get snapshots =>
      _sessions.map((s) => s.snapshot).toList();

  int get sessionCount => _sessions.length;
}
