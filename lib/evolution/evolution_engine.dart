/// EvolutionEngine — the top-level Autonomous Evolution orchestrator:
/// Observe -> Estimate -> Review -> Approve -> Plan -> Predict, mirroring
/// DesignReviewEngine's (V6) role as the single Kernel-facing facade over
/// everything else in this package.
///
/// Runs exactly one real iteration today: EvolutionObserver's output is a
/// pure function of an unchanged EvolutionContext, so a second pass over
/// the same context would be identical — there is nothing here to "fix
/// and re-detect" the way ReviewRefinement fixes binding edges. The
/// EvolutionCycle/EvolutionIteration/EvolutionBudget structure mirrors
/// ReviewRefinement's proven, terminating-by-construction shape and
/// leaves room for a future milestone where accepting one candidate
/// could itself surface new derived opportunities — documented honestly
/// as a single pass today, not fabricated as iterative.
library;

import 'evolution_approver.dart';
import 'evolution_budget.dart';
import 'evolution_context.dart';
import 'evolution_estimator.dart';
import 'evolution_graph.dart';
import 'evolution_history.dart';
import 'evolution_memory.dart';
import 'evolution_observer.dart';
import 'evolution_planner.dart';
import 'evolution_prediction.dart';
import 'evolution_result.dart';
import 'evolution_reviewer.dart';

class EvolutionEngine {
  final EvolutionObserver _observer;
  final EvolutionEstimator _estimator;
  final EvolutionReviewer _reviewer;
  final EvolutionApprover _approver;
  final EvolutionPlanner _planner;
  final EvolutionGraphBuilder _graphBuilder;
  final EvolutionBudget _budget;

  const EvolutionEngine({
    EvolutionObserver observer = const EvolutionObserver(),
    EvolutionEstimator estimator = const EvolutionEstimator(),
    EvolutionReviewer reviewer = const EvolutionReviewer(),
    EvolutionApprover approver = const EvolutionApprover(),
    EvolutionPlanner planner = const EvolutionPlanner(),
    EvolutionGraphBuilder graphBuilder = const EvolutionGraphBuilder(),
    EvolutionBudget budget = const EvolutionBudget(),
  }) : _observer = observer,
       _estimator = estimator,
       _reviewer = reviewer,
       _approver = approver,
       _planner = planner,
       _graphBuilder = graphBuilder,
       _budget = budget;

  EvolutionResult evolve(EvolutionContext context, {EvolutionMemory? memory, EvolutionHistory? history}) {
    final fingerprint = fingerprintOf(context);

    final opportunities = _observer.observe(context).take(_budget.maxOpportunitiesPerIteration).toList();
    final candidates = opportunities.map(_estimator.estimate).toList();
    final decisions = candidates.map((c) => _reviewer.review(c, context)).toList();

    final iteration = EvolutionIteration(
      index: 0,
      opportunities: opportunities,
      candidates: candidates,
      decisions: decisions,
    );
    final outcome = opportunities.isEmpty ? EvolutionOutcome.noOpportunities : EvolutionOutcome.planned;
    final cycle = EvolutionCycle(iterations: [iteration], outcome: outcome);

    final acceptedProposals = _approver.approveForRoadmap(candidates, decisions);
    final roadmap = _planner.plan(
      fingerprint: fingerprint,
      reviewedProposals: acceptedProposals,
      context: context,
      budget: _budget,
    );
    final prediction = EvolutionPrediction.derive(context, roadmap);
    final graph = _graphBuilder.build(candidates);

    final result = EvolutionResult(cycle: cycle, roadmap: roadmap, prediction: prediction, graph: graph);
    memory?.record(result);
    history?.record(result);
    return result;
  }

  /// A deterministic structural fingerprint — entity ids, capability ids,
  /// and screen count, sorted for stability — mirroring
  /// DesignReviewEngine.fingerprintOf exactly, never a domain name.
  String fingerprintOf(EvolutionContext context) {
    final entityIds = context.architecture.entities.map((e) => e.entityId).toList()..sort();
    final capabilityIds = context.architecture.capabilities.map((c) => c.capabilityId).toList()..sort();
    return '${entityIds.join(',')}|${capabilityIds.join(',')}|${context.blueprint.views.length}';
  }
}
