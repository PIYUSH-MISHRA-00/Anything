/// Solution Alternative — one candidate that was considered but not
/// selected, paired with a concrete reason why.
library;

import 'solution_types.dart';

class SolutionAlternative {
  final SolutionCandidate candidate;
  final String whyNotSelected;

  const SolutionAlternative({required this.candidate, required this.whyNotSelected});
}
