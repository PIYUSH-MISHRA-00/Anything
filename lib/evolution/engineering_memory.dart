/// EngineeringMemory — the single consultation point every future
/// modification or evolution pass must go through. Deliberately a facade
/// over the real, already-persisted stores rather than a second parallel
/// ledger: [ReviewMemory]/[ReviewHistory] (V6, every design-review
/// decision, including security/performance/accessibility/architecture
/// findings categorized within each session) and [EvolutionMemory]/
/// [EvolutionHistory] (V7, every evolution decision and tradeoff).
/// "Performance history"/"security history"/"architectural history" are
/// real slices of the same ReviewHistory sessions (SCARE already
/// categorizes every finding by [ReviewCategory]) rather than three more
/// stores duplicating what SCARE already records.
library;

import '../design_review/review_history.dart';
import '../design_review/review_memory.dart';
import '../design_review/review_types.dart';
import '../solution_reasoning/solution_tradeoff.dart' show SolutionTradeoff;
import 'evolution_history.dart';
import 'evolution_memory.dart';
import 'evolution_types.dart';

class EngineeringMemory {
  final ReviewMemory reviewMemory;
  final ReviewHistory reviewHistory;
  final EvolutionMemory evolutionMemory;
  final EvolutionHistory evolutionHistory;

  const EngineeringMemory({
    required this.reviewMemory,
    required this.reviewHistory,
    required this.evolutionMemory,
    required this.evolutionHistory,
  });

  List<EvolutionDecision> acceptedIdeas(String fingerprint) => evolutionMemory
      .decisionsFor(fingerprint)
      .where((d) => d.kind == EvolutionDecisionKind.accepted)
      .toList();

  List<EvolutionDecision> rejectedIdeas(String fingerprint) => evolutionMemory
      .decisionsFor(fingerprint)
      .where((d) => d.kind == EvolutionDecisionKind.rejected)
      .toList();

  List<ReviewDecision> reviewDecisionsFor(String fingerprint) =>
      reviewMemory.decisionsFor(fingerprint);

  List<SolutionTradeoff> tradeoffsFor(String fingerprint) {
    final result = evolutionMemory.recall(fingerprint);
    if (result == null) return const [];
    return result.cycle.finalIteration.candidates
        .expand((c) => c.tradeoffs)
        .toList();
  }

  List<String> futureIdeasFor(String fingerprint) {
    final result = evolutionMemory.recall(fingerprint);
    if (result == null) return const [];
    return [
      ...result.roadmap.proposalsFor(EvolutionPhase.future),
      ...result.roadmap.proposalsFor(EvolutionPhase.experimental),
    ].map((p) => p.candidate.opportunity.description).toList();
  }

  /// Every architecture-category finding SCARE has ever recorded — a real
  /// slice of ReviewHistory, not a separate ledger.
  List<ReviewIssue> architecturalHistory() =>
      _issuesOfCategory(ReviewCategory.architecture);

  /// Every security-category finding SCARE has ever recorded.
  List<ReviewIssue> securityHistory() =>
      _issuesOfCategory(ReviewCategory.security);

  /// Every performance-category finding SCARE has ever recorded.
  List<ReviewIssue> performanceHistory() =>
      _issuesOfCategory(ReviewCategory.performance);

  List<ReviewIssue> _issuesOfCategory(ReviewCategory category) => reviewHistory
      .sessions
      .expand((s) => s.result.allIssues)
      .where((issue) => issue.category == category)
      .toList();
}
