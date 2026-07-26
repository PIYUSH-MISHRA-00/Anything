/// Execution Plan for Anything.
///
/// Represents HOW Anything intends to satisfy an ExperienceSpec.
/// It is not executable code — it is a typed, validated plan
/// that the future Runtime will execute.
library;

import 'package:anything/kernel/specification/experience_spec.dart';

/// Version of the ExecutionPlan schema.
const int executionPlanVersion = 1;

/// A typed execution plan with dependency graph.
class ExecutionPlan {
  /// Schema version.
  final int planVersion;

  /// Unique identifier for this plan.
  final String id;

  /// The ExperienceSpec this plan fulfills.
  final ExperienceSpec specification;

  /// Ordered steps with dependencies.
  final List<ExecutionStep> steps;

  /// When this plan was created.
  final DateTime createdAt;

  /// Current status of the plan.
  final PlanStatus status;

  const ExecutionPlan({
    this.planVersion = executionPlanVersion,
    required this.id,
    required this.specification,
    required this.steps,
    required this.createdAt,
    this.status = PlanStatus.created,
  });

  /// Get steps that have no unmet dependencies (ready to execute).
  List<ExecutionStep> get readySteps {
    final completedIds = <String>{};
    return steps.where((step) {
      return step.dependencies.every((dep) => completedIds.contains(dep));
    }).toList();
  }

  /// Validate the plan structure.
  PlanValidationResult validate() {
    return PlanValidator.validate(this);
  }
}

/// Status of an execution plan.
enum PlanStatus {
  created,
  validating,
  ready,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// A single step in an execution plan.
class ExecutionStep {
  /// Unique step identifier.
  final String stepId;

  /// Type of this step.
  final StepType type;

  /// Human-readable description.
  final String description;

  /// IDs of steps this step depends on.
  final List<String> dependencies;

  /// Capability IDs required for this step.
  final List<String> requiredCapabilityIds;

  /// Input references (from previous steps or external).
  final Map<String, String> inputRefs;

  /// Expected output type description.
  final String expectedOutputType;

  /// Whether this step requires network.
  final bool networkRequired;

  /// Permissions needed for this step.
  final List<String> requiredPermissions;

  /// What to do if this step fails.
  final FailurePolicy failurePolicy;

  /// Current status.
  final StepStatus status;

  const ExecutionStep({
    required this.stepId,
    required this.type,
    required this.description,
    this.dependencies = const [],
    this.requiredCapabilityIds = const [],
    this.inputRefs = const {},
    required this.expectedOutputType,
    this.networkRequired = false,
    this.requiredPermissions = const [],
    this.failurePolicy = FailurePolicy.fail,
    this.status = StepStatus.pending,
  });
}

/// Types of execution steps.
enum StepType {
  resolveExisting,
  obtainKnowledge,
  prepareImplementation,
  prepareStorage,
  prepareInterface,
  validateImplementation,
  persistExperience,
  protectData,
  launchExperience,
  custom,
}

/// Step status.
enum StepStatus { pending, ready, inProgress, completed, failed, skipped }

/// Failure policy for a step.
enum FailurePolicy { fail, retry, skip, fallback }

/// Result of plan validation.
class PlanValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const PlanValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory PlanValidationResult.valid() {
    return const PlanValidationResult(isValid: true);
  }

  factory PlanValidationResult.invalid(List<String> errors) {
    return PlanValidationResult(isValid: false, errors: errors);
  }
}

/// Validates execution plan structure.
class PlanValidator {
  /// Validate an execution plan.
  static PlanValidationResult validate(ExecutionPlan plan) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check step IDs are unique
    final stepIds = <String>{};
    for (final step in plan.steps) {
      if (!stepIds.add(step.stepId)) {
        errors.add('Duplicate step ID: ${step.stepId}');
      }
    }

    // Check dependencies exist
    for (final step in plan.steps) {
      for (final dep in step.dependencies) {
        if (!stepIds.contains(dep)) {
          errors.add('Step ${step.stepId} depends on unknown step: $dep');
        }
      }
    }

    // Check for cycles
    if (_hasCycle(plan.steps)) {
      errors.add('Plan contains circular dependencies');
    }

    // Check spec version
    if (plan.specification.specVersion > experienceSpecVersion) {
      errors.add(
        'Spec version ${plan.specification.specVersion} is not supported '
        '(max: $experienceSpecVersion)',
      );
    }

    // Check plan version
    if (plan.planVersion > executionPlanVersion) {
      errors.add(
        'Plan version ${plan.planVersion} is not supported '
        '(max: $executionPlanVersion)',
      );
    }

    // Warn if no steps
    if (plan.steps.isEmpty) {
      warnings.add('Plan has no steps');
    }

    return PlanValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  static bool _hasCycle(List<ExecutionStep> steps) {
    final visited = <String>{};
    final inStack = <String>{};

    bool dfs(String stepId) {
      if (inStack.contains(stepId)) return true;
      if (visited.contains(stepId)) return false;

      visited.add(stepId);
      inStack.add(stepId);

      final step = steps.where((s) => s.stepId == stepId).firstOrNull;
      if (step != null) {
        for (final dep in step.dependencies) {
          if (dfs(dep)) return true;
        }
      }

      inStack.remove(stepId);
      return false;
    }

    for (final step in steps) {
      if (dfs(step.stepId)) return true;
    }
    return false;
  }
}
