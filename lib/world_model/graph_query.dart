/// GraphQuery — a typed query specification, the target of
/// "Natural language -> Semantic Query -> Graph Traversal -> Typed
/// Results." Never free text at this layer: SemanticQueryEngine's own
/// minimal, honestly-scoped structural parser is the only place a raw
/// expression is ever accepted.
library;

import 'entity_identity.dart';
import 'world_types.dart';

enum GraphQueryDirection { forward, reverse, both }

class GraphQuery {
  final EntityIdentity startId;
  final Set<RelationshipKind>? relationKinds;
  final GraphQueryDirection direction;
  final int maxDepth;

  const GraphQuery({
    required this.startId,
    this.relationKinds,
    this.direction = GraphQueryDirection.forward,
    this.maxDepth = 5,
  });
}
