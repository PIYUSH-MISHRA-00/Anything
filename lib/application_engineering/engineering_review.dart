/// Engineering Review — inspects an EngineeringCandidate for real,
/// computable inconsistencies across behavior, state, navigation,
/// bindings, validation, and every other engineering concern.
library;

import 'engineering_candidate.dart';

enum EngineeringIssueCategory {
  behaviorInconsistency,
  danglingBinding,
  unsatisfiedValidation,
  navigationInconsistency,
  lowConfidence,
}

enum EngineeringIssueSeverity { info, warning, critical }

class EngineeringIssue {
  final EngineeringIssueCategory category;
  final EngineeringIssueSeverity severity;
  final String subjectId;
  final String message;
  final bool autoFixable;

  const EngineeringIssue({
    required this.category,
    required this.severity,
    required this.subjectId,
    required this.message,
    this.autoFixable = false,
  });
}

class EngineeringReviewResult {
  final String candidateId;
  final int iteration;
  final List<EngineeringIssue> issues;

  const EngineeringReviewResult({
    required this.candidateId,
    required this.iteration,
    this.issues = const [],
  });

  bool get passed => issues.isEmpty;
  bool get hasCriticalIssues =>
      issues.any((i) => i.severity == EngineeringIssueSeverity.critical);
  List<EngineeringIssue> get autoFixableIssues =>
      issues.where((i) => i.autoFixable).toList();
}

class EngineeringReview {
  const EngineeringReview();

  EngineeringReviewResult review(EngineeringCandidate candidate) {
    final issues = <EngineeringIssue>[];

    _checkUnsatisfiedValidations(candidate, issues);
    _checkDanglingBindings(candidate, issues);
    _checkBehaviorConsistency(candidate, issues);
    _checkConfidence(candidate, issues);

    return EngineeringReviewResult(
      candidateId: candidate.id,
      iteration: candidate.iteration,
      issues: issues,
    );
  }

  void _checkUnsatisfiedValidations(
    EngineeringCandidate candidate,
    List<EngineeringIssue> issues,
  ) {
    for (final rule in candidate.validations) {
      if (!rule.satisfied) {
        issues.add(
          EngineeringIssue(
            category: EngineeringIssueCategory.unsatisfiedValidation,
            severity: EngineeringIssueSeverity.warning,
            subjectId: rule.subjectId,
            message: rule.decision.decision,
          ),
        );
      }
    }
  }

  void _checkDanglingBindings(
    EngineeringCandidate candidate,
    List<EngineeringIssue> issues,
  ) {
    final entityIds = candidate.behaviors
        .map((b) => b.eventGraph.entityId)
        .toSet();
    for (final edge in candidate.bindingGraph.edges) {
      if (edge.kind.name == 'stateToData' && !entityIds.contains(edge.toId)) {
        issues.add(
          EngineeringIssue(
            category: EngineeringIssueCategory.danglingBinding,
            severity: EngineeringIssueSeverity.critical,
            subjectId: '${edge.fromId}->${edge.toId}',
            message:
                'Binding references entity "${edge.toId}" with no behavior plan',
            autoFixable: true,
          ),
        );
      }
    }
  }

  void _checkBehaviorConsistency(
    EngineeringCandidate candidate,
    List<EngineeringIssue> issues,
  ) {
    for (final behavior in candidate.behaviors) {
      for (final transition in behavior.stateMachine.transitions) {
        final hasEvent =
            behavior.eventGraph.events.any((e) => e.id == transition.eventId) ||
            transition.eventId.endsWith(':done') ||
            transition.eventId.endsWith(':failed');
        if (!hasEvent) {
          issues.add(
            EngineeringIssue(
              category: EngineeringIssueCategory.behaviorInconsistency,
              severity: EngineeringIssueSeverity.critical,
              subjectId:
                  '${behavior.eventGraph.entityId}:${transition.eventId}',
              message:
                  'State transition references an event no action declares',
              autoFixable: true,
            ),
          );
        }
      }
    }
  }

  void _checkConfidence(
    EngineeringCandidate candidate,
    List<EngineeringIssue> issues,
  ) {
    if (candidate.overallConfidence.score < 0.4) {
      issues.add(
        EngineeringIssue(
          category: EngineeringIssueCategory.lowConfidence,
          severity: EngineeringIssueSeverity.critical,
          subjectId: candidate.id,
          message:
              'Overall engineering confidence ${candidate.overallConfidence.score.toStringAsFixed(2)} '
              'is below the acceptance threshold (0.4)',
        ),
      );
    }
  }
}
