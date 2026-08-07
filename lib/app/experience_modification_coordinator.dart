/// Experience Modification Coordinator — connects product UI to ModificationEngine.
library;

import 'package:anything/app/experience_commit.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_package_diff.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/creation/modification/modification_engine.dart';
import 'package:anything/creation/modification/experience_modification_spec.dart';
import 'package:anything/evolution/evolution_diff_plan.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

/// Typed result for modification.
sealed class ModificationCoordinatorResult {
  const ModificationCoordinatorResult();
}

/// Modification succeeded.
class ModificationCoordinatorSucceeded extends ModificationCoordinatorResult {
  final ExperiencePackage newPackage;
  final String experienceId;
  final String experienceName;
  final String newVersion;

  /// The package that was active immediately before this change was
  /// persisted (Implementation Milestone R6) — `null` for the pre-R6
  /// [modifyExperience] call path (unchanged, backward compatible).
  /// [applyEvolutionPlan] always populates this, since real rollback
  /// requires the exact prior state, not a re-derived one.
  final ExperiencePackage? previousPackage;

  const ModificationCoordinatorSucceeded({
    required this.newPackage,
    required this.experienceId,
    required this.experienceName,
    required this.newVersion,
    this.previousPackage,
  });
}

/// Modification failed.
class ModificationCoordinatorFailed extends ModificationCoordinatorResult {
  final String message;
  const ModificationCoordinatorFailed({required this.message});
}

/// Orchestrates the modification lifecycle.
class ExperienceModificationCoordinator {
  final SqliteExperienceRepository _repository;
  final ActivityRepository _activity;
  final ModificationEngine _engine;
  final WorldModelCoordinator _worldModel;

  /// Optional engineering-memory repository (Implementation Milestone
  /// R5) — null-by-default, matching `_worldModel`'s pre-R1
  /// null-unless-explicitly-injected pattern for a genuinely optional
  /// enrichment: `planEvolution()` degrades gracefully (falls back to
  /// R4's `ExperienceDiff`-only behavior) when absent or when no
  /// engineering memory was ever persisted for the target Experience.
  final EngineeringMemoryRepository? _engineeringMemory;

  /// [worldModel] defaults to a real, freshly-constructed
  /// WorldModelCoordinator when not injected — never null, never
  /// optional-out — so the graph-aware pre-check below always runs for
  /// every real call path (Vision Milestone V10: "No caller should ever
  /// bypass it").
  /// The ONE commit owner (IS-R55). Modification MODIFIES; it does not
  /// persist, and — since R55 — it does not own rollback either. Both
  /// terminate inside the commit framework.
  final ExperienceCommitFramework _commits;

  ExperienceModificationCoordinator({
    SqliteExperienceRepository? repository,
    ActivityRepository? activity,
    WorldModelCoordinator? worldModel,
    EngineeringMemoryRepository? engineeringMemory,
    ExperienceCommitFramework? commitFramework,
  }) : _repository = repository ?? SqliteExperienceRepository(),
       _commits = commitFramework ??
           ExperienceCommitFramework(repository: repository ?? SqliteExperienceRepository()),
       _activity = activity ?? ActivityRepository(),
       _engine = ModificationEngine(),
       _worldModel = worldModel ?? WorldModelCoordinator(),
       _engineeringMemory = engineeringMemory;

  /// Modify an existing Experience.
  Future<ModificationCoordinatorResult> modifyExperience({
    required String experienceId,
    required String modificationExpression,
  }) async {
    // 1. Load current metadata + package
    final metadata = await _repository.getMetadata(experienceId);
    if (metadata == null) {
      return const ModificationCoordinatorFailed(message: 'App not found');
    }

    final currentPackage = await _repository.getPackage(experienceId);
    if (currentPackage == null) {
      return const ModificationCoordinatorFailed(message: 'App data not found');
    }

    // 1.5. Graph-aware pre-check (Vision Milestone V10) — Impact Analysis
    // + Consistency Validation, always run, never bypassed. Honest scope:
    // ImpactAnalyzer answers "what depends on this Experience" (recorded
    // for visibility, never blocking on its own — depended-upon is the
    // normal, expected case, not a defect); GraphConsistency gates
    // outright, since a currently-inconsistent World Graph (a dangling
    // edge, a real structural defect) is a genuine reason to refuse
    // rather than compound it with a modification made against stale
    // information.
    final check = _worldModel.precheckModification(experienceId);
    if (!check.approved) {
      return const ModificationCoordinatorFailed(
        message: "I couldn't verify this app's data is consistent right now. Please try again.",
      );
    }

    // 2. Create ModificationSpec
    final spec = ExperienceModificationSpec(
      targetExperienceId: experienceId,
      basePackageVersion: currentPackage.manifest.version,
      objective: modificationExpression,
      operations: _parseOperations(modificationExpression),
    );

    // 3. Execute ModificationEngine
    final result = await _engine.modify(currentPackage, spec);

    switch (result) {
      case ModificationReady():
        // 4. Validate candidate with full validator
        final validation = ExperiencePackageValidator.validate(
          result.updatedPackage,
        );
        if (!validation.isValid) {
          return const ModificationCoordinatorFailed(
            message: "I couldn't apply that change.",
          );
        }

        // 5. Persist new version
        // IS-R55 Task 3 — modification prepares, the commit framework commits.
        await _commits.commit(
          experienceId: experienceId,
          origin: CommitOrigin.modification,
          package: result.updatedPackage,
        );

        // 5.5. World Model ingestion (Implementation Milestone R4): every
        // ACCEPTED modification updates the canonical, shared World Graph
        // — closing MIS-1 Part 2's finding that `ingestExperience`
        // (outside the bulk-load helper) had zero real call sites.
        // Best-effort and defensive: an ingestion failure must never
        // surface as a modification failure, mirroring R1/R2/R3's
        // `_ingestIntoWorldModelSafely` contract exactly. A REJECTED
        // modification (any earlier `return` above) never reaches this
        // line, so the World Graph is never mutated on rejection —
        // proven directly in this milestone's tests.
        try {
          _worldModel.ingestExperience(metadata, result.updatedPackage);
        } catch (_) {
          // Deliberately swallowed — see comment above.
        }

        // 6. Record activity
        await _activity.record(
          ActivityEvent(
            id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
            type: 'updated',
            experienceId: experienceId,
            experienceName: metadata.name,
            message: 'Updated ${metadata.name}',
            timestamp: DateTime.now(),
          ),
        );

        return ModificationCoordinatorSucceeded(
          newPackage: result.updatedPackage,
          experienceId: experienceId,
          experienceName: metadata.name,
          newVersion: result.updatedPackage.manifest.version,
        );

      case ModificationFailed():
        return const ModificationCoordinatorFailed(
          message: "I couldn't apply that change.",
        );

      case ModificationUnsupported():
        return const ModificationCoordinatorFailed(
          message: "I couldn't apply that change.",
        );
    }
  }

  /// Computes an [EvolutionDiffPlan] for [modificationExpression] against
  /// [experienceId]'s CURRENT package — Implementation Milestone R4's
  /// "Incremental Software Evolution," planning-only. Reuses the exact
  /// same [_parseOperations]/[ModificationEngine.modify] pure-function
  /// path [modifyExperience] already uses (never a duplicate modification
  /// implementation) but STOPS before persistence: no
  /// `_repository.savePackage`, no activity record, no World Model
  /// ingestion. Returns `null` when the Experience doesn't exist or the
  /// candidate modification itself is honestly not computable (mirrors
  /// [modifyExperience]'s own early-return conditions).
  ///
  /// Known limitation, stated honestly (see Implementation Milestone
  /// R5's report): [requirementDiff]/[architectureDiff]/[engineeringDiff]
  /// remain unpopulated — real historical `RequirementGraph`/
  /// `ArchitectureCandidate`/engineering-summary ARE now persisted (R5,
  /// closing R4's "Anything forgets how an Experience was engineered"
  /// finding) and surfaced via [EvolutionDiffPlan.historicalEngineeringMemory],
  /// but computing a genuine diff would require re-deriving a real
  /// "after" state by re-running Requirement/Architecture planning
  /// against the modification — this coordinator patches
  /// `ExperiencePackage` directly and never re-invokes the Kernel's
  /// planning stages, so no non-fabricated "after" exists yet (see
  /// Known Limitations).
  Future<EvolutionDiffPlan?> planEvolution({
    required String experienceId,
    required String modificationExpression,
  }) async {
    final currentPackage = await _repository.getPackage(experienceId);
    if (currentPackage == null) return null;

    final spec = ExperienceModificationSpec(
      targetExperienceId: experienceId,
      basePackageVersion: currentPackage.manifest.version,
      objective: modificationExpression,
      operations: _parseOperations(modificationExpression),
    );

    final result = await _engine.modify(currentPackage, spec);
    if (result is! ModificationReady) return null;

    final experienceDiff = const ExperienceDiffer().diff(currentPackage, result.updatedPackage);

    // Implementation Milestone R5: surface real, persisted engineering
    // history when available — never a fabricated diff (see
    // `HistoricalEngineeringMemory`'s doc comment for why this is
    // history, not requirement/architecture diffs). Best-effort: a load
    // failure must never break planning, matching every other
    // engineering-memory read/write in this codebase.
    HistoricalEngineeringMemory? historicalMemory;
    if (_engineeringMemory != null) {
      try {
        final record = await _engineeringMemory.load(experienceId);
        if (record != null) {
          historicalMemory = HistoricalEngineeringMemory(
            requirementGraph: record.requirementGraph,
            architectureCandidate: record.architectureCandidate,
            engineeringSummary: record.engineeringSummary,
          );
        }
      } catch (_) {
        // Deliberately swallowed — see comment above.
      }
    }

    return const EvolutionDiffPlanBuilder().build(
      experienceId: experienceId,
      experienceDiff: experienceDiff,
      historicalEngineeringMemory: historicalMemory,
      candidatePackage: result.updatedPackage,
    );
  }

  /// Applies a previously-computed [plan] (Implementation Milestone R6:
  /// "Deterministic Runtime Patching") — validates, persists, ingests
  /// into the World Graph on success only, and returns the prior package
  /// so a caller can reload the live `AnythingRuntime`/`ExperienceRenderer`
  /// (the SAME `closeSession()` -> `openExperience()` sequence this
  /// codebase has used for every modification since before Vision
  /// Milestone V1 — see `ExperienceHostScreen._submitModification`; this
  /// method deliberately does NOT touch `AnythingRuntime`/
  /// `ExperienceRenderer` itself, since that existing reload mechanism
  /// already does exactly what's needed) or call [rollback].
  ///
  /// REALITY: [planEvolution] itself only checks `result is ModificationReady`
  /// — it never runs [ExperiencePackageValidator]. Applying a plan without
  /// re-validating here would be a real security gap (a plan computed
  /// against stale state could persist an invalid package). This method
  /// re-validates [EvolutionDiffPlan.candidatePackage] through the exact
  /// same boundary [modifyExperience] already uses — never a bypass.
  Future<ModificationCoordinatorResult> applyEvolutionPlan(EvolutionDiffPlan plan) async {
    final stopwatch = Stopwatch()..start();
    final candidate = plan.candidatePackage;
    if (candidate == null) {
      return const ModificationCoordinatorFailed(message: "This plan has no candidate to apply.");
    }

    final metadata = await _repository.getMetadata(plan.experienceId);
    if (metadata == null) {
      return const ModificationCoordinatorFailed(message: 'App not found');
    }
    final previousPackage = await _repository.getPackage(plan.experienceId);
    if (previousPackage == null) {
      return const ModificationCoordinatorFailed(message: 'App data not found');
    }

    final validation = ExperiencePackageValidator.validate(candidate);
    if (!validation.isValid) {
      return const ModificationCoordinatorFailed(message: "I couldn't apply that change.");
    }

    // IS-R55 Task 3 — modification prepares, the commit framework commits.
    await _commits.commit(
      experienceId: plan.experienceId,
      origin: CommitOrigin.modification,
      package: candidate,
    );

    // World Model ingestion on ACCEPTED evolution only — a rejected plan
    // returns above, before this line is ever reached, so World state is
    // never mutated on failure (mirrors R4's identical, already-tested
    // contract for `modifyExperience`).
    try {
      _worldModel.ingestExperience(metadata, candidate);
    } catch (_) {
      // Deliberately swallowed — a bookkeeping failure must never surface
      // as an evolution failure.
    }

    stopwatch.stop();
    await _activity.record(
      ActivityEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        type: 'updated',
        experienceId: plan.experienceId,
        experienceName: metadata.name,
        message: 'Evolved ${metadata.name}${_summarize(plan.experienceDiff)}',
        timestamp: DateTime.now(),
        durationMs: stopwatch.elapsedMilliseconds,
      ),
    );

    return ModificationCoordinatorSucceeded(
      newPackage: candidate,
      experienceId: plan.experienceId,
      experienceName: metadata.name,
      newVersion: candidate.manifest.version,
      previousPackage: previousPackage,
    );
  }

  /// A real, evidence-backed one-line summary of what changed (Implementation
  /// Milestone R7's "Evolution History" needs a real per-entry summary, not
  /// a bare "Updated X") — built from [plan]'s own already-computed
  /// [EvolutionDiffPlan.experienceDiff] (R4), never fabricated. Empty string
  /// when the diff itself is empty (e.g. a plan applied with no
  /// candidatePackage change detected).
  static String _summarize(ExperienceDiff diff) {
    if (diff.isEmpty) return '';
    final parts = <String>[];
    if (diff.addedScreens.isNotEmpty) parts.add('${diff.addedScreens.length} screen(s) added');
    if (diff.removedScreens.isNotEmpty) parts.add('${diff.removedScreens.length} screen(s) removed');
    if (diff.addedComponents.isNotEmpty) parts.add('${diff.addedComponents.length} component(s) added');
    if (diff.removedComponents.isNotEmpty) parts.add('${diff.removedComponents.length} component(s) removed');
    if (diff.addedCapabilities.isNotEmpty) parts.add('${diff.addedCapabilities.length} capability(ies) added');
    if (diff.behaviorChanged) parts.add('behavior changed');
    if (diff.stateChanged) parts.add('state changed');
    if (diff.dataSchemaChanged) parts.add('data schema changed');
    return parts.isEmpty ? '' : ' (${parts.join(', ')})';
  }

  /// Deterministic rollback (Implementation Milestone R6): restores
  /// [previousPackage] — real prior state already returned by
  /// [applyEvolutionPlan] as `ModificationCoordinatorSucceeded.previousPackage`,
  /// never an arbitrary caller-supplied blob (Security: this cannot be
  /// abused to persist a package that was never actually valid, since
  /// [previousPackage] only ever originates from this coordinator's own
  /// prior, already-validated, already-persisted state). Re-validates
  /// defensively before persisting — cheap, since the package was valid
  /// before, but never assumed. `SqliteExperienceRepository.savePackage()`
  /// has no version history (confirmed by direct source read: `INSERT ...
  /// ConflictAlgorithm.replace` keyed on `experience_id`) — this is why
  /// the caller must hold [previousPackage] rather than this coordinator
  /// attempting to look up "the version before this one" itself.
  Future<ModificationCoordinatorResult> rollback({
    required String experienceId,
    required ExperiencePackage previousPackage,
  }) async {
    final stopwatch = Stopwatch()..start();
    final metadata = await _repository.getMetadata(experienceId);
    if (metadata == null) {
      return const ModificationCoordinatorFailed(message: 'App not found');
    }

    final validation = ExperiencePackageValidator.validate(previousPackage);
    if (!validation.isValid) {
      return const ModificationCoordinatorFailed(message: "I couldn't roll back that change.");
    }

    final currentPackage = await _repository.getPackage(experienceId);

    // IS-R55 Task 9 — EVERY rollback terminates inside the commit framework.
    // This one predates it and already had the right shape (the caller holds
    // the prior package, because the repository keeps no version history);
    // R55 makes it the SAME owner as installation rollback rather than a
    // second implementation that happens to agree.
    await _commits.rollback(
      experienceId: experienceId,
      previousPackage: previousPackage,
    );

    stopwatch.stop();
    await _activity.record(
      ActivityEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        type: 'updated',
        experienceId: experienceId,
        experienceName: metadata.name,
        message: 'Rolled back ${metadata.name}',
        timestamp: DateTime.now(),
        durationMs: stopwatch.elapsedMilliseconds,
      ),
    );

    return ModificationCoordinatorSucceeded(
      newPackage: previousPackage,
      experienceId: experienceId,
      experienceName: metadata.name,
      newVersion: previousPackage.manifest.version,
      previousPackage: currentPackage,
    );
  }

  List<ModificationOperation> _parseOperations(String expression) {
    final lower = expression.toLowerCase();
    final ops = <ModificationOperation>[];

    if (lower.contains('percentage') || lower.contains('percent')) {
      ops.add(
        ModificationOperation(
          type: ModificationType.addUiNode,
          params: {'label': '%', 'action': 'percentage'},
        ),
      );
      ops.add(
        ModificationOperation(
          type: ModificationType.addBehavior,
          params: {'operation': 'percentage'},
        ),
      );
    }

    if (ops.isEmpty) {
      ops.add(
        ModificationOperation(
          type: ModificationType.modifyUiNode,
          params: {'expression': expression},
        ),
      );
    }

    return ops;
  }
}
