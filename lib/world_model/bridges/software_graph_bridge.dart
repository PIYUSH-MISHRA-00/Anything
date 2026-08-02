/// SoftwareGraphBridge — translates a real SemanticSoftwareGraph (Vision
/// Milestone V11's Software Cognition subsystem) into a GraphUpdate, the
/// same pure-translation pattern every other Bridge follows (Knowledge/
/// Experience/Evolution/Runtime/Review, Vision Milestones V9-V10). Never
/// re-implements acquisition or analysis — it only maps
/// SoftwareNode/SoftwareEdge's already-computed shape onto WorldNode/
/// WorldEdge's vocabulary.
library;

import '../../software_cognition/semantic_software_graph.dart';
import '../../software_cognition/software_identity.dart' as sc;
import '../../software_cognition/software_types.dart' as sc;
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

WorldNodeKind _mapNodeKind(sc.SoftwareNodeKind kind) => switch (kind) {
  sc.SoftwareNodeKind.repository => WorldNodeKind.repository,
  sc.SoftwareNodeKind.package => WorldNodeKind.softwarePackage,
  sc.SoftwareNodeKind.library => WorldNodeKind.softwarePackage,
  sc.SoftwareNodeKind.entity => WorldNodeKind.entity,
  sc.SoftwareNodeKind.capability => WorldNodeKind.capability,
  sc.SoftwareNodeKind.file ||
  sc.SoftwareNodeKind.classType ||
  sc.SoftwareNodeKind.function ||
  sc.SoftwareNodeKind.widget ||
  sc.SoftwareNodeKind.component ||
  sc.SoftwareNodeKind.endpoint ||
  sc.SoftwareNodeKind.schema ||
  sc.SoftwareNodeKind.database ||
  sc.SoftwareNodeKind.architectureLayer => WorldNodeKind.softwareComponent,
};

RelationshipKind _mapEdgeKind(sc.SoftwareRelationshipKind kind) => switch (kind) {
  sc.SoftwareRelationshipKind.contains => RelationshipKind.contains,
  sc.SoftwareRelationshipKind.dependsOn => RelationshipKind.dependsOn,
  sc.SoftwareRelationshipKind.imports => RelationshipKind.dependsOn,
  sc.SoftwareRelationshipKind.calls => RelationshipKind.references,
  sc.SoftwareRelationshipKind.implements_ => RelationshipKind.extends_,
  sc.SoftwareRelationshipKind.exposes => RelationshipKind.produces,
  sc.SoftwareRelationshipKind.references => RelationshipKind.references,
  sc.SoftwareRelationshipKind.derivedFrom => RelationshipKind.derivedFrom,
  sc.SoftwareRelationshipKind.similarTo => RelationshipKind.relatesTo,
};

class SoftwareGraphBridge {
  final EntityResolver _resolver;

  const SoftwareGraphBridge({EntityResolver resolver = const EntityResolver()}) : _resolver = resolver;

  GraphUpdate bridge(SemanticSoftwareGraph graph) {
    final nodes = <WorldNode>[
      for (final node in graph.nodes)
        WorldNode(identity: _resolver.resolve(_mapNodeKind(node.kind), stableId: node.id), kind: _mapNodeKind(node.kind), label: node.label),
    ];

    final edges = <WorldEdge>[
      for (final edge in graph.edges)
        WorldEdge(
          fromId: _resolver.resolve(_mapNodeKind(_kindOf(graph, edge.fromId) ?? sc.SoftwareNodeKind.component), stableId: edge.fromId.value),
          toId: _resolver.resolve(_mapNodeKind(_kindOf(graph, edge.toId) ?? sc.SoftwareNodeKind.component), stableId: edge.toId.value),
          kind: _mapEdgeKind(edge.kind),
          evidence: GraphEvidence(sourceGraph: 'SoftwareCognition', sourceNodeId: edge.evidence.sourceArtifact),
        ),
    ];

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }

  sc.SoftwareNodeKind? _kindOf(SemanticSoftwareGraph graph, sc.SoftwareIdentity id) => graph.nodeById(id)?.kind;
}
