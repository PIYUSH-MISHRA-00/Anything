/// Experience Modification Spec — represents a request to modify an existing Experience.
library;

/// A request to modify an existing Experience.
class ExperienceModificationSpec {
  final String targetExperienceId;
  final String basePackageVersion;
  final String objective;
  final List<ModificationOperation> operations;
  final List<String> requiredCapabilities;
  final List<String> requiredPermissions;
  final Map<String, dynamic> params;

  const ExperienceModificationSpec({
    required this.targetExperienceId,
    required this.basePackageVersion,
    required this.objective,
    required this.operations,
    this.requiredCapabilities = const [],
    this.requiredPermissions = const [],
    this.params = const {},
  });
}

/// A single modification operation.
class ModificationOperation {
  final ModificationType type;
  final Map<String, dynamic> params;

  const ModificationOperation({required this.type, required this.params});
}

/// Types of modifications.
enum ModificationType {
  addUiNode,
  modifyUiNode,
  removeUiNode,
  addBehavior,
  modifyBehavior,
  removeBehavior,
  addState,
  modifySchema,
  addEntity,
  addService,
  addCapability,
  addPermission,
  updateMetadata,

  /// Add a live WebWeaveX "Discover" browse surface to a records app —
  /// applied by [ExperienceModificationCoordinator] via
  /// `NetworkReferenceInterfaceFactory.composeDiscoverTab`, NOT by
  /// [ModificationEngine] (it spans services + capability declarations the
  /// engine's per-slice ops don't touch). `params['subject']` names what to
  /// browse (e.g. "trains"). No-op on apps without entities.
  addWebBrowse,
}
