/// Generation Result & Diagnostics — Implementation Milestone R10. Real,
/// typed, structured output of a [Generator] run — never a bare string
/// dump. `GenerationDiagnostic` covers warnings/errors/info/performance/
/// skipped-features/unsupported-concepts/version-compatibility as one
/// real, closed, typed vocabulary (never free-text-only).
library;

import 'artifact.dart';

enum DiagnosticSeverity { info, warning, error }

/// What KIND of thing a diagnostic is reporting — real, closed
/// vocabulary matching the spec's own "Generation Diagnostics" list
/// exactly (warnings/errors/information/performance/skipped
/// features/unsupported concepts/version compatibility).
enum DiagnosticCategory { general, performance, skippedFeature, unsupportedConcept, versionCompatibility }

/// One real, structured diagnostic — never a raw exception string
/// leaking through (matches this codebase's established
/// `lib/diagnostics/error_report.dart` philosophy: real category, real
/// safe message, optional real reference back to what it's about).
class GenerationDiagnostic {
  final DiagnosticSeverity severity;
  final DiagnosticCategory category;
  final String message;
  final String? relatedId;

  const GenerationDiagnostic({required this.severity, required this.category, required this.message, this.relatedId});
}

/// One real, named, language-neutral dependency a generated artifact set
/// needs — e.g. `DependencyReference(name: 'http-client', versionConstraint: '>=1.0.0')`
/// — never a `package.json`/`pubspec.yaml`/`requirements.txt`-specific
/// shape. A future real language generator maps this onto its own real
/// ecosystem's manifest format; this framework never does that mapping
/// itself.
class DependencyReference {
  final String name;
  final String versionConstraint;

  const DependencyReference({required this.name, this.versionConstraint = '*'});
}

class DependencyManifest {
  final List<DependencyReference> dependencies;

  const DependencyManifest({this.dependencies = const []});

  static const DependencyManifest empty = DependencyManifest();
}

/// The real, typed, complete output of one [Generator.generate] call.
class GenerationResult {
  final List<ArtifactGroup> artifactGroups;
  final List<GenerationDiagnostic> diagnostics;
  final DependencyManifest dependencyManifest;

  const GenerationResult({
    this.artifactGroups = const [],
    this.diagnostics = const [],
    this.dependencyManifest = DependencyManifest.empty,
  });

  bool get hasErrors => diagnostics.any((d) => d.severity == DiagnosticSeverity.error);

  List<Artifact> get allArtifacts => [for (final g in artifactGroups) ...g.artifacts];
}
