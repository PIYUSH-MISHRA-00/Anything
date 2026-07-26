/// Builds ExperienceSpec from IntentUnderstanding.
///
/// This is a fallback builder used when the synthesis pipeline is not available.
/// It uses generic derivation from understanding structure, not domain keywords.
library;

import 'package:uuid/uuid.dart';

import '../../core/contracts/intent.dart';
import '../understanding/intent_understanding.dart';
import 'experience_spec.dart';

/// Builds ExperienceSpec from understanding.
class ExperienceSpecBuilder {
  /// Build an ExperienceSpec from an IntentUnderstanding.
  ExperienceSpec build({
    required IntentUnderstanding understanding,
    required Intent intent,
  }) {
    final id = 'spec-${const Uuid().v4()}';
    final name = _deriveName(understanding);
    final description = _deriveDescription(understanding);
    final category = _deriveCategory(understanding);

    return ExperienceSpec(
      id: id,
      name: name,
      description: description,
      category: category,
      interactionModel: _deriveInteractionModel(understanding),
      uiRequirements: _deriveUIRequirements(understanding),
      functionalRequirements: _deriveFunctionalRequirements(understanding),
      stateRequirements: _deriveStateRequirements(understanding),
      storageRequirements: _deriveStorageRequirements(understanding),
      serviceRequirements: _deriveServiceRequirements(understanding),
      networkRequirements: _deriveNetworkRequirements(understanding),
      backendClassification: _deriveBackendClassification(understanding),
      requiredCapabilities: _deriveRequiredCapabilities(understanding),
      protectionRequirements: _deriveProtectionRequirements(understanding),
      runtimeRequirements: const RuntimeRequirements(),
      qualityRequirements: const QualityRequirements(),
      accessibilityRequirements: const AccessibilityRequirements(),
      offlineBehavior: _deriveOfflineBehavior(understanding),
      sourceIntentId: intent.id,
      createdAt: DateTime.now(),
    );
  }

  String _deriveName(IntentUnderstanding understanding) {
    final obj = understanding.objective;
    if (obj.isEmpty) return 'Untitled Experience';
    return obj[0].toUpperCase() + obj.substring(1);
  }

  String _deriveDescription(IntentUnderstanding understanding) {
    return understanding.desiredOutcome.isNotEmpty
        ? understanding.desiredOutcome
        : understanding.objective;
  }

  ExperienceCategory _deriveCategory(IntentUnderstanding understanding) {
    // Generic derivation from understanding structure, not domain keywords
    if (understanding.networkNeed == NetworkNeed.required) {
      return ExperienceCategory.utility;
    }
    return ExperienceCategory.unknown;
  }

  InteractionModel _deriveInteractionModel(IntentUnderstanding understanding) {
    // Generic derivation from understanding structure
    return InteractionModel.formBased;
  }

  UIRequirements _deriveUIRequirements(IntentUnderstanding understanding) {
    return UIRequirements(
      description: 'Interface for ${understanding.objective}',
    );
  }

  List<FunctionalRequirement> _deriveFunctionalRequirements(
    IntentUnderstanding understanding,
  ) {
    return [
      FunctionalRequirement(
        id: 'fr-001',
        description: 'Fulfill the user objective: ${understanding.objective}',
      ),
    ];
  }

  StateRequirements _deriveStateRequirements(
    IntentUnderstanding understanding,
  ) {
    return const StateRequirements(
      description: 'Standard application state',
      requiresEphemeralState: true,
    );
  }

  StorageRequirements _deriveStorageRequirements(
    IntentUnderstanding understanding,
  ) {
    return const StorageRequirements(
      description: 'No persistent storage required',
      storageType: StorageType.none,
    );
  }

  List<ServiceRequirement> _deriveServiceRequirements(
    IntentUnderstanding understanding,
  ) {
    return const [];
  }

  NetworkRequirements _deriveNetworkRequirements(
    IntentUnderstanding understanding,
  ) {
    return NetworkRequirements(
      networkNeed: understanding.networkNeed,
      description: understanding.networkNeed == NetworkNeed.none
          ? 'This experience works fully offline'
          : 'Network access required for data',
    );
  }

  BackendClassification _deriveBackendClassification(
    IntentUnderstanding understanding,
  ) {
    if (understanding.networkNeed == NetworkNeed.required) {
      return BackendClassification.externalApi;
    }
    return BackendClassification.none;
  }

  List<RequiredCapability> _deriveRequiredCapabilities(
    IntentUnderstanding understanding,
  ) {
    return const [];
  }

  ProtectionRequirements _deriveProtectionRequirements(
    IntentUnderstanding understanding,
  ) {
    return const ProtectionRequirements(
      requiresEncryption: false,
      requiresLocalOnly: true,
    );
  }

  OfflineBehavior _deriveOfflineBehavior(IntentUnderstanding understanding) {
    if (understanding.networkNeed == NetworkNeed.none) {
      return const OfflineBehavior(
        offlineCapability: OfflineCapability.fullyOffline,
        description: 'Works completely offline',
      );
    }

    if (understanding.networkNeed == NetworkNeed.required) {
      return const OfflineBehavior(
        offlineCapability: OfflineCapability.requiresNetwork,
        description: 'Requires network for full functionality',
      );
    }

    return const OfflineBehavior(
      offlineCapability: OfflineCapability.hybrid,
      description: 'Works offline with reduced functionality',
    );
  }
}
