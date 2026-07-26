/// Builds ExperienceSpec from IntentUnderstanding.
///
/// Uses smart defaults and the understanding to produce
/// a complete, versioned specification.
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
    // Capitalize first letter of objective
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
    final obj = understanding.objective.toLowerCase();
    if (obj.contains('calculator') || obj.contains('math')) {
      return ExperienceCategory.tool;
    }
    if (obj.contains('tracker') || obj.contains('habit')) {
      return ExperienceCategory.productivity;
    }
    if (obj.contains('budget') ||
        obj.contains('expense') ||
        obj.contains('finance')) {
      return ExperienceCategory.finance;
    }
    if (obj.contains('health') ||
        obj.contains('water') ||
        obj.contains('exercise')) {
      return ExperienceCategory.health;
    }
    if (obj.contains('timer') || obj.contains('pomodoro')) {
      return ExperienceCategory.productivity;
    }
    if (obj.contains('weather')) {
      return ExperienceCategory.utility;
    }
    return ExperienceCategory.unknown;
  }

  InteractionModel _deriveInteractionModel(IntentUnderstanding understanding) {
    final obj = understanding.objective.toLowerCase();
    if (obj.contains('calculator') || obj.contains('timer')) {
      return InteractionModel.directManipulation;
    }
    if (obj.contains('tracker') || obj.contains('planner')) {
      return InteractionModel.formBased;
    }
    if (obj.contains('dashboard')) {
      return InteractionModel.dashboard;
    }
    return InteractionModel.directManipulation;
  }

  UIRequirements _deriveUIRequirements(IntentUnderstanding understanding) {
    final obj = understanding.objective.toLowerCase();

    if (obj.contains('calculator')) {
      return const UIRequirements(
        description: 'Calculator interface',
        primaryViews: ['main calculator view'],
        inputElements: ['numeric keypad', 'operation buttons'],
        displayElements: ['result display', 'expression display'],
      );
    }

    if (obj.contains('tracker') || obj.contains('habit')) {
      return const UIRequirements(
        description: 'Tracker interface with data entry and history',
        primaryViews: ['tracker view', 'history view'],
        inputElements: ['data entry form', 'date picker'],
        displayElements: ['progress display', 'streak counter', 'history list'],
      );
    }

    if (obj.contains('weather')) {
      return const UIRequirements(
        description: 'Weather dashboard',
        primaryViews: ['current weather', 'forecast'],
        displayElements: ['temperature', 'conditions', 'forecast cards'],
      );
    }

    return UIRequirements(
      description: 'Interface for ${understanding.objective}',
    );
  }

  List<FunctionalRequirement> _deriveFunctionalRequirements(
    IntentUnderstanding understanding,
  ) {
    final obj = understanding.objective.toLowerCase();

    if (obj.contains('calculator')) {
      return [
        const FunctionalRequirement(
          id: 'fr-001',
          description: 'Perform addition',
          acceptanceCriteria: ['Correctly adds two numbers'],
        ),
        const FunctionalRequirement(
          id: 'fr-002',
          description: 'Perform subtraction',
          acceptanceCriteria: ['Correctly subtracts two numbers'],
        ),
        const FunctionalRequirement(
          id: 'fr-003',
          description: 'Perform multiplication',
          acceptanceCriteria: ['Correctly multiplies two numbers'],
        ),
        const FunctionalRequirement(
          id: 'fr-004',
          description: 'Perform division',
          acceptanceCriteria: [
            'Correctly divides two numbers',
            'Handles division by zero',
          ],
        ),
        const FunctionalRequirement(
          id: 'fr-005',
          description: 'Display calculation result',
          acceptanceCriteria: ['Result is visible and accurate'],
        ),
      ];
    }

    if (obj.contains('tracker') || obj.contains('habit')) {
      return [
        const FunctionalRequirement(
          id: 'fr-001',
          description: 'Log daily entries',
          acceptanceCriteria: ['User can mark completion for today'],
        ),
        const FunctionalRequirement(
          id: 'fr-002',
          description: 'View history',
          acceptanceCriteria: ['Shows past entries in a list or calendar'],
        ),
        const FunctionalRequirement(
          id: 'fr-003',
          description: 'Track streaks',
          acceptanceCriteria: ['Calculates current and best streaks'],
        ),
        const FunctionalRequirement(
          id: 'fr-004',
          description: 'Persist data locally',
          acceptanceCriteria: ['Data survives app restart'],
        ),
      ];
    }

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
    final obj = understanding.objective.toLowerCase();

    if (obj.contains('calculator')) {
      return const StateRequirements(
        description: 'Ephemeral calculation state',
        requiresEphemeralState: true,
        requiresPersistentState: false,
      );
    }

    if (obj.contains('tracker') || obj.contains('habit')) {
      return const StateRequirements(
        description: 'Persistent tracking data',
        requiresEphemeralState: true,
        requiresPersistentState: true,
        stateEntities: ['habit_entry', 'streak_data'],
      );
    }

    return const StateRequirements(
      description: 'Standard application state',
      requiresEphemeralState: true,
    );
  }

  StorageRequirements _deriveStorageRequirements(
    IntentUnderstanding understanding,
  ) {
    final obj = understanding.objective.toLowerCase();

    if (obj.contains('tracker') || obj.contains('habit')) {
      return const StorageRequirements(
        description: 'Local SQLite database for habit data',
        storageType: StorageType.localDatabase,
        requiresDatabase: true,
      );
    }

    return const StorageRequirements(
      description: 'No persistent storage required',
      storageType: StorageType.none,
    );
  }

  List<ServiceRequirement> _deriveServiceRequirements(
    IntentUnderstanding understanding,
  ) {
    final obj = understanding.objective.toLowerCase();

    if (obj.contains('tracker') || obj.contains('habit')) {
      return const [
        ServiceRequirement(
          id: 'svc-001',
          description: 'Local database access',
          type: ServiceType.localDatabase,
        ),
      ];
    }

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
    final obj = understanding.objective.toLowerCase();

    if (obj.contains('tracker') || obj.contains('habit')) {
      return BackendClassification.localDatabase;
    }

    if (understanding.networkNeed == NetworkNeed.required) {
      return BackendClassification.externalApi;
    }

    return BackendClassification.none;
  }

  List<RequiredCapability> _deriveRequiredCapabilities(
    IntentUnderstanding understanding,
  ) {
    final obj = understanding.objective.toLowerCase();

    if (obj.contains('tracker') || obj.contains('habit')) {
      return const [RequiredCapability(capabilityId: 'local-database')];
    }

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
