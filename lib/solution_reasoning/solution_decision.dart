/// Solution Decision — the final output of Multi-Solution Reasoning: the
/// selected SolutionCandidate, every rejected alternative with a concrete
/// reason, the comparison graph the decision was based on, and the overall
/// rationale for the selection.
library;

import 'solution_alternative.dart';
import 'solution_types.dart';

class SolutionDecision {
  final SolutionCandidate selected;
  final List<SolutionAlternative> rejected;
  final SolutionGraph graph;
  final String rationale;

  const SolutionDecision({
    required this.selected,
    required this.rejected,
    required this.graph,
    required this.rationale,
  });
}
