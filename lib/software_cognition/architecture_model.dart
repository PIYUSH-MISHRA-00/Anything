/// ArchitectureGraph / DatabaseGraph / DependencyGraph / ImportGraph /
/// CodeRelationshipGraph — thin, named wrappers over an
/// architecture-scoped SemanticSoftwareGraph. Kept deliberately simple:
/// each is a real, typed projection of a repository's already-computed
/// SemanticSoftwareGraph, not a second graph engine.
///
/// Note: this `DependencyGraph` is scoped to acquired/understood
/// software (Software Cognition) and is a distinct type from
/// `lib/feature_discovery/dependency_types.dart`'s `DependencyGraph`
/// (which models feature-to-feature dependencies within a design being
/// generated) — the two are never imported unprefixed in the same file.
library;

import 'semantic_software_graph.dart';

class ArchitectureGraph {
  final SemanticSoftwareGraph graph;

  const ArchitectureGraph(this.graph);
}

class DatabaseGraph {
  final SemanticSoftwareGraph graph;

  const DatabaseGraph(this.graph);
}

class AuthenticationPatternGraph {
  final SemanticSoftwareGraph graph;

  const AuthenticationPatternGraph(this.graph);
}

class NavigationPatternGraph {
  final SemanticSoftwareGraph graph;

  const NavigationPatternGraph(this.graph);
}

class RealtimePatternGraph {
  final SemanticSoftwareGraph graph;

  const RealtimePatternGraph(this.graph);
}

class CachingPatternGraph {
  final SemanticSoftwareGraph graph;

  const CachingPatternGraph(this.graph);
}

class DependencyGraph {
  final SemanticSoftwareGraph graph;

  const DependencyGraph(this.graph);
}

class ImportGraph {
  final SemanticSoftwareGraph graph;

  const ImportGraph(this.graph);
}

class CodeRelationshipGraph {
  final SemanticSoftwareGraph graph;

  const CodeRelationshipGraph(this.graph);
}
