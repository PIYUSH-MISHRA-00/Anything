/// ReviewGraphBridge — translates a real Design Review (V6/SCARE)
/// ReviewSession into a GraphUpdate: every surviving finding becomes a
/// real `review` node related to the architecture element it concerns.
/// A pure translation — never a second review engine; SCARE remains the
/// only place review logic is implemented.
library;

import '../../design_review/review_history.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class ReviewGraphBridge {
  final EntityResolver _resolver;

  const ReviewGraphBridge({EntityResolver resolver = const EntityResolver()}) : _resolver = resolver;

  GraphUpdate bridge(ReviewSession session) {
    final nodes = <WorldNode>[];
    final edges = <WorldEdge>[];

    for (final issue in session.result.finalIteration.issues) {
      final issueIdentity = _resolver.resolve(WorldNodeKind.review, stableId: issue.id);
      nodes.add(WorldNode(identity: issueIdentity, kind: WorldNodeKind.review, label: issue.reason));

      final affectedNodeId = issue.evidence.affectedNodeId;
      if (affectedNodeId.isNotEmpty) {
        final affectedIdentity = _resolver.resolve(WorldNodeKind.entity, stableId: affectedNodeId);
        nodes.add(WorldNode(identity: affectedIdentity, kind: WorldNodeKind.entity, label: affectedNodeId));
        edges.add(
          WorldEdge(
            fromId: issueIdentity,
            toId: affectedIdentity,
            kind: RelationshipKind.relatesTo,
            evidence: GraphEvidence(sourceGraph: 'ReviewSession', sourceNodeId: issue.id),
            confidence: GraphConfidence(score: issue.confidence.score, reason: issue.confidence.reason),
          ),
        );
      }
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
