/// CompilerPipelineRunner — Implementation Milestone R19. The one, real
/// place `BuildGraphBuilder` (R11) -> `GenerationPipeline` (R10) ->
/// `RuntimeExperienceGenerator` (R13) get invoked outside of tests —
/// REALITY before this milestone: grepping the whole `lib/` tree for
/// `GenerationPipeline(`/`BuildGraphBuilder(`/`RuntimeExperienceGenerator(`
/// returns exactly one hit each, their own defining file. Never a second
/// compiler, never a reimplementation — this is a thin, real caller of the
/// existing, unmodified pipeline, mirroring `GenerationPipeline.run`'s own
/// "thin dispatch, no reasoning" shape.
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

/// Runs the real, existing, unmodified compiler chain end-to-end for one
/// [CanonicalImplementationModel] and decodes its one aggregate artifact
/// (R13) back into a real [ExperiencePackage] — zero new AI call, zero new
/// upstream dependency, zero change to any of the three pipeline stages.
CompilerPipelineOutcome runCompilerPipeline(CanonicalImplementationModel model, {required String id, required String name}) {
  final stopwatch = Stopwatch()..start();
  final buildGraph = const BuildGraphBuilder().build(model);
  const pipeline = GenerationPipeline();
  final result = pipeline.run(
    buildGraph: buildGraph,
    generator: const RuntimeExperienceGenerator(),
    target: GeneratorTarget(id: id, name: name),
  );
  stopwatch.stop();

  if (result.hasErrors || result.allArtifacts.isEmpty) {
    return CompilerPipelineOutcome(package: null, result: result, latency: stopwatch.elapsed);
  }

  final artifact = result.allArtifacts.first;
  final package = ExperiencePackage.fromJson(jsonDecode(artifact.content!) as Map<String, dynamic>);
  return CompilerPipelineOutcome(package: package, result: result, latency: stopwatch.elapsed);
}
