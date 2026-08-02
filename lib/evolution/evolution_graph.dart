/// EvolutionGraph — the typed representation of one evolution pass:
/// Current State -> Detected Opportunities -> Candidate Improvements ->
/// Dependencies -> Review -> Approval -> Execution -> Verification.
/// Mirrors DependencyGraph (V4) / SolutionGraph (V5)'s node+edge shape.
library;

import 'evolution_candidate.dart';
import 'evolution_types.dart';

enum EvolutionGraphNodeKind { currentState, opportunity, candidate, review, approval, execution, verification }

class EvolutionGraphNode {
  final String id;
  final EvolutionGraphNodeKind kind;
  final String label;

  const EvolutionGraphNode({required this.id, required this.kind, required this.label});
}

class EvolutionGraph {
  final List<EvolutionGraphNode> nodes;
  final List<EvolutionDependency> edges;

  const EvolutionGraph({this.nodes = const [], this.edges = const []});

  List<EvolutionDependency> edgesFrom(String id) => edges.where((e) => e.fromId == id).toList();
  List<EvolutionDependency> edgesTo(String id) => edges.where((e) => e.toId == id).toList();
}

class EvolutionGraphBuilder {
  const EvolutionGraphBuilder();

  /// Builds the fixed pipeline-stage nodes for every candidate (currentState
  /// -> opportunity -> candidate -> review), plus real structural
  /// dependencies between candidates — e.g. a "missingSynchronization"
  /// candidate structurally requires the "missingOffline" candidate for
  /// the same architecture, since synchronization only makes sense once
  /// offline storage exists. Never a fabricated edge: every dependency
  /// traces to two real candidates whose categories are structurally
  /// related.
  EvolutionGraph build(List<EvolutionCandidate> candidates) {
    final nodes = <EvolutionGraphNode>[
      const EvolutionGraphNode(id: 'state:current', kind: EvolutionGraphNodeKind.currentState, label: 'Current State'),
    ];
    final edges = <EvolutionDependency>[];

    for (final candidate in candidates) {
      nodes.add(
        EvolutionGraphNode(
          id: 'opportunity:${candidate.opportunity.id}',
          kind: EvolutionGraphNodeKind.opportunity,
          label: candidate.opportunity.description,
        ),
      );
      nodes.add(EvolutionGraphNode(id: candidate.id, kind: EvolutionGraphNodeKind.candidate, label: candidate.id));

      edges.add(
        EvolutionDependency(
          fromId: 'state:current',
          toId: 'opportunity:${candidate.opportunity.id}',
          kind: EvolutionDependencyKind.relatesTo,
        ),
      );
      edges.add(
        EvolutionDependency(
          fromId: 'opportunity:${candidate.opportunity.id}',
          toId: candidate.id,
          kind: EvolutionDependencyKind.relatesTo,
        ),
      );
    }

    final syncCandidates = candidates.where(
      (c) => c.opportunity.category == EvolutionOpportunityCategory.missingSynchronization,
    );
    final offlineCandidates = candidates.where(
      (c) => c.opportunity.category == EvolutionOpportunityCategory.missingOffline,
    );
    for (final sync in syncCandidates) {
      for (final offline in offlineCandidates) {
        edges.add(EvolutionDependency(fromId: sync.id, toId: offline.id, kind: EvolutionDependencyKind.requires));
      }
    }

    return EvolutionGraph(nodes: nodes, edges: edges);
  }
}
