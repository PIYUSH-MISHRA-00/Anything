/// PackageModel and its supporting types — the typed understanding of one
/// acquired package (pub.dev, npm, PyPI, etc). Mirrors RepositoryModel's
/// shape; a package is treated as a small, focused repository whose
/// primary artifact is its declared dependency/capability surface.
library;

import 'semantic_software_graph.dart';
import 'software_provenance.dart';
import 'software_types.dart' show SoftwareConfidence, SoftwareEvidence;

class PackageMetadata {
  final String name;
  final String version;
  final String description;
  final SoftwareProvenance provenance;

  const PackageMetadata({required this.name, required this.version, required this.description, required this.provenance});
}

class PackageDependency {
  final String name;
  final String? versionConstraint;

  const PackageDependency({required this.name, this.versionConstraint});
}

/// A capability the package appears to offer, inferred from its
/// dependency/description text — always evidence-backed, never
/// fabricated from the package name alone.
class PackageCapability {
  final String name;
  final SoftwareEvidence evidence;

  const PackageCapability({required this.name, required this.evidence});
}

class PackageFeature {
  final String name;
  final SoftwareEvidence evidence;

  const PackageFeature({required this.name, required this.evidence});
}

/// Thin, named wrapper over a package-scoped SemanticSoftwareGraph.
class PackageGraph {
  final SemanticSoftwareGraph graph;

  const PackageGraph(this.graph);
}

class PackageModel {
  final PackageMetadata metadata;
  final List<PackageDependency> dependencies;
  final List<PackageCapability> capabilities;
  final List<PackageFeature> features;
  final PackageGraph graph;
  final SoftwareConfidence confidence;

  const PackageModel({
    required this.metadata,
    this.dependencies = const [],
    this.capabilities = const [],
    this.features = const [],
    required this.graph,
    required this.confidence,
  });
}
