/// Performance Review — estimates memory/CPU/storage/network/battery/
/// startup/runtime/modification/migration cost from the SELECTED
/// solution's own real FeatureComplexity profile (Vision Milestone V5) —
/// never a new, independent cost model. Only dimensions at medium/high
/// complexity are surfaced; low/none carry nothing worth reporting.
///
/// MaintainabilityReviewer is the long-term-cost counterpart: it looks at
/// the SAME complexity profile plus how many issues the rest of Design
/// Review found, as a real proxy for how much future work this design
/// will need.
library;

import '../../feature_discovery/feature_types.dart' show ComplexityLevel;
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class PerformanceReviewer {
  const PerformanceReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final complexity = context.solution.complexity;
    final issues = <ReviewIssue>[];

    void report(String dimension, ComplexityLevel level, String graph) {
      if (level == ComplexityLevel.none || level == ComplexityLevel.low) return;
      issues.add(
        ReviewIssue(
          id: 'performance:$dimension',
          category: ReviewCategory.performance,
          severity: level == ComplexityLevel.high ? ReviewSeverity.warning : ReviewSeverity.info,
          reason: '$dimension cost is ${level.name} for this solution',
          evidence: ReviewEvidence(affectedGraph: graph, affectedNodeId: dimension),
          recommendation: ReviewRecommendation(description: 'Consider the ${level.name} $dimension cost when reviewing this solution'),
          confidence: const Confidence(score: 0.7, reason: 'Derived from the solution\'s own real FeatureComplexity profile.'),
        ),
      );
    }

    report('memory', complexity.memoryCost, 'SolutionCandidate.complexity');
    report('cpu', complexity.runtime, 'SolutionCandidate.complexity');
    report('storage', complexity.storageCost, 'SolutionCandidate.complexity');
    report('network', complexity.networkCost, 'SolutionCandidate.complexity');
    report('battery', complexity.batteryCost, 'SolutionCandidate.complexity');
    report('runtime', complexity.runtime, 'SolutionCandidate.complexity');
    report('modification', complexity.modificationCost, 'SolutionCandidate.complexity');

    // Startup: proxied by total engineered behavior node count — more
    // nodes means more to parse before the first frame renders.
    final totalNodes = context.engineering.behaviors.expand((b) => b.eventGraph.actions).length;
    if (totalNodes > 20) {
      issues.add(
        ReviewIssue(
          id: 'performance:startup',
          category: ReviewCategory.performance,
          severity: ReviewSeverity.info,
          reason: 'Engineered behavior has $totalNodes actions — a real, if modest, startup parse cost',
          evidence: const ReviewEvidence(affectedGraph: 'EngineeringCandidate.behaviors', affectedNodeId: 'startup'),
          recommendation: const ReviewRecommendation(description: 'No action needed below RuntimeSecurityLimits.maxBehaviorNodesPerPackage'),
          confidence: const Confidence(score: 0.6, reason: 'Action count is a real but indirect proxy for parse cost.'),
        ),
      );
    }

    // Migration cost is reviewed by MigrationReviewer, which reuses
    // DataEngineering's own decision rather than re-deriving it here.

    return issues;
  }
}

class MaintainabilityReviewer {
  const MaintainabilityReviewer();

  List<ReviewIssue> review(ReviewContext context, {required int otherIssueCount}) {
    final complexity = context.solution.complexity;
    final issues = <ReviewIssue>[];

    final highComplexityDimensions = [
      complexity.implementation,
      complexity.engineering,
      complexity.maintenanceCost,
    ].where((l) => l == ComplexityLevel.high).length;

    if (highComplexityDimensions >= 2) {
      issues.add(
        ReviewIssue(
          id: 'maintainability:highComplexity',
          category: ReviewCategory.maintainability,
          severity: ReviewSeverity.warning,
          reason: '$highComplexityDimensions of 3 core complexity dimensions are high — this design will be costly to maintain',
          evidence: const ReviewEvidence(affectedGraph: 'SolutionCandidate.complexity', affectedNodeId: 'maintainability'),
          recommendation: const ReviewRecommendation(description: 'Consider a lower-richness/lower-complexity solution variant'),
          confidence: const Confidence(score: 0.6, reason: 'A structural proxy, not a measured maintenance cost.'),
        ),
      );
    }

    if (otherIssueCount > 15) {
      issues.add(
        ReviewIssue(
          id: 'maintainability:highIssueVolume',
          category: ReviewCategory.maintainability,
          severity: ReviewSeverity.info,
          reason: '$otherIssueCount findings were raised elsewhere in this review — a real signal of design surface area',
          evidence: const ReviewEvidence(affectedGraph: 'ReviewResult', affectedNodeId: 'issueVolume'),
          recommendation: const ReviewRecommendation(description: 'Address the highest-severity findings first'),
          confidence: const Confidence(score: 0.5, reason: 'Issue volume correlates with, but does not prove, maintenance burden.'),
        ),
      );
    }

    return issues;
  }
}
