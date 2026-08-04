/// CompilerPipelineRunner — Implementation Milestone R19, generalized
/// Implementation Specification IS-R26. The one, real place
/// `BuildGraphBuilder` (R11) -> `GenerationPipeline` (R10) -> a real
/// `Generator` get invoked outside of tests — REALITY before R19:
/// grepping the whole `lib/` tree for `GenerationPipeline(`/
/// `BuildGraphBuilder(`/`RuntimeExperienceGenerator(` returned exactly one
/// hit each, their own defining file. Never a second compiler, never a
/// reimplementation — this is a thin, real caller of the existing,
/// unmodified pipeline, mirroring `GenerationPipeline.run`'s own "thin
/// dispatch, no reasoning" shape.
///
/// [runGeneratorPipeline] (R26) is the real, generic primitive — any
/// `Generator` implementation, not just `RuntimeExperienceGenerator`,
/// runs through it. [runCompilerPipeline] is now a thin, 100%-backward-
/// compatible wrapper over it (same signature, same behavior, same
/// `ExperiencePackage` decode) — every R19-R25 call site is byte-for-byte
/// unaffected.
library;

import 'dart:convert';

import '../build_graph/universal_build_graph.dart';
import '../creation/experience_package.dart';
import '../generator_framework/generation_pipeline.dart';
import '../generator_framework/generation_result.dart';
import '../generator_framework/generator.dart';
import '../generator_framework/reference/runtime_experience_generator.dart';
import '../implementation_model/canonical_implementation_model.dart';

/// Real outcome of one compiler-pipeline attempt — never a bare nullable
/// package, so a caller can honestly distinguish "not applicable" (empty
/// model) from "produced a package with real diagnostics" from "produced
/// nothing generatable" without re-deriving that from a null.
class CompilerPipelineOutcome {
  final ExperiencePackage? package;
  final GenerationResult result;
  final Duration latency;

  const CompilerPipelineOutcome({required this.package, required this.result, required this.latency});

  bool get succeeded => package != null && !result.hasErrors;
}

/// Real, generic outcome of one [Generator] run through the existing,
/// unmodified `BuildGraphBuilder`/`GenerationPipeline` — never decoded
/// into any particular artifact shape here (that decode is generator-
/// specific, e.g. [runCompilerPipeline]'s own `ExperiencePackage` decode
/// below); this stays a real, generator-agnostic primitive.
class GeneratorPipelineOutcome {
  final GenerationResult result;
  final Duration latency;

  const GeneratorPipelineOutcome({required this.result, required this.latency});
}

/// Runs the real, existing, unmodified compiler chain end-to-end for one
/// [CanonicalImplementationModel] against [generator] — zero new AI call,
/// zero new upstream dependency, zero change to any of the three pipeline
/// stages. [options] threads generator-specific data (e.g. a real
/// `BackendEngineeringPlan`, R26) through `GenerationPipeline.run`'s own
/// already-real `options` parameter — never a new required field on
/// `GeneratorContext` itself.
GeneratorPipelineOutcome runGeneratorPipeline(
  CanonicalImplementationModel model, {
  required Generator generator,
  required String id,
  required String name,
  GeneratorOptions options = GeneratorOptions.empty,
}) {
  final stopwatch = Stopwatch()..start();
  final buildGraph = const BuildGraphBuilder().build(model);
  const pipeline = GenerationPipeline();
  final result = pipeline.run(buildGraph: buildGraph, generator: generator, target: GeneratorTarget(id: id, name: name), options: options);
  stopwatch.stop();
  return GeneratorPipelineOutcome(result: result, latency: stopwatch.elapsed);
}

/// Runtime-Experience-specific: runs [runGeneratorPipeline] against the
/// real, existing `RuntimeExperienceGenerator` (R13) and decodes its one
/// aggregate artifact back into a real [ExperiencePackage]. Behavior
/// unchanged since R19 — every existing caller/test is unaffected.
CompilerPipelineOutcome runCompilerPipeline(CanonicalImplementationModel model, {required String id, required String name}) {
  final outcome = runGeneratorPipeline(model, generator: const RuntimeExperienceGenerator(), id: id, name: name);
  final result = outcome.result;

  if (result.hasErrors || result.allArtifacts.isEmpty) {
    return CompilerPipelineOutcome(package: null, result: result, latency: outcome.latency);
  }

  final artifact = result.allArtifacts.first;
  final package = ExperiencePackage.fromJson(jsonDecode(artifact.content!) as Map<String, dynamic>);
  return CompilerPipelineOutcome(package: package, result: result, latency: outcome.latency);
}
