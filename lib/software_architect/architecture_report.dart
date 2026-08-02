/// Architecture Report — the final, typed summary of one ASAE planning
/// run: the approved (or best-effort) candidate, the full review history,
/// and stage timings.
library;

import 'architecture_candidate.dart';
import 'architecture_review.dart';

class PlanningStageTiming {
  final String stage;
  final Duration elapsed;

  const PlanningStageTiming({required this.stage, required this.elapsed});
}

class ArchitectureReport {
  final ArchitectureCandidate finalCandidate;
  final List<ArchitectureReview> reviewHistory;
  final RefinementOutcome outcome;
  final List<PlanningStageTiming> timings;

  const ArchitectureReport({
    required this.finalCandidate,
    required this.reviewHistory,
    required this.outcome,
    this.timings = const [],
  });

  ArchitectureReview get finalReview => reviewHistory.last;

  Duration get totalElapsed =>
      timings.fold(Duration.zero, (total, t) => total + t.elapsed);
}
