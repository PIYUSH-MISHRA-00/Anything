/// Canonical Experience Specification for Anything.
///
/// Versioned, technology-independent specification of what an Experience requires.
library;

import '../../application_engineering/engineering_plan.dart';
import '../../core/contracts/intent.dart';

const int experienceSpecVersion = 1;

class ExperienceSpec {
  final int specVersion;
  final String id;
  final String name;
  final String description;
  final ExperienceCategory category;
  final InteractionModel interactionModel;
  final UIRequirements uiRequirements;
  final List<FunctionalRequirement> functionalRequirements;
  final StateRequirements stateRequirements;
  final StorageRequirements storageRequirements;
  final List<DataEntity> dataEntities;
  final List<ServiceRequirement> serviceRequirements;
  final NetworkRequirements networkRequirements;
  final List<PermissionRequirement> permissionRequirements;
  final BackendClassification backendClassification;
  final List<RequiredCapability> requiredCapabilities;
  final List<KnowledgeRequirement> knowledgeRequirements;
  final ProtectionRequirements protectionRequirements;
  final RuntimeRequirements runtimeRequirements;
  final QualityRequirements qualityRequirements;
  final AccessibilityRequirements accessibilityRequirements;
  final OfflineBehavior offlineBehavior;
  final IntentId? sourceIntentId;
  final DateTime createdAt;

  /// The Application Engineering Engine's output for this spec's blueprint
  /// (Vision Milestone V3). Null for callers/paths that predate engineering
  /// planning — every existing consumer of ExperienceSpec is unaffected.
  final EngineeringPlan? engineeringPlan;

  const ExperienceSpec({
    this.specVersion = experienceSpecVersion,
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.interactionModel,
    required this.uiRequirements,
    this.functionalRequirements = const [],
    required this.stateRequirements,
    required this.storageRequirements,
    this.dataEntities = const [],
    this.serviceRequirements = const [],
    required this.networkRequirements,
    this.permissionRequirements = const [],
    required this.backendClassification,
    this.requiredCapabilities = const [],
    this.knowledgeRequirements = const [],
    required this.protectionRequirements,
    required this.runtimeRequirements,
    required this.qualityRequirements,
    required this.accessibilityRequirements,
    required this.offlineBehavior,
    this.sourceIntentId,
    required this.createdAt,
    this.engineeringPlan,
  });
}

enum ExperienceCategory {
  tool,
  productivity,
  finance,
  health,
  creative,
  education,
  social,
  utility,
  entertainment,
  reference,
  unknown,
}

enum InteractionModel {
  directManipulation,
  formBased,
  conversational,
  dashboard,
  canvas,
  mixed,
}

class UIRequirements {
  final String description;
  final List<String> primaryViews;
  final List<String> inputElements;
  final List<String> displayElements;
  const UIRequirements({
    required this.description,
    this.primaryViews = const [],
    this.inputElements = const [],
    this.displayElements = const [],
  });
}

class FunctionalRequirement {
  final String id;
  final String description;
  final List<String> acceptanceCriteria;
  const FunctionalRequirement({
    required this.id,
    required this.description,
    this.acceptanceCriteria = const [],
  });
}

class StateRequirements {
  final String description;
  final bool requiresEphemeralState;
  final bool requiresPersistentState;
  final List<String> stateEntities;
  const StateRequirements({
    required this.description,
    this.requiresEphemeralState = true,
    this.requiresPersistentState = false,
    this.stateEntities = const [],
  });
}

enum StorageType { none, ephemeral, localKey, localDatabase, localFile }

class DataEntity {
  final String name;
  final String description;
  const DataEntity({required this.name, required this.description});
}

class StorageRequirements {
  final String description;
  final StorageType storageType;
  final bool requiresDatabase;
  final bool requiresFileSystem;
  const StorageRequirements({
    required this.description,
    this.storageType = StorageType.none,
    this.requiresDatabase = false,
    this.requiresFileSystem = false,
  });
}

enum ServiceType { clock, localDatabase, httpClient, notifications, fileAccess }

class ServiceRequirement {
  final String id;
  final String description;
  final ServiceType type;
  const ServiceRequirement({
    required this.id,
    required this.description,
    required this.type,
  });
}

enum NetworkNeed { none, optional, required, conditional }

class NetworkRequirements {
  final NetworkNeed networkNeed;
  final String? description;
  const NetworkRequirements({required this.networkNeed, this.description});
}

class KnowledgeRequirement {
  final String objective;
  final String resourceType;
  final List<String> queryHints;
  final bool networkRequired;
  const KnowledgeRequirement({
    required this.objective,
    required this.resourceType,
    this.queryHints = const [],
    this.networkRequired = true,
  });
}

class PermissionRequirement {
  final String permission;
  final String reason;
  const PermissionRequirement({required this.permission, required this.reason});
}

enum BackendClassification { none, localService, localDatabase, externalApi }

class RequiredCapability {
  final String capabilityId;
  final bool isRequired;
  const RequiredCapability({
    required this.capabilityId,
    this.isRequired = true,
  });
}

class ProtectionRequirements {
  final bool requiresEncryption;
  final bool requiresLocalOnly;
  const ProtectionRequirements({
    this.requiresEncryption = false,
    this.requiresLocalOnly = true,
  });
}

class RuntimeRequirements {
  final bool requiresBackgroundExecution;
  const RuntimeRequirements({this.requiresBackgroundExecution = false});
}

class QualityRequirements {
  final bool requiresOfflineSupport;
  final bool requiresResponsiveDesign;
  final bool requiresAccessibility;
  const QualityRequirements({
    this.requiresOfflineSupport = true,
    this.requiresResponsiveDesign = true,
    this.requiresAccessibility = true,
  });
}

class AccessibilityRequirements {
  final bool requiresScreenReader;
  final bool requiresSemanticLabels;
  const AccessibilityRequirements({
    this.requiresScreenReader = true,
    this.requiresSemanticLabels = true,
  });
}

enum OfflineCapability { fullyOffline, mostlyOffline, requiresNetwork, hybrid }

class OfflineBehavior {
  final OfflineCapability offlineCapability;
  final String? description;
  const OfflineBehavior({required this.offlineCapability, this.description});
}
