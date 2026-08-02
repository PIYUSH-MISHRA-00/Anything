/// EntityIdentity — stable, persistent, cross-session, cross-experience
/// identity for anything in the World Graph. Never a random UUID: every
/// identity is either (a) reused directly from an already-stable id that
/// exists elsewhere in the codebase (a capability id, an experience id),
/// or (b) a deterministic structural fingerprint built from sorted,
/// typed signature parts — the same "same structure -> same id" pattern
/// already used by ReviewMemory/EvolutionMemory's fingerprinting and
/// RIL's ExperienceFingerprint (V8), never a hash function whose
/// stability isn't guaranteed across Dart versions.
library;

import 'world_types.dart';

class EntityIdentity {
  final String value;

  const EntityIdentity._(this.value);

  /// Reuses an already-stable id that exists elsewhere (a capability id
  /// from CapabilityDescriptor, an experience id from
  /// ExperienceMetadataRecord) — never re-derived, never duplicated.
  factory EntityIdentity.stable(WorldNodeKind kind, String id) => EntityIdentity._('${kind.name}:$id');

  /// Builds a deterministic structural fingerprint for something with no
  /// existing stable id (an entity shape, a workflow, a recommendation).
  /// Two structurally-identical things — regardless of which Experience
  /// or session produced them — always resolve to the exact same
  /// identity, satisfying "no duplicate identities" without a database.
  factory EntityIdentity.structural(WorldNodeKind kind, List<String> signature) {
    final sorted = [...signature]..sort();
    return EntityIdentity._('${kind.name}:${sorted.join(',')}');
  }

  @override
  bool operator ==(Object other) => other is EntityIdentity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A lightweight, typed pointer to an entity — used when one part of the
/// system needs to reference an entity without holding its full node.
class EntityReference {
  final EntityIdentity identity;
  final WorldNodeKind kind;
  final String label;

  const EntityReference({required this.identity, required this.kind, required this.label});
}
