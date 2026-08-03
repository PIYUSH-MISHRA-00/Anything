/// Experience Creation Coordinator — orchestrates the full creation lifecycle.
///
/// Connects: Intent → Kernel → CreationEngine → Persistence → Runtime.
library;

import 'dart:async';

import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
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
import 'package:anything/software_cognition/software_cognition_engine.dart' show RepositoryCognitionResult;
import 'package:anything/software_cognition/software_reasoner.dart';
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
  ///
  /// [referenceUrls] (Implementation Milestone R15) optionally names
  /// MULTIPLE such sources in one request — additive to [referenceUrl],
  /// which still works unchanged as a single-source convenience (both
  /// may be supplied together; every URL from either is acquired). With
  /// 2+ real sources, `SoftwareReasoner.reasonAboutRepositories` (V11)
  /// finally corroborates across genuinely independent candidates instead
  /// of the single-candidate case where its `minSupportingCandidates`
  /// gate can never accept anything (see R14's own documented limitation
  /// in `docs/architecture/SOFTWARE_COGNITION_ENGINE.md`).
  /// [autoDiscoverKnowledge] (Implementation Milestone R16) opts the
  /// Kernel into autonomous repository discovery from the reasoner's own
  /// already-emitted `knowledgeNeeds` — no reference URL required. `false`
  /// by default; composes with (does not replace) [referenceUrl]/
  /// [referenceUrls] when both are supplied.
  Future<CreationResult> createFromIntent(
    Intent intent, {
    String? referenceUrl,
    List<String>? referenceUrls,
    bool autoDiscoverKnowledge = false,
  }) async {
    _state = CreationState.understanding;

    try {
      final urls = <String>{
        if (referenceUrl != null && referenceUrl.isNotEmpty) referenceUrl,
        ...?referenceUrls?.where((u) => u.isNotEmpty),
      }.toList();
      final (seedKnowledge, corroboratingRecommendations) = await _acquireSoftwareCognitionSeeds(urls);
      final kernelOutcome = await _kernel.processIntent(
        intent,
        seedKnowledge: seedKnowledge,
        corroboratingRecommendations: corroboratingRecommendations,
        autoDiscoverKnowledge: autoDiscoverKnowledge,
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
            backendEngineeringPlan: kernelOutcome.backendEngineeringPlan,
            canonicalImplementationModel: kernelOutcome.canonicalImplementationModel,
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
    List<String>? referenceUrls,
    bool autoDiscoverKnowledge = false,
  }) async {
    return createFromIntent(
      Intent.create(expression: expression),
      referenceUrl: referenceUrl,
      referenceUrls: referenceUrls,
      autoDiscoverKnowledge: autoDiscoverKnowledge,
    );
  }

  /// Acquires real Software Cognition understanding of every URL in
  /// [urls] (Implementation Milestone R15 — generalizes the single-source
  /// `_acquireSoftwareCognitionSeed` this replaces) and returns both a
  /// `KnowledgeResource` seed per sound acquisition AND the real,
  /// multi-source-corroborated `SoftwareRecommendation`s
  /// `SoftwareReasoner.reasonAboutRepositories` (V11) produces when given
  /// every acquired candidate together — never raw source, never a
  /// fabricated resource/recommendation. Returns empty on any failure or
  /// when the feature isn't in use — always an optional enhancement,
  /// never a hard dependency of creation. Every acquired repository's
  /// software graph is synced into the World Model (not just the first);
  /// `GraphMerge`'s existing identity-keyed dedup (unchanged, V9) means
  /// two sources reporting the same real-world framework/dependency
  /// collapse into one World Model node, never two.
  Future<(List<KnowledgeResource>, List<SoftwareRecommendation>)> _acquireSoftwareCognitionSeeds(
    List<String> urls,
  ) async {
    if (urls.isEmpty || _softwareCognition == null) {
      return (const <KnowledgeResource>[], const <SoftwareRecommendation>[]);
    }

    final soundResults = <RepositoryCognitionResult>[];
    for (final url in urls) {
      try {
        final result = await _softwareCognition.engine.understandRepositoryFromUrl(
          url,
          name: Uri.tryParse(url)?.host ?? url,
        );
        if (result != null && result.isSound) soundResults.add(result);
      } catch (_) {
        // Deliberately swallowed — one failed source must never fail the
        // whole creation, matching the single-source contract this
        // replaces.
      }
    }
    if (soundResults.isEmpty) {
      return (const <KnowledgeResource>[], const <SoftwareRecommendation>[]);
    }

    // World Graph ingestion (Implementation Milestone R14, generalized to
    // every acquired source by R15) — best-effort, never allowed to fail
    // creation itself, same non-blocking contract as `ingestExperience`
    // below.
    if (_worldModel != null) {
      for (final result in soundResults) {
        try {
          _softwareCognition.syncToWorldModel(_worldModel, result.model);
        } catch (_) {
          // Deliberately swallowed — see comment above.
        }
      }
    }

    final seedKnowledge = <KnowledgeResource>[
      for (final result in soundResults)
        if (_softwareCognition.toKnowledgeResource(result) case final resource?) resource,
    ];

    // Real multi-source corroboration (Implementation Milestone R15) —
    // reuses SoftwareReasoner.reasonAboutRepositories unchanged (V11).
    // With a single sound source this still returns recommendations, but
    // every one is `accepted: false` (minSupportingCandidates defaults to
    // 2) — filtered out below, matching R14's documented "single source
    // can never satisfy the acceptance gate" finding exactly.
    final candidates = soundResults.map((r) => r.model).toList();
    final corroboratingRecommendations = _softwareCognition.reasoner.reasonAboutRepositories(candidates).where((r) => r.accepted).toList();

    return (seedKnowledge, corroboratingRecommendations);
  }

  Future<CreationResult> _createExperience({
    required Intent intent,
    required ExperienceSpec specification,
    required ExecutionPlan plan,
    AppBlueprint? blueprint,
    EngineeringPlan? engineeringPlan,
    RequirementGraph? requirementGraph,
    SolutionDecision? solutionDecision,
    BackendEngineeringPlan? backendEngineeringPlan,
    CanonicalImplementationModel? canonicalImplementationModel,
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
            backendEngineeringPlan: backendEngineeringPlan,
            canonicalImplementationModel: canonicalImplementationModel,
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
