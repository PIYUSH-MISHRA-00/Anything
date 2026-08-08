/// Review Refinement — review the full design, apply conservative
/// auto-fixes, re-review, until either no critical issues remain or a
/// configurable iteration budget is exhausted. Mirrors the proven-
/// terminating design already established by ASAE/AEE/FDI/MSRA.
///
/// Deliberately conservative: only edge-level graph cleanups with zero
/// cascading risk are ever auto-applied (dead/unused BindingGraph edges,
/// duplicate BindingGraph/DependencyGraph edges) — anything with wider
/// blast radius (orphan entities, unsafe permissions, unused state/
/// navigation) is always surfaced for review only, never silently
/// removed. Every fix is recorded in the resulting ReviewSession's
/// decisions — nothing is ever applied without a logged explanation.
library;

import '../application_engineering/engineering_candidate.dart';
import '../application_engineering/engineering_plan.dart';
import '../application_engineering/engineering_types.dart'
    show BindingEdge, BindingGraph;
import '../feature_discovery/dependency_types.dart';
import '../solution_reasoning/solution_types.dart';
import '../solution_reasoning/solution_variation_types.dart'
    show EngineeringVariation;
import 'design_reviewer.dart';
import 'review_budget.dart';
import 'review_context.dart';
import 'review_result.dart';
import 'review_types.dart';

class ReviewRefinement {
  final DesignReviewer _reviewer;
  final ReviewBudget _budget;

  const ReviewRefinement({
    DesignReviewer reviewer = const DesignReviewer(),
    ReviewBudget budget = const ReviewBudget(),
  }) : _reviewer = reviewer,
       _budget = budget;

  ReviewResult refine(ReviewContext initial) {
    var context = initial;
    var iteration = _reviewer.review(context, iteration: 0);
    final iterations = [iteration];

    // Auto-fixes apply regardless of severity — "autonomous improvement"
    // (removing a duplicate/dead edge) is valuable even when the finding
    // is only a warning, not just when it blocks approval outright.
    var i = 0;
    while (iteration.autoFixableIssues.isNotEmpty &&
        i < _budget.maxIterations) {
      context = _applyFixes(context, iteration.autoFixableIssues);
      i++;
      iteration = _reviewer.review(context, iteration: i);
      iterations.add(iteration);
    }

    final outcome = !iteration.hasCriticalIssues
        ? ReviewOutcome.approved
        : (i >= _budget.maxIterations
              ? ReviewOutcome.budgetExhausted
              : ReviewOutcome.refinementRequired);

    return ReviewResult(
      iterations: iterations,
      finalContext: context,
      outcome: outcome,
    );
  }

  ReviewContext _applyFixes(ReviewContext context, List<ReviewIssue> fixes) {
    final bindingEdges = List<BindingEdge>.from(
      context.engineering.bindingGraph.edges,
    );
    final dependencyEdges = List<DependencyEdge>.from(
      context.dependencyGraph.edges,
    );
    final bindingIndicesToRemove = <int>{};
    final dependencyIndicesToRemove = <int>{};
    final bindingPairsToRemove = <String>{};
    final dependencyPairsToRemove = <String>{};

    for (final issue in fixes) {
      final trailingIndex = int.tryParse(issue.id.split(':').last);
      if (issue.id.startsWith('engineering:duplicate:') &&
          trailingIndex != null) {
        bindingIndicesToRemove.add(trailingIndex);
      } else if (issue.id.startsWith('engineering:unused:') ||
          issue.id.startsWith('binding:dead:')) {
        bindingPairsToRemove.add(issue.evidence.affectedNodeId);
      } else if (issue.id.startsWith('dependency:redundant:') &&
          trailingIndex != null) {
        dependencyIndicesToRemove.add(trailingIndex);
      } else if (issue.id.startsWith('dependency:missing:')) {
        dependencyPairsToRemove.add(issue.evidence.affectedNodeId);
      }
    }

    final newBindingEdges = <BindingEdge>[
      for (var i = 0; i < bindingEdges.length; i++)
        if (!bindingIndicesToRemove.contains(i) &&
            !bindingPairsToRemove.contains(
              '${bindingEdges[i].fromId}->${bindingEdges[i].toId}',
            ))
          bindingEdges[i],
    ];
    final newDependencyEdges = <DependencyEdge>[
      for (var i = 0; i < dependencyEdges.length; i++)
        if (!dependencyIndicesToRemove.contains(i) &&
            !dependencyPairsToRemove.contains(
              '${dependencyEdges[i].fromId}->${dependencyEdges[i].toId}',
            ))
          dependencyEdges[i],
    ];

    final EngineeringCandidate newEngineeringCandidate = context.engineering
        .copyWith(bindingGraph: BindingGraph(edges: newBindingEdges));
    final oldPlan = context.solution.engineeringVariation.plan;
    final newPlan = EngineeringPlan(
      finalCandidate: newEngineeringCandidate,
      reviewHistory: oldPlan.reviewHistory,
      outcome: oldPlan.outcome,
    );
    final newDependencyGraph = DependencyGraph(
      nodes: context.dependencyGraph.nodes,
      edges: newDependencyEdges,
    );
    final old = context.solution;
    final newSolution = SolutionCandidate(
      id: old.id,
      label: old.label,
      architecture: old.architecture,
      architectureVariation: old.architectureVariation,
      engineeringVariation: EngineeringVariation(plan: newPlan),
      navigationVariation: old.navigationVariation,
      capabilityVariation: old.capabilityVariation,
      offlineVariation: old.offlineVariation,
      synchronizationVariation: old.synchronizationVariation,
      storageVariation: old.storageVariation,
      stateVariation: old.stateVariation,
      dependencies: newDependencyGraph,
      complexity: old.complexity,
      tradeoffs: old.tradeoffs,
      score: old.score,
      confidence: old.confidence,
      explanation: old.explanation,
    );

    return ReviewContext(
      app: context.app,
      requirements: context.requirements,
      featureGraph: context.featureGraph,
      dependencyGraph: newDependencyGraph,
      solution: newSolution,
      blueprint: context.blueprint,
    );
  }
}
