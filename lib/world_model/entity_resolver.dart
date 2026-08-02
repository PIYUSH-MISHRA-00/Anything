/// EntityResolver — decides what identity a new thing should get before
/// it enters the World Graph: reuse an already-stable id when one
/// exists, or derive a deterministic structural fingerprint when it
/// doesn't. This is the single place that decision is made, so "no
/// duplicate identities" is enforced structurally rather than by
/// convention.
library;

import 'entity_identity.dart';
import 'world_types.dart';

class EntityResolver {
  const EntityResolver();

  /// [stableId] is provided for kinds that already have a real, stable
  /// id elsewhere in the codebase (capability ids, experience ids).
  /// [structuralSignature] is used otherwise — sorted, so field order
  /// never affects the resulting identity.
  EntityIdentity resolve(WorldNodeKind kind, {String? stableId, List<String> structuralSignature = const []}) {
    if (stableId != null && stableId.isNotEmpty) {
      return EntityIdentity.stable(kind, stableId);
    }
    return EntityIdentity.structural(kind, structuralSignature);
  }
}
