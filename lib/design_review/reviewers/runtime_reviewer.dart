/// Runtime Review — checks the engineered design's real counts (screens,
/// state variables, events, bindings, behavior nodes) against
/// RuntimeSecurityLimits (M2's single trusted source of truth for every
/// resource boundary) *before* Creation ever runs, rather than only
/// discovering an over-budget package after it's built.
library;

import '../../security/runtime_security_limits.dart';
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class RuntimeReviewer {
  const RuntimeReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final issues = <ReviewIssue>[];
    final blueprint = context.blueprint;
    final engineering = context.engineering;

    void checkBudget(String dimension, int actual, int limit, String graph) {
      if (actual > limit) {
        issues.add(
          ReviewIssue(
            id: 'runtime:overBudget:$dimension',
            category: ReviewCategory.runtime,
            severity: ReviewSeverity.critical,
            reason:
                '$dimension is $actual, exceeding RuntimeSecurityLimits ($limit)',
            evidence: ReviewEvidence(
              affectedGraph: graph,
              affectedNodeId: dimension,
            ),
            recommendation: const ReviewRecommendation(
              description:
                  'Reduce scope until this fits the trusted runtime budget',
            ),
            confidence: Confidence.full,
          ),
        );
      } else if (actual > (limit * 0.8).floor()) {
        issues.add(
          ReviewIssue(
            id: 'runtime:approachingBudget:$dimension',
            category: ReviewCategory.runtime,
            severity: ReviewSeverity.info,
            reason:
                '$dimension is $actual, approaching RuntimeSecurityLimits ($limit)',
            evidence: ReviewEvidence(
              affectedGraph: graph,
              affectedNodeId: dimension,
            ),
            recommendation: const ReviewRecommendation(
              description: 'No action needed yet; monitor as the design grows',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    checkBudget(
      'screenCount',
      blueprint.views.length,
      RuntimeSecurityLimits.maxScreensPerPackage,
      'AppBlueprint.views',
    );

    final eventCount = engineering.behaviors
        .expand((b) => b.eventGraph.events)
        .length;
    final actionCount = engineering.behaviors
        .expand((b) => b.eventGraph.actions)
        .length;
    final estimatedBehaviorNodes = eventCount + actionCount;
    checkBudget(
      'behaviorNodeCount',
      estimatedBehaviorNodes,
      RuntimeSecurityLimits.maxBehaviorNodesPerPackage,
      'EngineeringCandidate.behaviors',
    );

    final bindingCount = engineering.bindingGraph.edges.length;
    checkBudget(
      'bindingCount',
      bindingCount,
      RuntimeSecurityLimits.maxBehaviorNodesPerPackage,
      'EngineeringCandidate.bindingGraph',
    );

    final stateCount = context.architecture.states.length;
    checkBudget(
      'stateCount',
      stateCount,
      RuntimeSecurityLimits.maxBehaviorNodesPerPackage,
      'ArchitectureCandidate.states',
    );

    return issues;
  }
}
