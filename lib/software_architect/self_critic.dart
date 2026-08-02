/// Self Critic — inspects an ArchitectureCandidate for real, computable
/// structural defects. Every check below fires on the candidate's actual
/// typed structure; none of them know or care what any entity is named.
library;

import 'architecture_candidate.dart';
import 'architecture_review.dart';

class SelfCritic {
  const SelfCritic();

  ArchitectureReview review(ArchitectureCandidate candidate) {
    final issues = <ArchitectureIssue>[];

    _checkDuplicateEntities(candidate, issues);
    _checkEmptyEntities(candidate, issues);
    _checkDanglingRelationships(candidate, issues);
    _checkNavigation(candidate, issues);
    _checkCapabilities(candidate, issues);
    _checkConfidence(candidate, issues);

    return ArchitectureReview(
      candidateId: candidate.id,
      iteration: candidate.iteration,
      issues: issues,
    );
  }

  void _checkDuplicateEntities(
    ArchitectureCandidate candidate,
    List<ArchitectureIssue> issues,
  ) {
    final seen = <String>{};
    for (final entity in candidate.entities) {
      final key = entity.name.trim().toLowerCase();
      if (!seen.add(key)) {
        issues.add(
          ArchitectureIssue(
            category: IssueCategory.duplicateEntity,
            severity: IssueSeverity.critical,
            subjectId: entity.entityId,
            message: 'Duplicate entity name "${entity.name}"',
            autoFixable: true,
          ),
        );
      }
    }
  }

  void _checkEmptyEntities(
    ArchitectureCandidate candidate,
    List<ArchitectureIssue> issues,
  ) {
    for (final entity in candidate.entities) {
      if (entity.fieldCount == 0) {
        issues.add(
          ArchitectureIssue(
            category: IssueCategory.poorStorage,
            severity: IssueSeverity.warning,
            subjectId: entity.entityId,
            message: 'Entity "${entity.name}" has no fields to persist',
          ),
        );
      }
    }
  }

  void _checkDanglingRelationships(
    ArchitectureCandidate candidate,
    List<ArchitectureIssue> issues,
  ) {
    final entityIds = candidate.entities.map((e) => e.entityId).toSet();
    for (final rel in candidate.relationships) {
      if (!entityIds.contains(rel.toEntityId)) {
        issues.add(
          ArchitectureIssue(
            category: IssueCategory.navigationIssue,
            severity: IssueSeverity.critical,
            subjectId: '${rel.fromEntityId}.${rel.fieldId}',
            message:
                'Relationship references non-existent entity "${rel.toEntityId}"',
            autoFixable: true,
          ),
        );
      }
    }
  }

  void _checkNavigation(
    ArchitectureCandidate candidate,
    List<ArchitectureIssue> issues,
  ) {
    if (candidate.navigation.screenIds.length > 1 &&
        candidate.navigation.edges.isEmpty) {
      issues.add(
        ArchitectureIssue(
          category: IssueCategory.navigationIssue,
          severity: IssueSeverity.warning,
          subjectId: candidate.navigation.entryScreenId,
          message:
              '${candidate.navigation.screenIds.length} screens declared '
              'but no navigation edges connect them',
        ),
      );
    }
  }

  void _checkCapabilities(
    ArchitectureCandidate candidate,
    List<ArchitectureIssue> issues,
  ) {
    for (final cap in candidate.capabilities) {
      if (!cap.resolved) {
        issues.add(
          ArchitectureIssue(
            category: IssueCategory.missingCapability,
            severity: IssueSeverity.warning,
            subjectId: cap.capabilityId,
            message: 'Capability "${cap.capabilityId}" is not yet implemented',
          ),
        );
      }
    }
  }

  void _checkConfidence(
    ArchitectureCandidate candidate,
    List<ArchitectureIssue> issues,
  ) {
    if (candidate.overallConfidence.score < 0.4) {
      issues.add(
        ArchitectureIssue(
          category: IssueCategory.lowConfidence,
          severity: IssueSeverity.critical,
          subjectId: candidate.id,
          message:
              'Overall confidence ${candidate.overallConfidence.score.toStringAsFixed(2)} '
              'is below the acceptance threshold (0.4)',
        ),
      );
    } else if (candidate.overallConfidence.score < 0.6) {
      issues.add(
        ArchitectureIssue(
          category: IssueCategory.lowConfidence,
          severity: IssueSeverity.warning,
          subjectId: candidate.id,
          message:
              'Overall confidence ${candidate.overallConfidence.score.toStringAsFixed(2)} is marginal',
        ),
      );
    }
  }
}
