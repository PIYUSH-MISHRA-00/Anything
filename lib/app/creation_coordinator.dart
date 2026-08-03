/// Experience Creation Coordinator — orchestrates the full creation lifecycle.
///
/// Connects: Intent → Kernel → CreationEngine → Persistence → Runtime.
library;

import 'dart:async';

import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/creation/creation_engine.dart';
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/kernel/planning/execution_plan.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/application_engineering/engineering_memory_summary.dart';
import 'package:anything/software_architect/requirement_graph.dart';
import 'package:anything/solution_reasoning/solution_decision.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

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

  /// Optional shared World Graph (Implementation Milestone R1). When
  /// present, a successful creation is ingested via `ingestExperience` —
  /// REALITY before R1: this coordinator never referenced World Model at
  /// all (MIS-1 Part 2). Null by default, fully backward compatible.
  final WorldModelCoordinator? _worldModel;

  /// Optional shared Software Cognition coordinator (Implementation
  /// Milestone R1). When both this AND a `referenceUrl` are supplied to
  /// `createFromIntent`, acquired repository understanding is fed into
  /// the Kernel's existing, already-safe knowledge pathway BEFORE
  /// reasoning runs — never a second, parallel prompt-injection surface
  /// (see `docs/architecture/SOFTWARE_COGNITION_ENGINE.md`, "The
  /// architectural correction"). Purely additive: omitting `referenceUrl`
  /// leaves creation byte-for-byte unchanged.
  final SoftwareCognitionCoordinator? _softwareCognition;

  /// Optional shared engineering-memory repository (Implementation
  /// Milestone R5), matching `_worldModel`/`_softwareCognition`'s exact
  /// "null unless the composition root explicitly injects one" pattern —
  /// REALITY before R5: `RequirementGraph`/`ArchitectureCandidate` were
  /// computed inside the Kernel and immediately discarded (MIS-1 Part 2).
  /// Null by default, fully backward compatible.
  final EngineeringMemoryRepository? _engineeringMemory;

  CreationState _state = CreationState.idle;
  CreationState get state => _state;

  ExperienceCreationCoordinator({
    required AnythingKernel kernel,
    CreationEngine? creationEngine,
    SqliteExperienceRepository? repository,
    ActivityRepository? activity,
    WorldModelCoordinator? worldModel,
    SoftwareCognitionCoordinator? softwareCognition,
    EngineeringMemoryRepository? engineeringMemory,
  }) : _kernel = kernel,
       _creationEngine = creationEngine ?? CreationEngine(),
       _repository = repository ?? SqliteExperienceRepository(),
       _activity = activity ?? ActivityRepository(),
       _worldModel = worldModel,
       _softwareCognition = softwareCognition,
       _engineeringMemory = engineeringMemory;

  /// Create from a canonical Intent.
  ///
  /// [referenceUrl] optionally names an existing repository/package the
  /// user wants this creation "inspired by" — when supplied (and a
  /// `SoftwareCognitionCoordinator` was injected), real acquired
  /// understanding (never copied source) is fed into reasoning. Omitted
  /// by default; existing callers are unaffected.
  Future<CreationResult> createFromIntent(
    Intent intent, {
    String? referenceUrl,
  }) async {
    _state = CreationState.understanding;

    try {
      final seedKnowledge = await _acquireSoftwareCognitionSeed(referenceUrl);
      final kernelOutcome = await _kernel.processIntent(
        intent,
        seedKnowledge: seedKnowledge,
      );

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
            blueprint: kernelOutcome.blueprint,
            engineeringPlan: kernelOutcome.engineeringPlan,
            requirementGraph: kernelOutcome.requirementGraph,
            solutionDecision: kernelOutcome.solutionDecision,
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
  Future<CreationResult> createFromExpression(
    String expression, {
    String? referenceUrl,
  }) async {
    return createFromIntent(
      Intent.create(expression: expression),
      referenceUrl: referenceUrl,
    );
  }

  /// Acquires real Software Cognition understanding of [referenceUrl] (if
  /// supplied and a coordinator was injected) and converts a sound result
  /// into a `KnowledgeResource` seed — never raw source, never a
  /// fabricated resource from an unsound/unreviewed result (see
  /// `SoftwareCognitionCoordinator.toKnowledgeResource`). Returns an empty
  /// list on any failure or when the feature isn't in use — this is
  /// always an optional enhancement, never a hard dependency of creation.
  Future<List<KnowledgeResource>> _acquireSoftwareCognitionSeed(
    String? referenceUrl,
  ) async {
    if (referenceUrl == null || referenceUrl.isEmpty || _softwareCognition == null) {
      return const [];
    }
    try {
      final result = await _softwareCognition.engine.understandRepositoryFromUrl(
        referenceUrl,
        name: Uri.tryParse(referenceUrl)?.host ?? referenceUrl,
      );
      if (result == null || !result.isSound) return const [];
      final resource = _softwareCognition.toKnowledgeResource(result);
      return resource == null ? const [] : [resource];
    } catch (_) {
      return const [];
    }
  }

  Future<CreationResult> _createExperience({
    required Intent intent,
    required ExperienceSpec specification,
    required ExecutionPlan plan,
    AppBlueprint? blueprint,
    EngineeringPlan? engineeringPlan,
    RequirementGraph? requirementGraph,
    SolutionDecision? solutionDecision,
  }) async {
    _state = CreationState.creating;

    try {
      final creationResult = await _creationEngine.create(
        CreationContext(
          intent: intent,
          specification: specification,
          plan: plan,
          blueprint: blueprint,
          engineeringPlan: engineeringPlan,
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
      final metadata = ExperienceMetadataRecord(
        id: package.manifest.experienceId,
        name: package.manifest.name,
        description: package.manifest.description,
        category: package.manifest.category,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repository.savePackage(package);
      await _repository.saveMetadata(metadata);

      // World Graph ingestion (Implementation Milestone R1) — best-effort,
      // never allowed to fail creation itself; see AnythingKernel's
      // identical `_ingestIntoWorldModelSafely` rationale.
      if (_worldModel != null) {
        try {
          _worldModel.ingestExperience(metadata, package);
          await _worldModel.persist();
        } catch (_) {
          // Deliberately swallowed — World Graph bookkeeping must never
          // block a successful creation from being reported to the user.
        }
      }

      // Engineering memory persistence (Implementation Milestone R5) —
      // best-effort, same non-blocking contract as World Model ingestion
      // above: a failure here must never fail a successful creation.
      // Sequential with (not inside the same SQLite transaction as)
      // `savePackage` — this is real, deliberate scoping, not an
      // oversight, see `docs/architecture/ENGINEERING_MEMORY.md`
      // "Atomicity".
      if (_engineeringMemory != null) {
        try {
          await _engineeringMemory.save(
            experienceId: package.manifest.experienceId,
            requirementGraph: requirementGraph,
            architectureCandidate: solutionDecision?.selected.architecture,
            engineeringSummary: engineeringPlan == null ? null : EngineeringMemorySummary.summarize(engineeringPlan),
          );
        } catch (_) {
          // Deliberately swallowed — see comment above.
        }
      }

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
