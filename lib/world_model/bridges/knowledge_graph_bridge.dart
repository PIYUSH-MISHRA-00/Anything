/// KnowledgeGraphBridge — translates a real KnowledgeGraph (V1, built
/// fresh per Kernel call from package:webweavex-acquired resources) into
/// a GraphUpdate. A pure translation function: never a second knowledge
/// acquisition, extraction, or parsing implementation — those remain
/// exclusively package:webweavex's job via KnowledgeGraphBuilder.
library;

import '../../software_architect/knowledge_graph.dart';
import '../entity_identity.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class KnowledgeGraphBridge {
  final EntityResolver _resolver;

  const KnowledgeGraphBridge({EntityResolver resolver = const EntityResolver()}) : _resolver = resolver;

  GraphUpdate bridge(KnowledgeGraph knowledgeGraph) {
    final identities = <String, EntityIdentity>{};
    final nodes = knowledgeGraph.nodes.map((resource) {
      final identity = _resolver.resolve(WorldNodeKind.knowledge, stableId: resource.resourceId);
      identities[resource.resourceId] = identity;
      return WorldNode(identity: identity, kind: WorldNodeKind.knowledge, label: resource.title);
    }).toList();

    final edges = knowledgeGraph.links
        .where((link) => identities.containsKey(link.fromResourceId) && identities.containsKey(link.toResourceId))
        .map(
          (link) => WorldEdge(
            fromId: identities[link.fromResourceId]!,
            toId: identities[link.toResourceId]!,
            kind: RelationshipKind.relatesTo,
            evidence: GraphEvidence(sourceGraph: 'KnowledgeGraph', sourceNodeId: '${link.fromResourceId}->${link.toResourceId}'),
          ),
        )
        .toList();

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
