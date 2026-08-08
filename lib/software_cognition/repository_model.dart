/// RepositoryModel and its supporting types — the typed understanding of
/// one acquired repository. Every field here is derived from WebWeaveX's
/// own already-computed deterministic repository IR
/// (`compileRepository`/`queryRepository`, see RepositoryAnalyzer) — this
/// file only defines the strongly-typed shape that understanding lands
/// in; it performs no acquisition or parsing itself.
library;

import 'semantic_software_graph.dart';
import 'software_provenance.dart';
import 'software_types.dart' show SoftwareConfidence;

/// One entry in a repository's file/directory listing.
class RepositoryNode {
  final String path;
  final bool isDirectory;
  final String? language;

  const RepositoryNode({
    required this.path,
    required this.isDirectory,
    this.language,
  });
}

/// A structural relationship between two repository-tree entries (e.g.
/// "this file imports that file") — deliberately simple; full
/// per-file cross-reference resolution is out of scope (see
/// RepositoryAnalyzer's documented limitations).
class RepositoryRelationship {
  final String fromPath;
  final String toPath;
  final String kind;

  const RepositoryRelationship({
    required this.fromPath,
    required this.toPath,
    required this.kind,
  });
}

class RepositoryStructure {
  final List<RepositoryNode> entries;
  final List<RepositoryRelationship> relationships;

  const RepositoryStructure({
    this.entries = const [],
    this.relationships = const [],
  });

  bool get hasTests =>
      entries.any((e) => e.path.toLowerCase().contains('test'));
  bool get hasCi => entries.any(
    (e) =>
        e.path.contains('.github/workflows') || e.path.contains('.gitlab-ci'),
  );
  bool get hasDocker => entries.any(
    (e) =>
        e.path.toLowerCase().contains('dockerfile') ||
        e.path.toLowerCase().contains('docker-compose'),
  );
}

class RepositoryMetadata {
  final String name;
  final String description;
  final String primaryLanguage;
  final SoftwareProvenance provenance;

  const RepositoryMetadata({
    required this.name,
    required this.description,
    required this.primaryLanguage,
    required this.provenance,
  });
}

/// A human/LLM-readable digest of a repository's understood purpose and
/// shape — this, not raw source, is what safely flows into a reasoning
/// prompt (see SoftwareCognitionEngine.toKnowledgeResource).
class RepositorySummary {
  final String purpose;
  final String primaryLanguage;
  final int dependencyCount;
  final int entrypointCount;
  final bool hasTests;
  final bool hasCi;
  final bool hasDocker;

  const RepositorySummary({
    required this.purpose,
    required this.primaryLanguage,
    required this.dependencyCount,
    required this.entrypointCount,
    required this.hasTests,
    required this.hasCi,
    required this.hasDocker,
  });

  String toDigestText() {
    final buffer = StringBuffer();
    buffer.writeln('Repository purpose: $purpose');
    buffer.writeln('Primary language: $primaryLanguage');
    buffer.writeln('Declared dependencies: $dependencyCount');
    buffer.writeln('Detected entrypoints: $entrypointCount');
    buffer.writeln(
      'Has tests: $hasTests; CI: $hasCi; containerized: $hasDocker',
    );
    return buffer.toString();
  }
}

/// Thin, named wrapper over a repository-scoped SemanticSoftwareGraph —
/// satisfies the Vision Milestone V11 module list without duplicating
/// SemanticSoftwareGraph's real implementation.
class RepositoryGraph {
  final SemanticSoftwareGraph graph;

  const RepositoryGraph(this.graph);
}

/// The complete, typed understanding of one repository.
class RepositoryModel {
  final RepositoryMetadata metadata;
  final RepositoryStructure structure;
  final List<String> dependencies;
  final List<String> entrypoints;
  final List<String> frameworks;
  final List<String> infraSignals;
  final List<String> classNames;
  final List<String> functionNames;
  final List<String> decorators;
  final RepositorySummary summary;
  final RepositoryGraph graph;
  final SoftwareConfidence confidence;

  const RepositoryModel({
    required this.metadata,
    required this.structure,
    this.dependencies = const [],
    this.entrypoints = const [],
    this.frameworks = const [],
    this.infraSignals = const [],
    this.classNames = const [],
    this.functionNames = const [],
    this.decorators = const [],
    required this.summary,
    required this.graph,
    required this.confidence,
  });
}

/// Input bundle a caller supplies to RepositoryAnalyzer — mirrors the
/// *Context pattern used throughout the Kernel pipeline (ReviewContext,
/// EvolutionContext).
class RepositoryContext {
  final String source;
  final RepositoryMetadata metadata;
  final String path;
  final List<String> files;

  const RepositoryContext({
    required this.source,
    required this.metadata,
    this.path = '',
    this.files = const [],
  });
}
