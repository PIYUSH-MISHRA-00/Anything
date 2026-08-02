/// Experience Modification Coordinator — connects product UI to ModificationEngine.
library;

import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/creation/modification/modification_engine.dart';
import 'package:anything/creation/modification/experience_modification_spec.dart';
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
  const ModificationCoordinatorSucceeded({
    required this.newPackage,
    required this.experienceId,
    required this.experienceName,
    required this.newVersion,
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

  /// [worldModel] defaults to a real, freshly-constructed
  /// WorldModelCoordinator when not injected — never null, never
  /// optional-out — so the graph-aware pre-check below always runs for
  /// every real call path (Vision Milestone V10: "No caller should ever
  /// bypass it").
  ExperienceModificationCoordinator({
    SqliteExperienceRepository? repository,
    ActivityRepository? activity,
    WorldModelCoordinator? worldModel,
  }) : _repository = repository ?? SqliteExperienceRepository(),
       _activity = activity ?? ActivityRepository(),
       _engine = ModificationEngine(),
       _worldModel = worldModel ?? WorldModelCoordinator();

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
        await _repository.savePackage(result.updatedPackage);

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
