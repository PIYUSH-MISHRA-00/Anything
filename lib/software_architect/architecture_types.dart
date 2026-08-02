/// Architecture Types — the typed vocabulary ArchitecturePlanner and its
/// sub-planners assemble into an ArchitectureCandidate. No Maps, no
/// dynamic, no JSON blobs — every planning output is a real class.
library;

import 'confidence.dart';

// ── Data / entity / field / relationship ────────────────────────────────

enum StorageKind {
  memory,
  sqlite,
  file,
  credentialVault,
  temporary,
  persistentCache,
  generatedCache,
}

class EntityDecision {
  final String entityId;
  final String name;
  final int fieldCount;
  final StorageKind storage;
  final ArchitectureDecision storageDecision;

  const EntityDecision({
    required this.entityId,
    required this.name,
    required this.fieldCount,
    required this.storage,
    required this.storageDecision,
  });
}

class FieldDecision {
  final String entityId;
  final String fieldId;
  final String name;
  final ArchitectureDecision validationDecision;

  const FieldDecision({
    required this.entityId,
    required this.fieldId,
    required this.name,
    required this.validationDecision,
  });
}

enum RelationshipDeletePolicy { restrict, setNull }

class RelationshipDecision {
  final String fromEntityId;
  final String toEntityId;
  final String fieldId;
  final RelationshipDeletePolicy deletePolicy;
  final ArchitectureDecision decision;

  const RelationshipDecision({
    required this.fromEntityId,
    required this.toEntityId,
    required this.fieldId,
    required this.deletePolicy,
    required this.decision,
  });
}

// ── State ────────────────────────────────────────────────────────────────

enum StateKind { local, shared, persistent, derived, computed, reactive }

class StateDecision {
  final String stateId;
  final StateKind kind;
  final ArchitectureDecision decision;

  const StateDecision({
    required this.stateId,
    required this.kind,
    required this.decision,
  });
}

// ── Navigation ───────────────────────────────────────────────────────────

class NavigationEdge {
  final String fromScreenId;
  final String toScreenId;
  final String trigger;
  final bool isModal;

  const NavigationEdge({
    required this.fromScreenId,
    required this.toScreenId,
    required this.trigger,
    this.isModal = false,
  });
}

class NavigationGraph {
  final String entryScreenId;
  final List<String> screenIds;
  final List<NavigationEdge> edges;
  final ArchitectureDecision decision;

  const NavigationGraph({
    required this.entryScreenId,
    required this.screenIds,
    required this.edges,
    required this.decision,
  });
}

// ── Interaction ──────────────────────────────────────────────────────────

class InteractionDecision {
  final String entityId;
  final bool canCreate;
  final bool canRead;
  final bool canUpdate;
  final bool canDelete;
  final bool supportsSearch;
  final bool supportsFilter;
  final bool supportsSort;
  final bool supportsPagination;
  final ArchitectureDecision decision;

  const InteractionDecision({
    required this.entityId,
    required this.canCreate,
    required this.canRead,
    required this.canUpdate,
    required this.canDelete,
    required this.supportsSearch,
    required this.supportsFilter,
    required this.supportsSort,
    required this.supportsPagination,
    required this.decision,
  });
}

// ── Capability / permission ──────────────────────────────────────────────

class CapabilityDecision {
  final String capabilityId;
  final bool resolved;
  final ArchitectureDecision decision;

  const CapabilityDecision({
    required this.capabilityId,
    required this.resolved,
    required this.decision,
  });
}

class PermissionDecision {
  final String permission;
  final String requiredByCapabilityId;
  final ArchitectureDecision decision;

  const PermissionDecision({
    required this.permission,
    required this.requiredByCapabilityId,
    required this.decision,
  });
}

// ── Security / offline / sync ───────────────────────────────────────────

enum NetworkMode { none, restrictedHttps }

class SecurityDecision {
  final NetworkMode networkMode;
  final bool requiresCredentialVault;
  final ArchitectureDecision decision;

  const SecurityDecision({
    required this.networkMode,
    required this.requiresCredentialVault,
    required this.decision,
  });
}

enum OfflineCapability { fullyOffline, cacheThenOnline, onlineRequired }

class OfflineDecision {
  final OfflineCapability capability;
  final ArchitectureDecision decision;

  const OfflineDecision({required this.capability, required this.decision});
}

enum SyncStrategy { none, manualRefresh, cacheFirst, networkFirst }

class SynchronizationDecision {
  final SyncStrategy strategy;
  final ArchitectureDecision decision;

  const SynchronizationDecision({
    required this.strategy,
    required this.decision,
  });
}

// ── Validation ───────────────────────────────────────────────────────────

enum ValidationRuleType {
  required,
  minLength,
  maxLength,
  minimum,
  maximum,
  allowedValues,
  crossField,
}

class ValidationRule {
  final String entityId;
  final String fieldId;
  final ValidationRuleType type;
  final String description;

  const ValidationRule({
    required this.entityId,
    required this.fieldId,
    required this.type,
    required this.description,
  });
}
