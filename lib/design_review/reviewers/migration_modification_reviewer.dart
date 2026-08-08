/// Migration & Modification Review — MigrationReviewer wraps
/// DataEngineering's own migration decision (V4) rather than re-deriving
/// it; ModificationReviewer confirms the design still honors the
/// futureModification non-functional requirement RequirementExtractor
/// (V2) always records.
library;

import '../../software_architect/confidence.dart';
import '../../software_architect/requirement_graph.dart'
    show NonFunctionalCategory;
import '../review_context.dart';
import '../review_types.dart';

class MigrationReviewer {
  const MigrationReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final decision = context.engineering.data.migrationDecision;
    final issues = <ReviewIssue>[];

    if (decision.decision.trim().isEmpty || decision.rationale.trim().isEmpty) {
      issues.add(
        ReviewIssue(
          id: 'migration:missingDecision',
          category: ReviewCategory.migration,
          severity: ReviewSeverity.critical,
          reason: 'No real migration decision was recorded for this design',
          evidence: const ReviewEvidence(
            affectedGraph: 'EngineeringCandidate.data',
            affectedNodeId: 'migrationDecision',
          ),
          recommendation: const ReviewRecommendation(
            description:
                'Run DataEngineering to produce a real migration decision',
          ),
          confidence: Confidence.full,
        ),
      );
    }

    return issues;
  }
}

class ModificationReviewer {
  const ModificationReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final hasFutureModificationRequirement = context.requirements.nonFunctional
        .any((r) => r.category == NonFunctionalCategory.futureModification);
    final issues = <ReviewIssue>[];

    if (!hasFutureModificationRequirement) {
      issues.add(
        ReviewIssue(
          id: 'modification:missingRequirement',
          category: ReviewCategory.modification,
          severity: ReviewSeverity.warning,
          reason:
              'No future-modification non-functional requirement was recorded for this request',
          evidence: const ReviewEvidence(
            affectedGraph: 'RequirementGraph.nonFunctional',
            affectedNodeId: 'futureModification',
          ),
          recommendation: const ReviewRecommendation(
            description: 'Confirm RequirementExtractor ran for this request',
          ),
          confidence: Confidence.full,
        ),
      );
    }

    return issues;
  }
}
