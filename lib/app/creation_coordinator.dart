/// Experience Creation Coordinator — orchestrates the full creation lifecycle.
///
/// Connects: Intent → Kernel → CreationEngine → Persistence → Runtime.
library;

import 'dart:async';
import 'dart:convert';

import 'package:anything/ai/provider_error.dart';
import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/diagnostics/log_entry.dart';
import 'package:anything/diagnostics/structured_logger.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/creation_diagnostics.dart';
import 'package:anything/creation/creation_engine.dart';
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/deterministic_repair.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_smoke_validator.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/creation/display_naming.dart';
import 'package:anything/creation/creation_request.dart';
import 'package:anything/creation/intent_contract.dart';
import 'package:anything/creation/intent_preservation.dart';
import 'package:anything/creation/semantic_completeness.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:anything/creation/timing_interface_factory.dart';
import 'package:anything/kernel/planning/execution_plan.dart';
import 'package:anything/app/experience_commit.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/application_engineering/engineering_memory_summary.dart';
import 'package:anything/software_architect/requirement_graph.dart';
import 'package:anything/solution_reasoning/solution_decision.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/software_cognition/software_cognition_engine.dart'
    show RepositoryCognitionResult;
import 'package:anything/software_cognition/software_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/compiler_integration/compiler_pipeline_runner.dart';

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

  /// The ONE commit owner (IS-R55). Creation CREATES; it does not persist.
  ///
  /// This coordinator no longer holds a repository AT ALL. Once its two writes
  /// moved here, the analyzer reported the field as unused — which is the
  /// cleanest possible evidence that creation is now fully decoupled from
  /// persistence rather than merely routed around it.
  final ExperienceCommitFramework _commits;

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

  /// IS-P07: creation failures were previously unobservable. The validator's
  /// reasons and the caught exception both existed and both ended at a
  /// four-word snackbar, so a failing device could not be diagnosed at all.
  final StructuredLogger? _logger;

  /// IS-P10: structured creation diagnostics for Developer Mode / logcat.
  final CreationDiagnostics _diagnostics;

  CreationState _state = CreationState.idle;
  CreationState get state => _state;
  CreationDiagnostics get diagnostics => _diagnostics;

  ExperienceCreationCoordinator({
    required AnythingKernel kernel,
    CreationEngine? creationEngine,
    SqliteExperienceRepository? repository,
    ActivityRepository? activity,
    WorldModelCoordinator? worldModel,
    SoftwareCognitionCoordinator? softwareCognition,
    EngineeringMemoryRepository? engineeringMemory,
    ExperienceCommitFramework? commitFramework,
    StructuredLogger? logger,
    CreationDiagnostics? diagnostics,
  }) : _logger = logger,
       _diagnostics = diagnostics ?? CreationDiagnostics(logger: logger),
       _kernel = kernel,
       _creationEngine = creationEngine ?? CreationEngine(),
       _commits =
           commitFramework ??
           ExperienceCommitFramework(
             repository: repository ?? SqliteExperienceRepository(),
           ),
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
  ///
  /// [useCompilerPipeline] (Implementation Milestone R19) — the ONE
  /// production switch selecting the real, existing compiler pipeline
  /// (`BuildGraphBuilder`->`GenerationPipeline`->`RuntimeExperienceGenerator`,
  /// R9-R13) instead of the legacy `CreationEngine` (V3) for the
  /// `ExperiencePackage` this creation actually validates/persists/serves.
  /// `false` by default — REALITY: the compiler pipeline had ZERO
  /// production callers before this milestone (confirmed by grep); every
  /// existing call site keeps getting the legacy-produced package
  /// byte-for-byte unchanged unless this is explicitly set `true`. When
  /// `true` and the compiler pipeline cannot produce a valid package for
  /// this request (e.g. no entities, or fails
  /// `ExperiencePackageValidator`), creation falls back to the legacy
  /// pipeline rather than failing — see `_createExperience`.
  Future<CreationResult> createFromIntent(
    Intent intent, {
    String? referenceUrl,
    List<String>? referenceUrls,
    bool autoDiscoverKnowledge = false,
    bool useCompilerPipeline = false,
  }) async {
    _state = CreationState.understanding;

    try {
      final urls = <String>{
        if (referenceUrl != null && referenceUrl.isNotEmpty) referenceUrl,
        ...?referenceUrls?.where((u) => u.isNotEmpty),
      }.toList();
      final (seedKnowledge, corroboratingRecommendations) =
          await _acquireSoftwareCognitionSeeds(urls);
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
            canonicalImplementationModel:
                kernelOutcome.canonicalImplementationModel,
            useCompilerPipeline: useCompilerPipeline,
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
          // IS-P07: pass the Kernel's own message through rather than
          // replacing it with a second, vaguer one written here. Every other
          // branch in this switch already does.
          return CreationProviderRequired(message: kernelOutcome.message);

        case UnsupportedIntent():
          return CreationFailed(
            error: kernelOutcome.reason,
            message: kernelOutcome.message,
          );

        case PlanningFailed():
          // IS-P08/P10: surface the real cause; record structured diagnostics.
          final requestId = _diagnostics.nextRequestId();
          _diagnostics.record(
            CreationDiagnostic(
              requestId: requestId,
              stage: CreationStage.planning,
              errorType: 'PlanningFailed',
              errorMessage: kernelOutcome.error,
              retryable: true,
              userRecoverable: true,
            ),
          );
          _logger?.error(
            LogCategory.creation,
            'planning failed: ${kernelOutcome.error}',
            requestId: requestId,
          );
          if (kernelOutcome.stackTrace != null) {
            _logger?.debug(
              LogCategory.creation,
              'planning stack: ${_firstFrames(kernelOutcome.stackTrace!)}',
            );
          }
          return CreationFailed(
            error: kernelOutcome.error,
            message: 'Could not plan this app: ${kernelOutcome.error}',
          );
      }
    } catch (e) {
      final safe = e is ProviderException ? e.message : null;
      _logger?.error(
        LogCategory.creation,
        'routing threw: ${e.runtimeType}${safe == null ? '' : ' — $safe'}',
      );
      return CreationFailed(
        error: e.toString(),
        message: safe ?? 'Something went wrong',
      );
    }
  }

  /// The top frames of a stack trace, which is where the cause is.
  ///
  /// Whole traces are hundreds of lines and unreadable in the on-device log;
  /// the first few name the failing call.
  static String _firstFrames(StackTrace stack, {int count = 4}) =>
      const LineSplitter().convert(stack.toString()).take(count).join(' | ');

  /// Convenience: create from expression string.
  Future<CreationResult> createFromExpression(
    String expression, {
    String? referenceUrl,
    List<String>? referenceUrls,
    bool autoDiscoverKnowledge = false,
    bool useCompilerPipeline = false,
  }) async {
    return createFromIntent(
      Intent.create(expression: expression),
      referenceUrl: referenceUrl,
      referenceUrls: referenceUrls,
      autoDiscoverKnowledge: autoDiscoverKnowledge,
      useCompilerPipeline: useCompilerPipeline,
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
  Future<(List<KnowledgeResource>, List<SoftwareRecommendation>)>
  _acquireSoftwareCognitionSeeds(List<String> urls) async {
    if (urls.isEmpty || _softwareCognition == null) {
      return (const <KnowledgeResource>[], const <SoftwareRecommendation>[]);
    }

    final soundResults = <RepositoryCognitionResult>[];
    for (final url in urls) {
      try {
        final result = await _softwareCognition.engine
            .understandRepositoryFromUrl(
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
        if (_softwareCognition.toKnowledgeResource(result) case final resource?)
          resource,
    ];

    // Real multi-source corroboration (Implementation Milestone R15) —
    // reuses SoftwareReasoner.reasonAboutRepositories unchanged (V11).
    // With a single sound source this still returns recommendations, but
    // every one is `accepted: false` (minSupportingCandidates defaults to
    // 2) — filtered out below, matching R14's documented "single source
    // can never satisfy the acceptance gate" finding exactly.
    final candidates = soundResults.map((r) => r.model).toList();
    final corroboratingRecommendations = _softwareCognition.reasoner
        .reasonAboutRepositories(candidates)
        .where((r) => r.accepted)
        .toList();

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
    bool useCompilerPipeline = false,
  }) async {
    _state = CreationState.creating;

    try {
      // Compiler Pipeline (Implementation Milestone R19) — opt-in only.
      // Falls back to the legacy path below whenever the compiler pipeline
      // has nothing to generate or its output fails the SAME
      // ExperiencePackageValidator the legacy package must also pass —
      // the flag can never silently break creation.
      ExperiencePackage? package;
      if (useCompilerPipeline &&
          canonicalImplementationModel != null &&
          canonicalImplementationModel.entities.isNotEmpty) {
        final outcome = runCompilerPipeline(
          canonicalImplementationModel,
          id: specification.id,
          name: specification.name,
        );
        if (outcome.succeeded &&
            ExperiencePackageValidator.validate(outcome.package!).isValid) {
          package = outcome.package;
        }
      }

      if (package == null) {
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

        // IS-P09: bounded deterministic repair for missing capabilities,
        // then structural + semantic validation. No LLM repair loop.
        _state = CreationState.validating;
        var candidate = creationResult.package;
        var requiredCaps = blueprint != null
            ? const AppCapabilityInferrer().infer(
                blueprint: blueprint,
                intent: intent,
              )
            : candidate.manifest.requiredCapabilities.toSet();
        final repair = const DeterministicCapabilityRepair().repair(
          package: candidate,
          requiredCapabilities: requiredCaps,
          blueprint: blueprint,
        );
        candidate = repair.package;
        if (repair.repaired) {
          _logger?.info(
            LogCategory.creation,
            'deterministic repair applied: ${repair.appliedFixes.join(', ')}',
          );
        }

        // IS-P12: USER_INTENT_MUST_SURVIVE_PLANNING — reject unrelated products.
        var compat = const IntentPreservationValidator().validate(
          rawPrompt: intent.expression,
          package: candidate,
          requiredCapabilities: requiredCaps,
        );
        if (!compat.isCompatible) {
          _logger?.info(
            LogCategory.creation,
            'intent mismatch: ${compat.reason} — attempting safe re-plan',
          );
          if (compat.requested == IntentPurpose.timing) {
            requiredCaps = {
              ...requiredCaps.where((c) => c != AppCapabilityIds.calculation),
              AppCapabilityIds.timers,
              AppCapabilityIds.input,
              AppCapabilityIds.resultDisplay,
            };
            candidate = const TimingInterfaceFactory().applyToPackage(
              candidate,
              name: experienceDisplayName(
                generatedName: candidate.manifest.name,
                userIntent: intent.expression,
              ),
            );
          } else if (compat.requested == IntentPurpose.weather ||
              compat.requested == IntentPurpose.news ||
              compat.requested == IntentPurpose.networkReference) {
            // Generic external data shell: weather, news, stocks, etc.
            requiredCaps = {
              AppCapabilityIds.networkData,
              AppCapabilityIds.input,
              AppCapabilityIds.refresh,
              AppCapabilityIds.loadingState,
              AppCapabilityIds.errorState,
              AppCapabilityIds.resultDisplay,
            };
            candidate = const NetworkReferenceInterfaceFactory()
                .applyToPackage(
              candidate,
              name: experienceDisplayName(
                generatedName: candidate.manifest.name,
                userIntent: intent.expression,
              ),
            );
          }
          if (compat.requested == IntentPurpose.timing ||
              compat.requested == IntentPurpose.weather ||
              compat.requested == IntentPurpose.news ||
              compat.requested == IntentPurpose.networkReference) {
            final hash = ExperiencePackage.computeIntegrityHash(candidate);
            candidate = ExperiencePackage(
              packageVersion: candidate.packageVersion,
              manifest: candidate.manifest,
              interface: candidate.interface,
              behavior: candidate.behavior,
              state: candidate.state,
              data: candidate.data,
              services: candidate.services,
              networkDeclarations: candidate.networkDeclarations,
              capabilityDeclarations: candidate.capabilityDeclarations,
              permissionDeclarations: candidate.permissionDeclarations,
              protection: candidate.protection,
              provenance: candidate.provenance,
              integrity: PackageIntegrity(
                contentHash: hash,
                computedAt: DateTime.now(),
              ),
            );
            compat = const IntentPreservationValidator().validate(
              rawPrompt: intent.expression,
              package: candidate,
              requiredCapabilities: requiredCaps,
            );
          }
          if (!compat.isCompatible) {
            _state = CreationState.failed;
            _diagnostics.record(
              CreationDiagnostic(
                requestId: _diagnostics.nextRequestId(),
                stage: CreationStage.validation,
                errorType: 'IntentMismatch',
                errorMessage: compat.reason,
                retryable: true,
                userRecoverable: true,
              ),
            );
            return CreationFailed(
              error: compat.reason,
              message:
                  'I could not create an app that matches what you asked for '
                  '(${compat.requested.name} vs ${compat.generated.name}). '
                  'Please try rephrasing.',
            );
          }
        }

        // P21: typed IntentContract — rejects scientific→basic, timing→calc, etc.
        final contract = IntentContract.fromRequest(
          CreationRequest.capture(rawPrompt: intent.expression),
        );
        final contractResult = contract.evaluate(
          candidate,
          inferredCapabilities: requiredCaps,
        );
        if (!contractResult.isSatisfied) {
          _state = CreationState.failed;
          _diagnostics.record(
            CreationDiagnostic(
              requestId: _diagnostics.nextRequestId(),
              stage: CreationStage.validation,
              errorType: 'IntentContractViolation',
              errorMessage: contractResult.reason,
              retryable: true,
              userRecoverable: true,
            ),
          );
          return CreationFailed(
            error: contractResult.reason,
            message:
                'I could not create an app that satisfies your request. '
                '${contractResult.reason}',
          );
        }

        final validation = ExperiencePackageValidator.validate(candidate);
        final completeness = const SemanticCompletenessValidator().validate(
          package: candidate,
          requiredCapabilities: requiredCaps,
          blueprint: blueprint,
        );
        final smoke = const ExperienceSmokeValidator().validate(
          candidate,
          requiredCapabilities: requiredCaps,
        );
        if (!validation.isValid || !completeness.isComplete || !smoke.passed) {
          _state = CreationState.failed;
          final reasons = [
            ...validation.errors,
            ...completeness.errorMessages,
            ...smoke.messages,
          ].join('; ');
          _diagnostics.record(
            CreationDiagnostic(
              requestId: _diagnostics.nextRequestId(),
              stage: CreationStage.validation,
              errorType: 'PackageRejected',
              errorMessage: reasons,
              retryable: true,
              userRecoverable: true,
            ),
          );
          _logger?.error(
            LogCategory.creation,
            'package rejected by validator: $reasons',
          );
          return CreationFailed(
            error: reasons,
            message: 'Could not complete this app: $reasons',
          );
        }
        package = candidate;
      }

      // Persist
      _state = CreationState.persisting;
      // IS-R52: the ONE production creation site now records real provenance
      // instead of leaving it blank. This is what makes trust COMPUTED rather
      // than assumed: an Experience authored here is genuinely
      // `createdLocally`, and the classifier derives `local` from that fact
      // rather than from a default nobody chose.
      //
      // The fingerprint reuses the EXISTING `ExperiencePackage.computeIntegrityHash`
      // — R52 introduces no second hashing implementation.
      final createdAt = DateTime.now();
      final metadata = ExperienceMetadataRecord(
        id: package.manifest.experienceId,
        name: package.manifest.name,
        description: package.manifest.description,
        category: package.manifest.category,
        createdAt: createdAt,
        updatedAt: createdAt,
        provenance: ExperienceProvenance.createdLocally(
          at: createdAt,
          fingerprint: ExperienceFingerprint(
            ExperiencePackage.computeIntegrityHash(package),
          ),
        ),
      );
      // IS-R55 TASK 2 — CREATION PREPARES, THE COMMIT FRAMEWORK COMMITS.
      //
      // These were two separate writes with no atomicity: a failure between
      // them left a package with no metadata (or the reverse), which is
      // precisely the torn state R54's repair() was built to clean up. They
      // now land inside ONE transaction, so that state can no longer be
      // produced here.
      final committed = await _commits.commit(
        experienceId: package.manifest.experienceId,
        origin: CommitOrigin.creation,
        package: package,
        metadata: metadata,
      );
      if (!committed.succeeded) {
        return CreationFailed(
          error: committed.error ?? 'commit failed',
          message: "I couldn't save that app.",
        );
      }

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
            engineeringSummary: engineeringPlan == null
                ? null
                : EngineeringMemorySummary.summarize(engineeringPlan),
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
      // A classified provider failure already reads as a user instruction;
      // anything else stays redacted, because raw exception text is not a
      // message and may carry content this app has no business displaying.
      final safe = e is ProviderException ? e.message : null;
      _logger?.error(
        LogCategory.creation,
        'creation threw: ${e.runtimeType}${safe == null ? '' : ' — $safe'}',
      );
      return CreationFailed(
        error: e.toString(),
        message: safe ?? 'Could not complete this app',
      );
    }
  }

  void reset() {
    _state = CreationState.idle;
  }
}
