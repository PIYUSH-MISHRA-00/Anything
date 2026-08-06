/// KnowledgeGraphBridge — translates a real KnowledgeGraph (V1, built
/// fresh per Kernel call from package:webweavex-acquired resources) into
/// a GraphUpdate. A pure translation function: never a second knowledge
/// acquisition, extraction, or parsing implementation — those remain
/// exclusively package:webweavex's job via KnowledgeGraphBuilder.
///
/// Identity (Implementation Milestone R2): resolved from [sourceUri],
/// NOT [resourceId].
///
/// ORIGINAL R2 RATIONALE, NOW OBSOLETE — corrected by IS-R48, documentation
/// only, no behavior change. This paragraph used to state that
/// `KnowledgeResource.id` is assigned `'wwx-${microsecondsSinceEpoch}'` at
/// acquisition time — "a fresh value on every fetch, by design" — and that
/// using it as World Graph identity would therefore mint a brand-new node
/// for every re-acquisition. That was accurate when R2 was written, and it
/// stopped being true at IS-R47: resource identity is now derived from
/// WebWeaveX's `stableSerialize` over the identity-bearing fields, so the
/// same URL with the same normalized content yields the SAME id on every
/// acquisition and across restarts (IS-R48).
///
/// THE R2 DECISION STILL STANDS, on a stronger footing than before.
/// `sourceUri` remains the correct World Graph identity because it is the
/// "same knowledge resource" key even when the CONTENT legitimately changes
/// — a page edited between fetches now correctly produces a different
/// canonical id, and keying the graph on that id would still split one real
/// entity into two nodes. `sourceUri` is also the key already used for local
/// dedup (`KnowledgeAcquisitionEngine._deduplicate` keys on
/// `contentHash ?? sourceUri`); reusing it here means
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
