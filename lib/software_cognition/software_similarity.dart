/// SoftwareSimilarity — deterministic comparison between two acquired
/// software understandings. Every score is a plain, explainable ratio
/// (Jaccard overlap over real, already-extracted facts) — never a fuzzy
/// or model-driven judgment, matching the milestone's "everything
/// deterministic" requirement for the similarity engine.
library;

import 'package_model.dart';
import 'repository_model.dart';
import 'software_identity.dart';

class SoftwareSimilarityReport {
  final double dependencySimilarity;
  final double capabilitySimilarity;
  final double structuralSimilarity;

  const SoftwareSimilarityReport({
    required this.dependencySimilarity,
    required this.capabilitySimilarity,
    required this.structuralSimilarity,
  });

  /// A single overall score — the mean of the three dimensions, never a
  /// hidden weighting scheme.
  double get overall =>
      (dependencySimilarity + capabilitySimilarity + structuralSimilarity) / 3;
}

class SoftwareSimilarity {
  const SoftwareSimilarity();

  double _jaccard(Iterable<String> a, Iterable<String> b) =>
      SoftwareFingerprint(
        a.toList(),
      ).similarityTo(SoftwareFingerprint(b.toList()));

  double repositorySimilarity(RepositoryModel a, RepositoryModel b) =>
      SoftwareSimilarityReport(
        dependencySimilarity: _jaccard(a.dependencies, b.dependencies),
        capabilitySimilarity: _jaccard(a.frameworks, b.frameworks),
        structuralSimilarity: _jaccard(
          a.graph.graph.nodes.map((n) => n.kind.name),
          b.graph.graph.nodes.map((n) => n.kind.name),
        ),
      ).overall;

  SoftwareSimilarityReport compareRepositories(
    RepositoryModel a,
    RepositoryModel b,
  ) => SoftwareSimilarityReport(
    dependencySimilarity: _jaccard(a.dependencies, b.dependencies),
    capabilitySimilarity: _jaccard(a.frameworks, b.frameworks),
    structuralSimilarity: _jaccard(
      a.graph.graph.nodes.map((n) => n.kind.name),
      b.graph.graph.nodes.map((n) => n.kind.name),
    ),
  );

  SoftwareSimilarityReport comparePackages(PackageModel a, PackageModel b) =>
      SoftwareSimilarityReport(
        dependencySimilarity: _jaccard(
          a.dependencies.map((d) => d.name),
          b.dependencies.map((d) => d.name),
        ),
        capabilitySimilarity: _jaccard(
          a.capabilities.map((c) => c.name),
          b.capabilities.map((c) => c.name),
        ),
        structuralSimilarity: _jaccard(
          a.graph.graph.nodes.map((n) => n.kind.name),
          b.graph.graph.nodes.map((n) => n.kind.name),
        ),
      );

  /// Workflow similarity compares two acquired execution-flow entrypoint
  /// sets — a real, bounded proxy for "do these two repositories perform
  /// similar high-level workflows", never a claim of behavioral
  /// equivalence.
  double workflowSimilarity(
    List<String> entrypointsA,
    List<String> entrypointsB,
  ) => _jaccard(entrypointsA, entrypointsB);
}
