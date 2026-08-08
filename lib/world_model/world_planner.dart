/// WorldPlanner — Graph modifications must pass Review before they are
/// applied. GraphConsistency is the fail-closed gate applied here — the
/// same review-before-commit philosophy SCARE established, applied to
/// graph structure (SCARE's own DesignReviewEngine.review() is bound to
/// ReviewContext/ArchitectureCandidate and cannot be re-invoked directly
/// on a WorldGraph). When an update originates from an EvolutionProposal
/// or a ReviewSession finding, that artifact ALREADY passed SCARE before
/// reaching WorldPlanner — this is real reuse of that approval, not a
/// second review pass over the same decision.
library;

import 'graph_consistency.dart';
import 'graph_merge.dart';
import 'graph_update.dart';
import 'world_graph.dart';

class WorldPlanResult {
  final WorldGraph graph;
  final GraphMergeResult mergeResult;
  final GraphValidation validation;

  const WorldPlanResult({
    required this.graph,
    required this.mergeResult,
    required this.validation,
  });

  bool get approved => mergeResult.isClean && validation.isValid;
}

class WorldPlanner {
  final GraphMerge _merge;
  final GraphConsistency _consistency;

  const WorldPlanner({
    GraphMerge merge = const GraphMerge(),
    GraphConsistency consistency = const GraphConsistency(),
  }) : _merge = merge,
       _consistency = consistency;

  /// Plans applying [update] to [base]: merges it in, checks consistency,
  /// and only reports `approved` if both the merge was clean (no
  /// identity conflicts) and the resulting graph is structurally sound
  /// (no dangling edges). Never applies anything the caller doesn't then
  /// explicitly accept via [WorldPlanResult.graph] — planning and
  /// committing stay separate.
  WorldPlanResult plan(WorldGraph base, GraphUpdate update) {
    final incoming = WorldGraph(
      nodes: update.addedNodes,
      edges: update.addedEdges,
    );
    final mergeResult = _merge.merge(base, incoming);
    final validation = _consistency.validate(mergeResult.graph);
    return WorldPlanResult(
      graph: mergeResult.graph,
      mergeResult: mergeResult,
      validation: validation,
    );
  }
}
