/// WorldEdge — a typed relationship between two WorldNodes, always
/// carrying real evidence and confidence — never a fabricated
/// connection.
library;

import 'entity_identity.dart';
import 'relationship_identity.dart';
import 'world_types.dart';

class WorldEdge {
  final EntityIdentity fromId;
  final EntityIdentity toId;
  final RelationshipKind kind;
  final GraphEvidence evidence;
  final GraphConfidence confidence;

  const WorldEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
    required this.evidence,
    this.confidence = GraphConfidence.full,
  });

  RelationshipIdentity get identity => RelationshipIdentity.of(fromId, toId, kind);
}
