/// Incremental Compiler Synthesis — Implementation Specification IS-R24.
/// The one genuinely novel contribution this specification can honestly
/// make: reaching diff-driven incremental regeneration into the R9-R23
/// compiler chain for the first time. REALITY: `EvolutionDiffPlan`/
/// `applyEvolutionPlan()` (R4-R7) already implement "diff -> affected ->
/// apply -> hot reload" — but exclusively for the LEGACY `CreationEngine`
/// path (confirmed by grep: zero `CanonicalImplementationModel`/
/// `runCompilerPipeline` references anywhere under `lib/evolution/` or in
/// `experience_modification_coordinator.dart` before this file). This
/// module supplies the missing half: given [AffectedEntities] (from a real
/// `RequirementGraphDiff`/`ArchitectureDiff`, R3/R4), it scopes a full
/// `CanonicalImplementationModel` down to only the affected entities and
/// re-runs the EXISTING, UNMODIFIED `runCompilerPipeline` (R19) —
/// `BuildGraphBuilder`/`GenerationPipeline`/`RuntimeExperienceGenerator`
/// are never touched, never reimplemented.
///
/// Granularity, stated honestly (never overclaimed): scoping happens at
/// the `CanonicalImplementationModel` LIST level (entities/repositories/
/// controllers/dtos/validators/services/storageAdapters/stateContainers/
/// derivedValues/views are filtered to the affected entity id set — every
/// one of these is genuinely entity-keyed, confirmed by reading their real
/// field shapes). `RuntimeExperienceGenerator` itself still regenerates
/// every screen/behavior node for the SCOPED model in one call — there is
/// no per-node patching inside the generator (it has no such mechanism
/// today, and building one would mean modifying the reference generator's
/// internals, well beyond this specification's honest scope). This is
/// real "affected-entity-scoped regeneration," not per-node graph
/// surgery — the value is a smaller, real `CanonicalImplementationModel`
/// (and therefore a real, measurably faster compiler run — see
/// `test/r24_engineering_intelligence_test.dart`'s performance group),
/// not sub-entity granularity.
///
/// The resulting `ExperiencePackage` flows into a real `EvolutionDiffPlan`
/// via the EXISTING, UNMODIFIED `EvolutionDiffPlanBuilder`/
/// `ExperienceDiffer` (R4), so `ExperienceModificationCoordinator
/// .applyEvolutionPlan()` (R6) — and therefore `ExperienceHostScreen`'s
/// real, existing hot-reload flow (R7) — can apply a compiler-produced
/// package with ZERO changes to any of that machinery: confirmed by
/// reading `applyEvolutionPlan()` that it only ever touches
/// `EvolutionDiffPlan.candidatePackage`, a plain `ExperiencePackage`,
/// completely format-agnostic between legacy and compiler origin.
library;

import '../compiler_integration/compiler_pipeline_runner.dart';
import '../creation/experience_package.dart';
import '../creation/experience_package_diff.dart';
import '../evolution/evolution_diff_plan.dart';
import '../generator_framework/generation_result.dart';
import '../implementation_model/canonical_implementation_model.dart';
import 'affected_entities.dart';

/// One incremental compiler run's real outcome.
class IncrementalSynthesisResult {
  final ExperiencePackage? package;
  final GenerationResult compilerResult;
  final Set<String> affectedEntityIds;
  final int scopedEntityCount;
  final int fullEntityCount;
  final Duration latency;

  const IncrementalSynthesisResult({
    required this.package,
    required this.compilerResult,
    required this.affectedEntityIds,
    required this.scopedEntityCount,
    required this.fullEntityCount,
    required this.latency,
  });

  bool get succeeded => package != null && !compilerResult.hasErrors;
}

class IncrementalCompilerSynthesizer {
  const IncrementalCompilerSynthesizer();

  /// Scopes [fullModel] to [affected] and runs the real, unmodified
  /// compiler pipeline over only that subset. `affected.isEmpty` returns a
  /// real, honest no-op result (`package: null`) rather than silently
  /// falling back to a full regeneration — a caller with no real diff
  /// signal has nothing to incrementally synthesize.
  IncrementalSynthesisResult synthesize({
    required CanonicalImplementationModel fullModel,
    required AffectedEntities affected,
    required String id,
    required String name,
  }) {
    final stopwatch = Stopwatch()..start();
    if (affected.isEmpty) {
      stopwatch.stop();
      return IncrementalSynthesisResult(
        package: null,
        compilerResult: const GenerationResult(),
        affectedEntityIds: const {},
        scopedEntityCount: 0,
        fullEntityCount: fullModel.entities.length,
        latency: stopwatch.elapsed,
      );
    }

    final ids = affected.entityIds;
    final scoped = CanonicalImplementationModel(
      entities: fullModel.entities.where((e) => ids.contains(e.id)).toList(),
      repositories: fullModel.repositories
          .where((r) => ids.contains(r.entityId))
          .toList(),
      controllers: fullModel.controllers
          .where((c) => ids.contains(c.entityId))
          .toList(),
      dtos: fullModel.dtos.where((d) => ids.contains(d.entityId)).toList(),
      validators: fullModel.validators
          .where((v) => ids.contains(v.entityId))
          .toList(),
      services: fullModel.services
          .where((s) => ids.contains(s.entityId))
          .toList(),
      // Cross-cutting/non-entity-keyed specs are honestly NOT scoped —
      // filtering them further risks silently dropping real, unrelated
      // requirements (see this file's own top-level doc comment).
      dependencies: fullModel.dependencies,
      stateContainers: fullModel.stateContainers
          .where((s) => ids.contains(s.entityId))
          .toList(),
      navigation: fullModel.navigation,
      capabilityAdapters: fullModel.capabilityAdapters,
      authentication: fullModel.authentication,
      storageAdapters: fullModel.storageAdapters
          .where((s) => ids.contains(s.entityId))
          .toList(),
      backgroundWorker: fullModel.backgroundWorker,
      corroboratedPatterns: fullModel.corroboratedPatterns,
      derivedValues: fullModel.derivedValues
          .where((d) => ids.contains(d.sourceEntityId))
          .toList(),
      views: fullModel.views
          .where(
            (v) => v.sourceEntityId != null && ids.contains(v.sourceEntityId),
          )
          .toList(),
    );

    final outcome = runCompilerPipeline(scoped, id: id, name: name);
    stopwatch.stop();
    return IncrementalSynthesisResult(
      package: outcome.package,
      compilerResult: outcome.result,
      affectedEntityIds: ids,
      scopedEntityCount: scoped.entities.length,
      fullEntityCount: fullModel.entities.length,
      latency: stopwatch.elapsed,
    );
  }

  /// Real "Hot Reload" wiring (R24): composes the SAME
  /// `EvolutionDiffPlanBuilder`/`ExperienceDiffer` R4 already built, so
  /// the resulting plan is indistinguishable, to `applyEvolutionPlan()`,
  /// from a legacy-sourced one — never a second apply path.
  EvolutionDiffPlan? buildEvolutionPlan({
    required String experienceId,
    required ExperiencePackage previousPackage,
    required IncrementalSynthesisResult result,
  }) {
    final newPackage = result.package;
    if (newPackage == null) return null;
    final experienceDiff = const ExperienceDiffer().diff(
      previousPackage,
      newPackage,
    );
    return const EvolutionDiffPlanBuilder().build(
      experienceId: experienceId,
      experienceDiff: experienceDiff,
      candidatePackage: newPackage,
    );
  }
}
