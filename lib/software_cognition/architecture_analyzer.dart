/// ArchitectureAnalyzer / StorageAnalyzer — infers coarse architectural
/// layering and storage usage from a repository's already-computed
/// understanding (RepositoryModel). Both are small, documented,
/// deterministic heuristics over already-extracted facts (directory
/// names, declared dependencies) — neither re-parses source or acquires
/// anything.
library;

import 'architecture_model.dart';
import 'repository_model.dart';
import 'semantic_software_graph.dart';
import 'software_identity.dart';
import 'software_node.dart';
import 'software_projection_helpers.dart';
import 'software_types.dart';

/// Common top-level directory names that conventionally indicate an
/// architectural layer — a documented, non-exhaustive heuristic, not a
/// claim of understanding a repository's actual intended architecture.
const Map<String, String> _layerHints = {
  'ui': 'presentation',
  'presentation': 'presentation',
  'view': 'presentation',
  'views': 'presentation',
  'widgets': 'presentation',
  'screens': 'presentation',
  'domain': 'domain',
  'model': 'domain',
  'models': 'domain',
  'entity': 'domain',
  'entities': 'domain',
  'data': 'data',
  'repository': 'data',
  'repositories': 'data',
  'storage': 'data',
  'service': 'service',
  'services': 'service',
  'controller': 'service',
  'controllers': 'service',
};

/// Well-known storage-related dependency names — matched case-
/// insensitively as substrings against already-declared dependencies.
const List<String> _storageDependencyHints = ['sqlite', 'sqflite', 'postgres', 'mongodb', 'mongo', 'redis', 'mysql', 'firebase', 'hive', 'realm'];

class ArchitectureAnalyzer {
  const ArchitectureAnalyzer();

  ArchitectureGraph analyze(RepositoryModel model) {
    final topLevelDirs = model.structure.entries
        .where((e) => e.isDirectory)
        .map((e) => e.path.endsWith('/') ? e.path.substring(0, e.path.length - 1) : e.path)
        .where((dirName) => !dirName.contains('/'))
        .map((dirName) => dirName.toLowerCase())
        .toSet();

    final layers = <String>{};
    for (final dir in topLevelDirs) {
      final hint = _layerHints[dir];
      if (hint != null) layers.add(hint);
    }

    final nodes = layers
        .map((layer) => SoftwareNode(identity: SoftwareIdentity.stable(SoftwareNodeKind.architectureLayer, layer), kind: SoftwareNodeKind.architectureLayer, label: layer))
        .toList();
    return ArchitectureGraph(SemanticSoftwareGraph(nodes: nodes));
  }
}

class StorageAnalyzer {
  const StorageAnalyzer();

  DatabaseGraph analyze(RepositoryModel model) {
    final matches = model.dependencies.where((dep) => _storageDependencyHints.any((hint) => dep.toLowerCase().contains(hint))).toList();
    final nodes = matches
        .map((dep) => SoftwareNode(identity: SoftwareIdentity.stable(SoftwareNodeKind.database, dep), kind: SoftwareNodeKind.database, label: dep))
        .toList();
    return DatabaseGraph(SemanticSoftwareGraph(nodes: nodes));
  }
}

/// Real, typed projections of a repository's already-built
/// SemanticSoftwareGraph by relationship kind — never a second graph
/// engine, just a filtered view.
class DependencyProjections {
  const DependencyProjections();

  DependencyGraph dependencyGraph(RepositoryModel model) =>
      DependencyGraph(projectByRelationship(model.graph.graph, {SoftwareRelationshipKind.dependsOn}));

  ImportGraph importGraph(RepositoryModel model) => ImportGraph(projectByRelationship(model.graph.graph, {SoftwareRelationshipKind.imports}));

  CodeRelationshipGraph codeRelationshipGraph(RepositoryModel model) =>
      CodeRelationshipGraph(projectByRelationship(model.graph.graph, {SoftwareRelationshipKind.calls, SoftwareRelationshipKind.references}));
}
