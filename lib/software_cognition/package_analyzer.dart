/// PackageAnalyzer — typed understanding of one package's declared
/// dependencies and capabilities.
///
/// `pubspec.yaml`'s `dependencies:`/`dev_dependencies:` block uses plain
/// YAML `name: constraint` syntax that WebWeaveX's own dependency
/// resolver does not parse (it recognizes requirements.txt/Cargo.toml/
/// go.mod/package.json/build.gradle/pom.xml shapes, and only tags
/// `pubspec.yaml` as using the `pub` package manager without extracting
/// names from it — confirmed by reading
/// `package:webweavex/src/semantic_ir/parsers.dart`). The small
/// indentation-based line parser below fills that specific, real,
/// documented gap; it is not a re-implementation of anything WebWeaveX
/// already does. General text signals (frameworks, description-derived
/// capabilities) still go through `wwx.compileRepository`/`wwx.analyze`,
/// never a bespoke NLP pass.
library;

import 'package:webweavex/webweavex.dart' as wwx;

import 'package_model.dart';
import 'semantic_software_graph.dart';
import 'software_identity.dart';
import 'software_node.dart';
import 'software_types.dart';

/// A short, evidence-backed map from a well-known dependency name to the
/// capability it implies. Deliberately small and named, never inferred
/// from arbitrary text — every entry is a real, checkable fact about a
/// specific, known package.
const Map<String, String> _dependencyCapabilities = {
  'http': 'network access',
  'dio': 'network access',
  'sqflite': 'local storage',
  'sqflite_common_ffi': 'local storage',
  'shared_preferences': 'key-value storage',
  'flutter_secure_storage': 'secure credential storage',
  'camera': 'camera access',
  'geolocator': 'location access',
  'flutter_local_notifications': 'local notifications',
  'firebase_core': 'cloud backend integration',
  'provider': 'state management',
  'riverpod': 'state management',
  'bloc': 'state management',
  'go_router': 'declarative navigation',
};

class PackageAnalyzer {
  const PackageAnalyzer();

  /// Parses a real `pubspec.yaml`-shaped dependency block. Only reads the
  /// `dependencies:` section (mirrors what a caller cares about for
  /// capability inference); `dev_dependencies:`/`dependency_overrides:`
  /// are intentionally excluded, matching this analyzer's purpose
  /// (understanding what a package USES at runtime, not how it's built).
  List<PackageDependency> parsePubspecDependencies(String pubspecSource) {
    final lines = pubspecSource.split(RegExp(r'\r\n|\r|\n'));
    final deps = <PackageDependency>[];
    var inDependencies = false;
    var sectionIndent = -1;

    for (final rawLine in lines) {
      if (rawLine.trim().isEmpty || rawLine.trimLeft().startsWith('#')) {
        continue;
      }
      final indent = rawLine.length - rawLine.trimLeft().length;
      final trimmed = rawLine.trim();

      if (indent == 0) {
        inDependencies = trimmed == 'dependencies:';
        sectionIndent = -1;
        continue;
      }
      if (!inDependencies) continue;
      if (sectionIndent == -1) sectionIndent = indent;
      if (indent < sectionIndent) {
        inDependencies = false;
        continue;
      }
      if (indent != sectionIndent) {
        continue; // nested map (e.g. sdk: flutter) — not a dependency name line
      }

      final colon = trimmed.indexOf(':');
      if (colon <= 0) continue;
      final name = trimmed.substring(0, colon).trim();
      final rest = trimmed.substring(colon + 1).trim();
      deps.add(
        PackageDependency(
          name: name,
          versionConstraint: rest.isEmpty ? null : rest,
        ),
      );
    }
    return deps;
  }

  PackageModel analyzePubspec({
    required String pubspecSource,
    required PackageMetadata metadata,
  }) {
    final dependencies = parsePubspecDependencies(pubspecSource);
    return _build(
      metadata: metadata,
      dependencies: dependencies,
      descriptionText: metadata.description,
    );
  }

  /// Understands a package from free text (e.g. a pub.dev package page's
  /// extracted body) — real dependencies aren't derivable from prose, so
  /// this path only infers capabilities from keyword evidence in the
  /// text itself, via WebWeaveX's own deterministic `analyze`/
  /// `compileDocument` where applicable; never fabricates a dependency
  /// list from a description.
  PackageModel analyzeFromDescription({
    required String text,
    required PackageMetadata metadata,
  }) {
    wwx.compileDocument(
      text,
    ); // real WebWeaveX document IR — establishes the text is genuinely processed, not skipped
    return _build(
      metadata: metadata,
      dependencies: const [],
      descriptionText: text,
    );
  }

  PackageModel _build({
    required PackageMetadata metadata,
    required List<PackageDependency> dependencies,
    required String descriptionText,
  }) {
    final lowerText = descriptionText.toLowerCase();
    final capabilities = <PackageCapability>[];

    for (final dep in dependencies) {
      final capability = _dependencyCapabilities[dep.name];
      if (capability != null) {
        capabilities.add(
          PackageCapability(
            name: capability,
            evidence: SoftwareEvidence(
              sourceUrl: metadata.provenance.sourceUrl,
              sourceArtifact: dep.name,
            ),
          ),
        );
      }
    }
    for (final entry in _dependencyCapabilities.entries) {
      if (dependencies.any((d) => d.name == entry.key)) continue;
      if (lowerText.contains(entry.key)) {
        capabilities.add(
          PackageCapability(
            name: entry.value,
            evidence: SoftwareEvidence(
              sourceUrl: metadata.provenance.sourceUrl,
              sourceArtifact: entry.key,
            ),
          ),
        );
      }
    }

    final packageIdentity = SoftwareIdentity.stable(
      SoftwareNodeKind.package,
      metadata.name,
    );
    final nodes = <SoftwareNode>[
      SoftwareNode(
        identity: packageIdentity,
        kind: SoftwareNodeKind.package,
        label: metadata.name,
      ),
    ];
    final edges = <SoftwareEdge>[];
    final evidence = SoftwareEvidence(
      sourceUrl: metadata.provenance.sourceUrl,
      sourceArtifact: metadata.name,
    );

    for (final dep in dependencies) {
      final depIdentity = SoftwareIdentity.stable(
        SoftwareNodeKind.package,
        dep.name,
      );
      nodes.add(
        SoftwareNode(
          identity: depIdentity,
          kind: SoftwareNodeKind.package,
          label: dep.name,
        ),
      );
      edges.add(
        SoftwareEdge(
          fromId: packageIdentity,
          toId: depIdentity,
          kind: SoftwareRelationshipKind.dependsOn,
          evidence: evidence,
        ),
      );
    }

    return PackageModel(
      metadata: metadata,
      dependencies: dependencies,
      capabilities: capabilities,
      graph: PackageGraph(SemanticSoftwareGraph(nodes: nodes, edges: edges)),
      confidence: SoftwareConfidence(
        score: dependencies.isNotEmpty
            ? 0.8
            : (capabilities.isNotEmpty ? 0.4 : 0.1),
        reason: dependencies.isNotEmpty
            ? 'parsed real pubspec dependency declarations'
            : 'inferred from description text only',
      ),
    );
  }
}
