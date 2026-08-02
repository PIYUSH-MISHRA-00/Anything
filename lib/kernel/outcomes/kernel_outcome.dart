/// Typed Kernel outcome types.
///
/// The Kernel returns one of these after processing an Intent.
/// UI maps these to human-friendly messages.
library;

import '../../application_engineering/engineering_plan.dart';
import '../../feature_discovery/feature_plan.dart';
import '../../synthesis/app_blueprint.dart';
import '../specification/experience_spec.dart';
import '../planning/execution_plan.dart';
import '../understanding/intent_understanding.dart';

/// Base class for all Kernel outcomes.
sealed class KernelOutcome {
  final String message;
  final DateTime timestamp;

  const KernelOutcome({required this.message, required this.timestamp});
}

/// An existing Experience was found and opened.
class OpenExistingExperience extends KernelOutcome {
  final String experienceId;
  final String experienceName;

  const OpenExistingExperience({
    required this.experienceId,
    required this.experienceName,
    required super.message,
    required super.timestamp,
  });
}

/// Experience specification is ready for planning.
class ExperienceSpecificationReady extends KernelOutcome {
  final ExperienceSpec specification;
  final IntentUnderstanding understanding;

  const ExperienceSpecificationReady({
    required this.specification,
    required this.understanding,
    required super.message,
    required super.timestamp,
  });
}

/// Execution plan is ready for the Runtime.
class ExecutionPlanReady extends KernelOutcome {
  final ExecutionPlan plan;
  final ExperienceSpec specification;
  final AppBlueprint? blueprint;

  /// The Application Engineering Engine's output for this creation
  /// (Vision Milestone V3), null only for outcomes that never reach
  /// engineering planning (there are none on the production path — the
  /// Kernel always populates this alongside [blueprint]).
  final EngineeringPlan? engineeringPlan;

  /// The Feature Discovery Engine's output for this creation (Vision
  /// Milestone V4) — the approved FeatureGraph that shaped Architecture
  /// and Engineering. Null only for outcomes that never reach feature
  /// discovery (there are none on the production path).
  final FeaturePlan? featurePlan;

  const ExecutionPlanReady({
    required this.plan,
    required this.specification,
    this.blueprint,
    this.engineeringPlan,
    this.featurePlan,
    required super.message,
    required super.timestamp,
  });
}

/// Clarification is needed from the user.
class ClarificationRequired extends KernelOutcome {
  final ClarificationRequest request;

  const ClarificationRequired({
    required this.request,
    required super.message,
    required super.timestamp,
  });
}

/// A provider is needed but not configured.
class ProviderRequired extends KernelOutcome {
  const ProviderRequired({required super.message, required super.timestamp});
}

/// The intent cannot be fulfilled by Anything.
class UnsupportedIntent extends KernelOutcome {
  final String reason;

  const UnsupportedIntent({
    required this.reason,
    required super.message,
    required super.timestamp,
  });
}

/// Planning failed due to an error.
class PlanningFailed extends KernelOutcome {
  final String error;
  final StackTrace? stackTrace;

  const PlanningFailed({
    required this.error,
    this.stackTrace,
    required super.message,
    required super.timestamp,
  });
}

/// A clarification request to the user.
class ClarificationRequest {
  final String question;
  final String reason;
  final ClarificationResponseType expectedResponseType;
  final List<String>? choices;
  final String? affectedRequirement;

  const ClarificationRequest({
    required this.question,
    required this.reason,
    required this.expectedResponseType,
    this.choices,
    this.affectedRequirement,
  });
}

/// Expected type of response for a clarification.
enum ClarificationResponseType { text, choice, boolean, numeric }
