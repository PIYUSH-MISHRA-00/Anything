/// Architecture Review — SelfCritic's typed findings against an
/// ArchitectureCandidate, and RefinementPlanner's typed outcome.
library;

enum IssueCategory {
  redundancy,
  duplicateEntity,
  overComplexity,
  missingCapability,
  missingPermission,
  poorStorage,
  navigationIssue,
  securityIssue,
  accessibilityIssue,
  offlineIssue,
  lowConfidence,
}

enum IssueSeverity { info, warning, critical }

class ArchitectureIssue {
  final IssueCategory category;
  final IssueSeverity severity;
  final String subjectId;
  final String message;
  final bool autoFixable;

  const ArchitectureIssue({
    required this.category,
    required this.severity,
    required this.subjectId,
    required this.message,
    this.autoFixable = false,
  });
}

/// SelfCritic's typed verdict for one candidate.
class ArchitectureReview {
  final String candidateId;
  final int iteration;
  final List<ArchitectureIssue> issues;

  const ArchitectureReview({
    required this.candidateId,
    required this.iteration,
    this.issues = const [],
  });

  bool get hasCriticalIssues =>
      issues.any((i) => i.severity == IssueSeverity.critical);

  bool get passed => issues.isEmpty;

  List<ArchitectureIssue> get autoFixableIssues =>
      issues.where((i) => i.autoFixable).toList();
}

/// Outcome of the iterative refinement loop.
enum RefinementOutcome { approved, refinementRequired, budgetExhausted }
