/// SemanticEntity — a structural "kind of thing" recognized across
/// Experiences (e.g. a Person-shaped entity), never data. Identity comes
/// from EntityResolver's structural fingerprint, so two Experiences with
/// the same entity shape resolve to the same SemanticEntity.
library;

import 'entity_identity.dart';
import 'world_types.dart';

class SemanticEntity {
  final EntityIdentity identity;
  final String name;
  final List<String> fieldTypeNames;

  const SemanticEntity({required this.identity, required this.name, this.fieldTypeNames = const []});
}

class SemanticRelationship {
  final EntityIdentity fromId;
  final EntityIdentity toId;
  final RelationshipKind kind;

  const SemanticRelationship({required this.fromId, required this.toId, required this.kind});
}
