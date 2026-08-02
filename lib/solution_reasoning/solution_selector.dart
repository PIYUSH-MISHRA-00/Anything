/// Solution Selector — the Kernel chooses the best candidate from the
/// Pareto-optimal frontier (never dominated by another candidate) via an
/// explicit, ordered tie-break cascade: overall score -> complexity ->
/// security -> maintainability -> offline -> user experience ->
/// engineering cost -> confidence. Never "first candidate wins" — every
/// step is justified by a real, computed property.
library;

import '../feature_discovery/feature_types.dart' show ComplexityLevel;
import 'solution_alternative.dart';
import 'solution_decision.dart';
import 'solution_types.dart';

class SolutionSelector {
  const SolutionSelector();

  SolutionDecision select(List<SolutionCandidate> candidates, SolutionGraph graph) {
    final scored = candidates.where((c) => c.score != null).toList();
    if (scored.isEmpty) {
      throw StateError('SolutionSelector.select called with no scored candidates.');
    }

    final dominatedIds = graph.edges
        .where((e) => e.kind == SolutionRelationKind.dominates)
        .map((e) => e.toCandidateId)
        .toSet();
    final frontier = scored.where((c) => !dominatedIds.contains(c.id)).toList();
    final pool = frontier.isNotEmpty ? frontier : scored;

    final ranked = [...pool]..sort(_compare);
    final selected = ranked.first;

    final rejected = candidates
        .where((c) => c.id != selected.id)
        .map((c) => SolutionAlternative(candidate: c, whyNotSelected: _whyNotSelected(c, selected, dominatedIds)))
        .toList();

    return SolutionDecision(
      selected: selected,
      rejected: rejected,
      graph: graph,
      rationale:
          '"${selected.label}" selected: overall score ${selected.score!.overall.score.toStringAsFixed(2)}, '
          'complexity rank ${solutionComplexityRank(selected.complexity)}, from '
          '${pool.length} Pareto-optimal candidate(s) out of ${candidates.length} generated.',
    );
  }

  int _compare(SolutionCandidate a, SolutionCandidate b) {
    int cmp;

    cmp = b.score!.overall.score.compareTo(a.score!.overall.score);
    if (cmp != 0) return cmp;

    cmp = solutionComplexityRank(a.complexity).compareTo(solutionComplexityRank(b.complexity));
    if (cmp != 0) return cmp;

    cmp = b.score!.security.score.compareTo(a.score!.security.score);
    if (cmp != 0) return cmp;

    cmp = b.score!.maintainability.score.compareTo(a.score!.maintainability.score);
    if (cmp != 0) return cmp;

    cmp = b.score!.offline.score.compareTo(a.score!.offline.score);
    if (cmp != 0) return cmp;

    cmp = b.score!.userExperience.score.compareTo(a.score!.userExperience.score);
    if (cmp != 0) return cmp;

    cmp = _engineeringCostRank(a).compareTo(_engineeringCostRank(b));
    if (cmp != 0) return cmp;

    return b.confidence.score.compareTo(a.confidence.score);
  }

  int _engineeringCostRank(SolutionCandidate candidate) => switch (candidate.complexity.engineering) {
    ComplexityLevel.none => 0,
    ComplexityLevel.low => 1,
    ComplexityLevel.medium => 2,
    ComplexityLevel.high => 3,
  };

  String _whyNotSelected(SolutionCandidate candidate, SolutionCandidate selected, Set<String> dominatedIds) {
    if (dominatedIds.contains(candidate.id)) {
      return 'Dominated: another candidate scores at least as well at no greater complexity.';
    }
    final diff = selected.score!.overall.score - (candidate.score?.overall.score ?? 0.0);
    if (diff > 0.001) {
      return '"${selected.label}" scored higher overall '
          '(${selected.score!.overall.score.toStringAsFixed(2)} vs '
          '${(candidate.score?.overall.score ?? 0.0).toStringAsFixed(2)}).';
    }
    return 'Tied on overall score; "${selected.label}" won the tie-break cascade '
        '(complexity/security/maintainability/offline/user experience/engineering cost/confidence).';
  }
}
