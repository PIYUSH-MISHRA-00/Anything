/// Backend Storage Model — Implementation Milestone R8. Real, typed
/// summary of `EntityDecision.storage`'s already-computed `StorageKind`
/// distribution (ArchitectureCandidate, Vision Milestone V2) — never a
/// re-decision of where data should live, only a backend-facing
/// restatement of what Architecture Planning already decided.
library;

import '../software_architect/architecture_types.dart' show StorageKind;

class StorageRequirement {
  final String entityId;
  final StorageKind kind;

  const StorageRequirement({required this.entityId, required this.kind});
}

class BackendStorageModel {
  final List<StorageRequirement> requirements;

  const BackendStorageModel({this.requirements = const []});

  static const empty = BackendStorageModel();

  bool get isEmpty => requirements.isEmpty;

  /// Whether any entity's storage decision implies real file/object
  /// storage (as opposed to structured record storage) — the one real,
  /// checkable signal available for "does this app need file storage."
  bool get requiresFileStorage =>
      requirements.any((r) => r.kind == StorageKind.file);
}
