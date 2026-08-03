/// Architecture Diff — Implementation Milestone R4's second diff stage,
/// planning-only (no runtime patching; see `requirement_graph_diff.dart`
/// for the established scope statement, which applies identically here).
///
/// Mirrors `RequirementGraphDiffer`'s pattern exactly: list-shaped
/// decisions (entities/fields/relationships/capabilities/permissions) are
/// compared by their own real identity field, with a same-identity
/// content mismatch surfaced as an explicit remove+add pair, never a
/// silent overwrite. `ArchitectureCandidate`'s three singular decisions
/// (security/offline/synchronization) have no add/remove semantic — they
/// are represented as a real "before vs after" pair only when genuinely
/// different, never fabricated when unchanged.
library;

import 'architecture_candidate.dart';
import 'architecture_types.dart';

class ArchitectureDiff {
  final List<EntityDecision> addedEntities;
  final List<EntityDecision> removedEntities;
  final List<FieldDecision> addedFields;
  final List<FieldDecision> removedFields;
  final List<RelationshipDecision> addedRelationships;
  final List<RelationshipDecision> removedRelationships;
  final List<CapabilityDecision> addedCapabilities;
  final List<CapabilityDecision> removedCapabilities;
  final List<PermissionDecision> addedPermissions;
  final List<PermissionDecision> removedPermissions;
  final (SecurityDecision, SecurityDecision)? securityChange;
  final (OfflineDecision, OfflineDecision)? offlineChange;
  final (SynchronizationDecision, SynchronizationDecision)? synchronizationChange;

  const ArchitectureDiff({
    this.addedEntities = const [],
    this.removedEntities = const [],
    this.addedFields = const [],
    this.removedFields = const [],
    this.addedRelationships = const [],
    this.removedRelationships = const [],
    this.addedCapabilities = const [],
    this.removedCapabilities = const [],
    this.addedPermissions = const [],
    this.removedPermissions = const [],
    this.securityChange,
    this.offlineChange,
    this.synchronizationChange,
  });

  bool get isEmpty =>
      addedEntities.isEmpty &&
      removedEntities.isEmpty &&
      addedFields.isEmpty &&
      removedFields.isEmpty &&
      addedRelationships.isEmpty &&
      removedRelationships.isEmpty &&
      addedCapabilities.isEmpty &&
      removedCapabilities.isEmpty &&
      addedPermissions.isEmpty &&
      removedPermissions.isEmpty &&
      securityChange == null &&
      offlineChange == null &&
      synchronizationChange == null;

  static const ArchitectureDiff empty = ArchitectureDiff();
}

class ArchitectureDiffer {
  const ArchitectureDiffer();

  ArchitectureDiff diff(ArchitectureCandidate before, ArchitectureCandidate after) {
    final entityDiff = _diffById<EntityDecision, String>(
      before.entities,
      after.entities,
      (e) => e.entityId,
      (a, b) => a.name == b.name && a.storage == b.storage,
    );
    final fieldDiff = _diffById<FieldDecision, String>(
      before.fields,
      after.fields,
      (f) => '${f.entityId}.${f.fieldId}',
      (a, b) => a.name == b.name,
    );
    final relationshipDiff = _diffById<RelationshipDecision, String>(
      before.relationships,
      after.relationships,
      (r) => '${r.fromEntityId}->${r.toEntityId}.${r.fieldId}',
      (a, b) => a.deletePolicy == b.deletePolicy,
    );
    final capabilityDiff = _diffById<CapabilityDecision, String>(
      before.capabilities,
      after.capabilities,
      (c) => c.capabilityId,
      (a, b) => a.resolved == b.resolved,
    );
    final permissionDiff = _diffById<PermissionDecision, String>(
      before.permissions,
      after.permissions,
      (p) => '${p.permission}@${p.requiredByCapabilityId}',
      (a, b) => true,
    );

    return ArchitectureDiff(
      addedEntities: entityDiff.added,
      removedEntities: entityDiff.removed,
      addedFields: fieldDiff.added,
      removedFields: fieldDiff.removed,
      addedRelationships: relationshipDiff.added,
      removedRelationships: relationshipDiff.removed,
      addedCapabilities: capabilityDiff.added,
      removedCapabilities: capabilityDiff.removed,
      addedPermissions: permissionDiff.added,
      removedPermissions: permissionDiff.removed,
      securityChange:
          before.security.networkMode == after.security.networkMode &&
              before.security.requiresCredentialVault == after.security.requiresCredentialVault
          ? null
          : (before.security, after.security),
      offlineChange: before.offline.capability == after.offline.capability
          ? null
          : (before.offline, after.offline),
      synchronizationChange: before.synchronization.strategy == after.synchronization.strategy
          ? null
          : (before.synchronization, after.synchronization),
    );
  }

  /// Shared, real, id-keyed structural diff — the same "identity match +
  /// content mismatch = explicit remove+add" shape `RequirementGraphDiffer`
  /// already established, generalized to any decision type via a caller-
  /// supplied identity/equality function rather than duplicating the loop
  /// four times.
  ({List<T> added, List<T> removed}) _diffById<T, K>(
    List<T> before,
    List<T> after,
    K Function(T) idOf,
    bool Function(T, T) contentEquals,
  ) {
    final beforeById = {for (final item in before) idOf(item): item};
    final afterById = {for (final item in after) idOf(item): item};

    final added = <T>[];
    final removed = <T>[];

    for (final entry in afterById.entries) {
      final beforeItem = beforeById[entry.key];
      if (beforeItem == null) {
        added.add(entry.value);
      } else if (!contentEquals(beforeItem, entry.value)) {
        removed.add(beforeItem);
        added.add(entry.value);
      }
    }
    for (final entry in beforeById.entries) {
      if (!afterById.containsKey(entry.key)) {
        removed.add(entry.value);
      }
    }
    return (added: added, removed: removed);
  }
}
