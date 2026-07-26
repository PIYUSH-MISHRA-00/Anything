/// Blueprint to ExperienceSpec converter.
///
/// Converts an AppBlueprint into an ExperienceSpec that the CreationEngine
/// can consume. This bridges the semantic synthesis layer with the
/// existing creation pipeline.
library;

import '../kernel/specification/experience_spec.dart';
import 'app_archetype.dart';
import 'app_blueprint.dart';

/// Converts an AppBlueprint into an ExperienceSpec.
class BlueprintToSpecConverter {
  /// Convert a validated AppBlueprint into an ExperienceSpec.
  static ExperienceSpec convert(AppBlueprint blueprint) {
    return ExperienceSpec(
      id: blueprint.id,
      name: blueprint.name,
      description: blueprint.description,
      category: _mapDomainToCategory(blueprint.domain),
      interactionModel: _deriveInteractionModel(blueprint),
      uiRequirements: _deriveUIRequirements(blueprint),
      functionalRequirements: _deriveFunctionalRequirements(blueprint),
      stateRequirements: _deriveStateRequirements(blueprint),
      storageRequirements: _deriveStorageRequirements(blueprint),
      dataEntities: _deriveDataEntities(blueprint),
      serviceRequirements: _deriveServiceRequirements(blueprint),
      networkRequirements: _deriveNetworkRequirements(blueprint),
      permissionRequirements: _derivePermissionRequirements(blueprint),
      backendClassification: _deriveBackendClassification(blueprint),
      requiredCapabilities: _deriveRequiredCapabilities(blueprint),
      protectionRequirements: const ProtectionRequirements(),
      runtimeRequirements: const RuntimeRequirements(),
      qualityRequirements: const QualityRequirements(),
      accessibilityRequirements: const AccessibilityRequirements(),
      offlineBehavior: _deriveOfflineBehavior(blueprint),
      createdAt: DateTime.now(),
    );
  }

  static ExperienceCategory _mapDomainToCategory(AppDomain domain) {
    switch (domain) {
      case AppDomain.notes:
        return ExperienceCategory.productivity;
      case AppDomain.habits:
        return ExperienceCategory.health;
      case AppDomain.finances:
        return ExperienceCategory.finance;
      case AppDomain.education:
        return ExperienceCategory.education;
      case AppDomain.reading:
        return ExperienceCategory.reference;
      case AppDomain.weather:
        return ExperienceCategory.utility;
      case AppDomain.health:
        return ExperienceCategory.health;
      case AppDomain.productivity:
        return ExperienceCategory.productivity;
      case AppDomain.reference:
        return ExperienceCategory.reference;
      case AppDomain.entertainment:
        return ExperienceCategory.entertainment;
      case AppDomain.custom:
        return ExperienceCategory.unknown;
    }
  }

  static InteractionModel _deriveInteractionModel(AppBlueprint blueprint) {
    if (blueprint.archetypes.contains(AppArchetype.utility)) {
      return InteractionModel.directManipulation;
    }
    if (blueprint.archetypes.contains(AppArchetype.dashboard)) {
      return InteractionModel.dashboard;
    }
    return InteractionModel.formBased;
  }

  static UIRequirements _deriveUIRequirements(AppBlueprint blueprint) {
    final primaryViews = blueprint.views.map((v) => v.name).toList();
    final inputElements = <String>[];
    for (final entity in blueprint.entities) {
      for (final field in entity.fields) {
        if (field.type != BlueprintFieldType.reference) {
          inputElements.add(field.name);
        }
      }
    }
    return UIRequirements(
      description: '${blueprint.name} interface',
      primaryViews: primaryViews,
      inputElements: inputElements,
      displayElements: blueprint.entities.map((e) => e.name).toList(),
    );
  }

  static List<FunctionalRequirement> _deriveFunctionalRequirements(
    AppBlueprint blueprint,
  ) {
    return blueprint.actions.map((action) {
      return FunctionalRequirement(
        id: action.id,
        description: action.name,
        acceptanceCriteria: [
          if (action.actionType == BlueprintActionType.create)
            'Creates a new ${action.targetEntityId}',
          if (action.actionType == BlueprintActionType.update)
            'Updates existing ${action.targetEntityId}',
          if (action.actionType == BlueprintActionType.delete)
            'Deletes ${action.targetEntityId}',
          if (action.actionType == BlueprintActionType.toggle)
            'Toggles ${action.targetEntityId} state',
        ],
      );
    }).toList();
  }

  static StateRequirements _deriveStateRequirements(AppBlueprint blueprint) {
    final stateEntities = <String>[];
    for (final entity in blueprint.entities) {
      stateEntities.add(entity.id);
    }
    return StateRequirements(
      description: 'State for ${blueprint.name}',
      requiresEphemeralState: true,
      requiresPersistentState: blueprint.entities.isNotEmpty,
      stateEntities: stateEntities,
    );
  }

  static StorageRequirements _deriveStorageRequirements(
    AppBlueprint blueprint,
  ) {
    final hasEntities = blueprint.entities.isNotEmpty;
    return StorageRequirements(
      description: hasEntities
          ? 'Local database for ${blueprint.name}'
          : 'No storage required',
      storageType: hasEntities
          ? StorageType.localDatabase
          : StorageType.ephemeral,
      requiresDatabase: hasEntities,
    );
  }

  static List<DataEntity> _deriveDataEntities(AppBlueprint blueprint) {
    return blueprint.entities.map((entity) {
      return DataEntity(
        name: entity.name,
        description: 'Entity: ${entity.name}',
      );
    }).toList();
  }

  static List<ServiceRequirement> _deriveServiceRequirements(
    AppBlueprint blueprint,
  ) {
    final services = <ServiceRequirement>[];
    if (blueprint.entities.isNotEmpty) {
      services.add(
        ServiceRequirement(
          id: 'localDatabase',
          description: 'Local SQLite database',
          type: ServiceType.localDatabase,
        ),
      );
    }
    return services;
  }

  static NetworkRequirements _deriveNetworkRequirements(
    AppBlueprint blueprint,
  ) {
    if (blueprint.networkConfig != null) {
      return NetworkRequirements(
        networkNeed: NetworkNeed.required,
        description: blueprint.networkConfig!.purpose,
      );
    }
    return NetworkRequirements(
      networkNeed: NetworkNeed.none,
      description: 'No network required',
    );
  }

  static List<PermissionRequirement> _derivePermissionRequirements(
    AppBlueprint blueprint,
  ) {
    return [];
  }

  static BackendClassification _deriveBackendClassification(
    AppBlueprint blueprint,
  ) {
    if (blueprint.networkConfig != null) {
      return BackendClassification.externalApi;
    }
    if (blueprint.entities.isNotEmpty) {
      return BackendClassification.localDatabase;
    }
    return BackendClassification.none;
  }

  static List<RequiredCapability> _deriveRequiredCapabilities(
    AppBlueprint blueprint,
  ) {
    final capabilities = <RequiredCapability>[];
    if (blueprint.entities.isNotEmpty) {
      capabilities.add(
        const RequiredCapability(capabilityId: 'storage', isRequired: true),
      );
    }
    for (final capId in blueprint.requiredCapabilities) {
      capabilities.add(
        RequiredCapability(capabilityId: capId, isRequired: true),
      );
    }
    return capabilities;
  }

  static OfflineBehavior _deriveOfflineBehavior(AppBlueprint blueprint) {
    switch (blueprint.offlinePolicy) {
      case OfflinePolicy.full:
        return const OfflineBehavior(
          offlineCapability: OfflineCapability.fullyOffline,
          description: 'Works entirely offline',
        );
      case OfflinePolicy.partial:
        return const OfflineBehavior(
          offlineCapability: OfflineCapability.mostlyOffline,
          description: 'Mostly offline with optional network',
        );
      case OfflinePolicy.networkRequired:
        return const OfflineBehavior(
          offlineCapability: OfflineCapability.requiresNetwork,
          description: 'Requires network',
        );
    }
  }
}
