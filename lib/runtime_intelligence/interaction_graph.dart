/// InteractionGraph — the real, structural sequence of screens/entities
/// touched within ONE observed session, built directly from that
/// session's ObservationRecords. Mirrors DependencyGraph (V4) /
/// EvolutionGraph (V7)'s node/edge shape.
library;

import 'observation_record.dart';
import 'ril_types.dart';

enum InteractionRelation { followedBy }

class InteractionEdge {
  final String fromId;
  final String toId;
  final InteractionRelation relation;

  const InteractionEdge({
    required this.fromId,
    required this.toId,
    required this.relation,
  });
}

class InteractionGraph {
  final List<RilNode> nodes;
  final List<InteractionEdge> edges;

  const InteractionGraph({this.nodes = const [], this.edges = const []});

  RilNode? nodeById(String id) => nodes.where((n) => n.id == id).firstOrNull;

  List<InteractionEdge> edgesFrom(String id) =>
      edges.where((e) => e.fromId == id).toList();

  /// Builds the real followed-by chain of screens visited in this
  /// session, in observed order, de-duplicating consecutive repeats
  /// (e.g. two query updates on the same screen don't create a
  /// self-loop).
  factory InteractionGraph.fromRecords(List<ObservationRecord> records) {
    final screenSequence = records
        .where(
          (r) =>
              r.category == ObservationCategory.navigation &&
              r.screenId != null,
        )
        .map((r) => r.screenId!)
        .toList();

    final nodes = <RilNode>[];
    final seenIds = <String>{};
    for (final screenId in screenSequence) {
      if (seenIds.add(screenId)) {
        nodes.add(
          RilNode(id: screenId, kind: RilNodeKind.screen, label: screenId),
        );
      }
    }

    final edges = <InteractionEdge>[];
    for (var i = 1; i < screenSequence.length; i++) {
      final from = screenSequence[i - 1];
      final to = screenSequence[i];
      if (from == to) continue;
      edges.add(
        InteractionEdge(
          fromId: from,
          toId: to,
          relation: InteractionRelation.followedBy,
        ),
      );
    }

    return InteractionGraph(nodes: nodes, edges: edges);
  }
}
