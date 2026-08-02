/// Solution Scoring — every solution receives one Confidence-typed score
/// per dimension. Reusing `Confidence` (score + reason + risk) rather than
/// a bare double means every score is self-explaining by construction —
/// "explain every score" is enforced by the type, not a convention.
library;

import '../software_architect/confidence.dart';

class SolutionScore {
  final Confidence overall;
  final Confidence engineering;
  final Confidence architecture;
  final Confidence maintainability;
  final Confidence runtime;
  final Confidence performance;
  final Confidence security;
  final Confidence offline;
  final Confidence userExperience;
  final Confidence accessibility;
  final Confidence futureEvolution;

  const SolutionScore({
    required this.overall,
    required this.engineering,
    required this.architecture,
    required this.maintainability,
    required this.runtime,
    required this.performance,
    required this.security,
    required this.offline,
    required this.userExperience,
    required this.accessibility,
    required this.futureEvolution,
  });
}
