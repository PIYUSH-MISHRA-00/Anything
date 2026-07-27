/// Experience Creation Coordinator — orchestrates the full creation lifecycle.
///
/// Connects: Intent → Kernel → CreationEngine → Persistence → Runtime.
library;

import 'dart:async';

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/creation/creation_engine.dart';
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/kernel/planning/execution_plan.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';

/// User-facing creation state.
enum CreationState {
  idle,
  understanding,
  creating,
  validating,
  persisting,
  ready,
  failed,
  cancelled,
}

/// Typed creation result.
sealed class CreationResult {
  final String message;
  const CreationResult({required this.message});
}

/// Created a new Experience.
class CreationCreated extends CreationResult {
  final ExperiencePackage package;
  final String experienceId;
  const CreationCreated({
    required this.package,
    required this.experienceId,
    required super.message,
  });
}

/// Opened an existing Experience.
class CreationOpened extends CreationResult {
  final String experienceId;
  final String experienceName;
  const CreationOpened({
    required this.experienceId,
    required this.experienceName,
    required super.message,
  });
}

/// Clarification needed.
class CreationClarification extends CreationResult {
  final String question;
  const CreationClarification({required this.question, required super.message});
}

/// Provider needed.
class CreationProviderRequired extends CreationResult {
  const CreationProviderRequired({required super.message});
}

/// Creation failed.
class CreationFailed extends CreationResult {
  final String error;
  const CreationFailed({required this.error, required super.message});
}

/// Orchestrates the complete creation lifecycle.
class ExperienceCreationCoordinator {
  final AnythingKernel _kernel;
  final CreationEngine _creationEngine;
  final SqliteExperienceRepository _repository;
  final ActivityRepository _activity;

  CreationState _state = CreationState.idle;
  CreationState get state => _state;

  ExperienceCreationCoordinator({
    required AnythingKernel kernel,
    CreationEngine? creationEngine,
    SqliteExperienceRepository? repository,
    ActivityRepository? activity,
  }) : _kernel = kernel,
       _creationEngine = creationEngine ?? CreationEngine(),
       _repository = repository ?? SqliteExperienceRepository(),
       _activity = activity ?? ActivityRepository();

  /// Create from a canonical Intent.
  Future<CreationResult> createFromIntent(Intent intent) async {
    _state = CreationState.understanding;

    try {
      final kernelOutcome = await _kernel.processIntent(intent);

      switch (kernelOutcome) {
        case OpenExistingExperience():
          // Do NOT emit Opened Activity here — the OpeningCoordinator
          // is the single canonical emission point for Opened events.
          return CreationOpened(
            experienceId: kernelOutcome.experienceId,
            experienceName: kernelOutcome.experienceName,
            message: kernelOutcome.message,
          );

        case ExecutionPlanReady():
          return await _createExperience(
            intent: intent,
            specification: kernelOutcome.specification,
            plan: kernelOutcome.plan,
          );

        case ExperienceSpecificationReady():
          // Deprecated legacy path — should never be reached in production.
          // All universal synthesis produces ExecutionPlanReady.
          return CreationFailed(
            error: 'Deprecated creation path',
            message: 'This creation path is no longer supported',
          );

        case ClarificationRequired():
          return CreationClarification(
            question: kernelOutcome.message,
            message: kernelOutcome.message,
          );

        case ProviderRequired():
          return const CreationProviderRequired(
            message: 'Connect an AI provider to create new things',
          );

        case UnsupportedIntent():
          return CreationFailed(
            error: kernelOutcome.reason,
            message: kernelOutcome.message,
          );

        case PlanningFailed():
          return CreationFailed(
            error: kernelOutcome.error,
            message: 'Something went wrong during planning',
          );
      }
    } catch (e) {
      return CreationFailed(
        error: e.toString(),
        message: 'Something went wrong',
      );
    }
  }

  /// Convenience: create from expression string.
  Future<CreationResult> createFromExpression(String expression) async {
    return createFromIntent(Intent.create(expression: expression));
  }

  Future<CreationResult> _createExperience({
    required Intent intent,
    required ExperienceSpec specification,
    required ExecutionPlan plan,
  }) async {
    _state = CreationState.creating;

    try {
      final creationResult = await _creationEngine.create(
        CreationContext(
          intent: intent,
          specification: specification,
          plan: plan,
          platformContext: const PlatformContext(
            platform: 'android',
            sdkVersion: 34,
          ),
          securityPolicy: const CreationSecurityPolicy(),
        ),
      );

      if (creationResult is! CreationReady) {
        _state = CreationState.failed;
        return CreationFailed(
          error: creationResult.message,
          message: creationResult.message,
        );
      }

      // Validate with production validator
      _state = CreationState.validating;
      final validation = ExperiencePackageValidator.validate(
        creationResult.package,
      );
      if (!validation.isValid) {
        _state = CreationState.failed;
        return CreationFailed(
          error: validation.errors.join('; '),
          message: 'Could not complete this app',
        );
      }

      // Persist
      _state = CreationState.persisting;
      final package = creationResult.package;
      await _repository.savePackage(package);
      await _repository.saveMetadata(
        ExperienceMetadataRecord(
          id: package.manifest.experienceId,
          name: package.manifest.name,
          description: package.manifest.description,
          category: package.manifest.category,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await _activity.record(
        ActivityEvent(
          id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
          type: 'created',
          experienceId: package.manifest.experienceId,
          experienceName: package.manifest.name,
          message: 'Created ${package.manifest.name}',
          timestamp: DateTime.now(),
        ),
      );

      _state = CreationState.ready;
      return CreationCreated(
        package: package,
        experienceId: package.manifest.experienceId,
        message: 'Created ${package.manifest.name}',
      );
    } catch (e) {
      _state = CreationState.failed;
      return CreationFailed(
        error: e.toString(),
        message: 'Could not complete this app',
      );
    }
  }

  void reset() {
    _state = CreationState.idle;
  }
}
