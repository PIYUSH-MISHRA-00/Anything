/// EvolutionCoordinator — Modification Integration: User Request +
/// Evolution Proposal -> Merged Candidate -> Review -> Approval ->
/// Execution. The application-facing orchestrator, mirroring
/// ExperienceModificationCoordinator's role exactly, and deliberately
/// reusing its result types rather than inventing parallel ones.
///
/// A proposal only ever reaches execution through this explicit,
/// separate call — nothing in EvolutionEngine's roadmap planning ever
/// marks a proposal executable on its own, matching this milestone's
/// "Do NOT automatically execute" directive.
library;

import '../app/experience_commit.dart';
import '../app/experience_modification_coordinator.dart';
import '../creation/modification/experience_modification_spec.dart';
import '../creation/modification/modification_engine.dart';
import '../storage/activity_repository.dart';
import '../storage/sqlite_experience_repository.dart';
import 'evolution_candidate.dart';
import 'evolution_executor.dart';
import 'evolution_validator.dart';

export '../app/experience_modification_coordinator.dart'
    show ModificationCoordinatorResult, ModificationCoordinatorSucceeded, ModificationCoordinatorFailed;

class EvolutionCoordinator {
  final SqliteExperienceRepository _repository;
  final ActivityRepository _activity;
  final EvolutionExecutor _executor;
  final EvolutionValidator _validator;

  /// The ONE commit owner (IS-R55). Evolution EVOLVES; it does not persist.
  final ExperienceCommitFramework _commits;

  EvolutionCoordinator({
    SqliteExperienceRepository? repository,
    ActivityRepository? activity,
    EvolutionExecutor? executor,
    EvolutionValidator? validator,
    ExperienceCommitFramework? commitFramework,
  }) : _repository = repository ?? SqliteExperienceRepository(),
       _commits = commitFramework ??
           ExperienceCommitFramework(repository: repository ?? SqliteExperienceRepository()),
       _activity = activity ?? ActivityRepository(),
       _executor = executor ?? EvolutionExecutor(),
       _validator = validator ?? const EvolutionValidator();

  /// Merges an optional user objective with a roadmap proposal into one
  /// ExperienceModificationSpec, reviews/compiles it, and executes it
  /// through the existing ModificationEngine — never a second engine.
  Future<ModificationCoordinatorResult> applyProposal({
    required String experienceId,
    required EvolutionProposal proposal,
    String? userObjective,
  }) async {
    final metadata = await _repository.getMetadata(experienceId);
    if (metadata == null) {
      return const ModificationCoordinatorFailed(message: 'App not found');
    }
    final currentPackage = await _repository.getPackage(experienceId);
    if (currentPackage == null) {
      return const ModificationCoordinatorFailed(message: 'App data not found');
    }

    final approvedProposal = EvolutionProposal(
      candidate: proposal.candidate,
      phase: proposal.phase,
      reviewDecision: proposal.reviewDecision,
      approvedForExecution: true,
    );

    final plan = _executor.compile(approvedProposal, experienceId, currentPackage.manifest.version);
    switch (plan) {
      case EvolutionNotExecutable():
        return ModificationCoordinatorFailed(message: plan.reason);
      case EvolutionExecutable():
        final spec = userObjective == null ? plan.spec : _mergeWithUserObjective(plan.spec, userObjective);
        final result = await _executor.execute(currentPackage, spec);

        switch (result) {
          case ModificationReady():
            final validation = _validator.validate(result.updatedPackage);
            if (!validation.isValid) {
              return const ModificationCoordinatorFailed(message: "I couldn't apply that change.");
            }
            // IS-R55 Task 4 — evolution prepares, the commit framework commits.
            await _commits.commit(
              experienceId: result.updatedPackage.manifest.experienceId,
              origin: CommitOrigin.evolution,
              package: result.updatedPackage,
            );
            await _activity.record(
              ActivityEvent(
                id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
                type: 'evolved',
                experienceId: experienceId,
                experienceName: metadata.name,
                message: 'Applied evolution proposal to ${metadata.name}: ${proposal.candidate.opportunity.description}',
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
          case ModificationUnsupported():
            return const ModificationCoordinatorFailed(message: "I couldn't apply that change.");
        }
    }
  }

  ExperienceModificationSpec _mergeWithUserObjective(ExperienceModificationSpec base, String userObjective) {
    return ExperienceModificationSpec(
      targetExperienceId: base.targetExperienceId,
      basePackageVersion: base.basePackageVersion,
      objective: '${base.objective}; also requested: $userObjective',
      operations: base.operations,
      requiredCapabilities: base.requiredCapabilities,
      requiredPermissions: base.requiredPermissions,
      params: base.params,
    );
  }
}
