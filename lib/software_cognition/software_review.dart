/// SoftwareReview — reviews acquired software UNDERSTANDING itself
/// (confidence, provenance completeness), reusing SCARE's own typed
/// severity/confidence vocabulary (`ReviewSeverity`,
/// `lib/design_review/review_types.dart`) rather than inventing a
/// parallel one. This is intentionally a separate, additive review pass
/// — not a 16th mandatory SCARE sub-reviewer wired into the Kernel's
/// review gate, since ReviewContext's shape is depended on by every
/// existing reviewer/test and Software Cognition's acquisition is
/// optional, not a mandatory part of every generation. Mirrors how
/// EvolutionReviewer (V7) reused ReviewSession directly without SCARE
/// re-running its own review.
library;

import '../design_review/review_types.dart' show ReviewSeverity;
import 'package_model.dart';
import 'repository_model.dart';
import 'software_types.dart' show SoftwareEvidence;

class SoftwareReviewIssue {
  final ReviewSeverity severity;
  final String reason;
  final SoftwareEvidence evidence;

  const SoftwareReviewIssue({
    required this.severity,
    required this.reason,
    required this.evidence,
  });
}

class SoftwareReview {
  const SoftwareReview();

  /// WebWeaveX's own repository-confidence heuristic only ever returns
  /// 0.4 (not parser-backed) or 0.8 (parser-backed) — the threshold sits
  /// between them so "not backed by real parser evidence" is the actual,
  /// reachable warning condition, not an unreachable near-zero value.
  static const double _lowConfidenceThreshold = 0.5;

  List<SoftwareReviewIssue> reviewRepository(RepositoryModel model) {
    final issues = <SoftwareReviewIssue>[];
    final evidence = SoftwareEvidence(
      sourceUrl: model.metadata.provenance.sourceUrl,
      sourceArtifact: model.metadata.name,
    );

    if (model.confidence.score < _lowConfidenceThreshold) {
      issues.add(
        SoftwareReviewIssue(
          severity: ReviewSeverity.warning,
          reason:
              'Repository understanding has low confidence (${model.confidence.score.toStringAsFixed(2)}): ${model.confidence.reason}',
          evidence: evidence,
        ),
      );
    }
    if (model.metadata.provenance.sourceUrl.isEmpty) {
      issues.add(
        SoftwareReviewIssue(
          severity: ReviewSeverity.critical,
          reason:
              'Repository has no recorded source URL — provenance is not traceable.',
          evidence: evidence,
        ),
      );
    }
    return issues;
  }

  List<SoftwareReviewIssue> reviewPackage(PackageModel model) {
    final issues = <SoftwareReviewIssue>[];
    final evidence = SoftwareEvidence(
      sourceUrl: model.metadata.provenance.sourceUrl,
      sourceArtifact: model.metadata.name,
    );

    if (model.confidence.score < _lowConfidenceThreshold) {
      issues.add(
        SoftwareReviewIssue(
          severity: ReviewSeverity.warning,
          reason:
              'Package understanding has low confidence (${model.confidence.score.toStringAsFixed(2)}): ${model.confidence.reason}',
          evidence: evidence,
        ),
      );
    }
    if (model.metadata.provenance.sourceUrl.isEmpty) {
      issues.add(
        SoftwareReviewIssue(
          severity: ReviewSeverity.critical,
          reason:
              'Package has no recorded source URL — provenance is not traceable.',
          evidence: evidence,
        ),
      );
    }
    return issues;
  }

  bool hasCriticalIssues(List<SoftwareReviewIssue> issues) =>
      issues.any((i) => i.severity == ReviewSeverity.critical);
}
