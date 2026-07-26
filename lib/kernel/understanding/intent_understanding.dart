/// Structured representation of what the Kernel understands about an Intent.
library;

import '../../core/contracts/intent.dart';
import '../classification/intent_category.dart';
import '../specification/experience_spec.dart';

class IntentUnderstanding {
  final IntentId intentId;
  final String objective;
  final IntentCategory category;
  final ExistingExperienceResolution existingExperience;
  final String desiredOutcome;
  final List<String> constraints;
  final List<String> requiredInputs;
  final List<String> assumptions;
  final double confidence;
  final List<IdentifiedAmbiguity> ambiguities;
  final NetworkNeed networkNeed;
  final CreationNeed creationNeed;
  final ModificationNeed modificationNeed;

  const IntentUnderstanding({
    required this.intentId,
    required this.objective,
    required this.category,
    required this.existingExperience,
    required this.desiredOutcome,
    this.constraints = const [],
    this.requiredInputs = const [],
    this.assumptions = const [],
    required this.confidence,
    this.ambiguities = const [],
    required this.networkNeed,
    required this.creationNeed,
    required this.modificationNeed,
  });
}

class ExistingExperienceResolution {
  final ExistingExperienceStatus status;
  final String? experienceId;
  final String? experienceName;

  const ExistingExperienceResolution({
    required this.status,
    this.experienceId,
    this.experienceName,
  });

  factory ExistingExperienceResolution.notChecked() =>
      const ExistingExperienceResolution(
        status: ExistingExperienceStatus.notChecked,
      );

  factory ExistingExperienceResolution.found({
    required String experienceId,
    required String experienceName,
  }) => ExistingExperienceResolution(
    status: ExistingExperienceStatus.found,
    experienceId: experienceId,
    experienceName: experienceName,
  );

  factory ExistingExperienceResolution.notFound() =>
      const ExistingExperienceResolution(
        status: ExistingExperienceStatus.notFound,
      );
}

enum ExistingExperienceStatus { notChecked, found, notFound, error }

enum CreationNeed { notNeeded, likelyNeeded, definitelyNeeded }

enum ModificationNeed { notNeeded, likelyNeeded, definitelyNeeded }

class IdentifiedAmbiguity {
  final String description;
  final AmbiguitySeverity severity;
  const IdentifiedAmbiguity({
    required this.description,
    required this.severity,
  });
}

enum AmbiguitySeverity { safeToAssume, userInputRequired, critical }
