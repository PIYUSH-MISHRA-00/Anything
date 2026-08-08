/// RelationshipIdentity — stable identity for an edge, deterministically
/// derived from its endpoints and kind, mirroring EntityIdentity's
/// "structure determines identity" discipline.
library;

import 'entity_identity.dart';
import 'world_types.dart';

class RelationshipIdentity {
  final String value;

  const RelationshipIdentity._(this.value);

  factory RelationshipIdentity.of(
    EntityIdentity from,
    EntityIdentity to,
    RelationshipKind kind,
  ) => RelationshipIdentity._('${from.value}--${kind.name}-->${to.value}');

  @override
  bool operator ==(Object other) =>
      other is RelationshipIdentity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A lightweight, typed pointer to a relationship.
class RelationshipReference {
  final RelationshipIdentity identity;
  final EntityIdentity from;
  final EntityIdentity to;
  final RelationshipKind kind;

  const RelationshipReference({
    required this.identity,
    required this.from,
    required this.to,
    required this.kind,
  });
}
