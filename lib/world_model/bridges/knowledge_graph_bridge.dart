/// KnowledgeGraphBridge — translates a real KnowledgeGraph (V1, built
/// fresh per Kernel call from package:webweavex-acquired resources) into
/// a GraphUpdate. A pure translation function: never a second knowledge
/// acquisition, extraction, or parsing implementation — those remain
/// exclusively package:webweavex's job via KnowledgeGraphBuilder.
///
/// Identity (Implementation Milestone R2): resolved from [sourceUri],
/// NOT [resourceId]. REALITY: `KnowledgeResource.id` (the origin of
/// `resourceId`) is assigned `'wwx-${microsecondsSinceEpoch}'` at
/// acquisition time (`webweavex_adapter.dart`) — a fresh value on every
/// fetch, by design, since it identifies the acquisition event, not the
/// resource. Using it as the World Graph identity would mean the SAME
/// URL, re-acquired later, always mints a brand-new node — the opposite
/// of R2's "repeated acquisition must not duplicate nodes" requirement.
/// `sourceUri` is the real, stable "same knowledge resource" key
/// already used for local dedup (`KnowledgeAcquisitionEngine._deduplicate`
/// keys on `contentHash ?? sourceUri`); reusing it here means
/// `GraphMerge`'s existing identity-based dedup (identical
/// identity+kind+label -> clean no-op merge, re-verified this milestone)
/// correctly recognizes a re-fetch of the same URL as the SAME node. If
/// the title changed since the last acquisition, `GraphMerge` correctly
/// surfaces a real `GraphConflict` instead of silently duplicating or
/// silently overwriting — see Known Limitations in the R2 report for the
/// honest scope of what happens next (the existing, unmodified
/// `WorldPlanner` all-or-nothing gate, not something this milestone
/// changes).
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
      final identity = _resolver.resolve(WorldNodeKind.knowledge, stableId: resource.sourceUri);
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
