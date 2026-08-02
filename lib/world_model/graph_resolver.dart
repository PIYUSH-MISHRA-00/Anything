/// GraphResolver — resolves a reference against a real WorldGraph,
/// distinct from EntityResolver (which decides what identity a NEW thing
/// should get before insertion). GraphResolver only ever looks up
/// something that should already be there.
library;

import 'entity_identity.dart';
import 'world_edge.dart';
import 'world_graph.dart';
import 'world_node.dart';

class GraphResolver {
  final WorldGraph graph;

  const GraphResolver(this.graph);

  WorldNode? resolveEntity(EntityIdentity identity) => graph.nodeById(identity);

  bool exists(EntityIdentity identity) => resolveEntity(identity) != null;

  List<WorldEdge> resolveRelationships(EntityIdentity identity) => [...graph.edgesFrom(identity), ...graph.edgesTo(identity)];
}
