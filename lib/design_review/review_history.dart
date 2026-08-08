/// Review History — every review session ever run, in order. Nothing is
/// ever removed or overwritten; later modifications reuse this record
/// rather than re-deriving it.
library;

import 'review_result.dart';
import 'review_types.dart';

/// The complete, storable record of one Design Review run: the review
/// result itself, what ultimately happened to each finding, and the
/// non-critical recommendations that were surfaced but not acted on
/// (the milestone's "future improvements").
class ReviewSession {
  final String sessionId;
  final String fingerprint;
  final DateTime startedAt;
  final ReviewResult result;
  final List<ReviewDecision> decisions;
  final List<String> futureImprovements;

  const ReviewSession({
    required this.sessionId,
    required this.fingerprint,
    required this.startedAt,
    required this.result,
    this.decisions = const [],
    this.futureImprovements = const [],
  });

  ReviewSnapshot get snapshot => ReviewSnapshot(
    fingerprint: fingerprint,
    outcome: result.outcome,
    issueCount: result.finalIteration.issues.length,
    criticalCount: result.finalIteration.issues
        .where((i) => i.severity == ReviewSeverity.critical)
        .length,
    recordedAt: startedAt,
  );
}

class ReviewSnapshot {
  final String fingerprint;
  final ReviewOutcome outcome;
  final int issueCount;
  final int criticalCount;
  final DateTime recordedAt;

  const ReviewSnapshot({
    required this.fingerprint,
    required this.outcome,
    required this.issueCount,
    required this.criticalCount,
    required this.recordedAt,
  });
}

class ReviewHistory {
  final List<ReviewSession> _sessions = [];

  void record(ReviewSession session) => _sessions.add(session);

  List<ReviewSession> get sessions => List.unmodifiable(_sessions);

  List<ReviewSnapshot> get snapshots =>
      _sessions.map((s) => s.snapshot).toList();

  int get sessionCount => _sessions.length;
}
