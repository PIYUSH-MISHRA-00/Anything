/// EquivalenceReport — Implementation Milestone R19. Real, structural
/// comparison between the legacy `CreationEngine` (V3) pipeline's
/// `ExperiencePackage` and the compiler (R9-R13) pipeline's
/// `ExperiencePackage` for the SAME real creation request. Every field
/// here is computed from a real structural diff — never a fabricated
/// "100% equivalent" claim. Real, confirmed, permanent structural
/// differences exist between the two pipelines (see
/// `docs/architecture/COMPILER_PRODUCTION_INTEGRATION.md`, "Known
/// Differences") — this report names them, it does not hide them.
library;

/// One real, named structural gap between the two packages.
class ComponentDifference {
  final String category;
  final String description;

  const ComponentDifference({
    required this.category,
    required this.description,
  });
}

class EquivalenceReport {
  /// Screen ids present in the legacy package but not the compiler one.
  final List<String> missingComponents;

  /// Screen ids present in the compiler package but not the legacy one.
  final List<String> extraComponents;

  final List<ComponentDifference> behaviorDifferences;
  final List<ComponentDifference> capabilityDifferences;

  /// Real wall-clock latency for each pipeline on the SAME input —
  /// `Stopwatch`-measured by the caller, never fabricated.
  final Duration legacyLatency;
  final Duration compilerLatency;

  /// Fraction (0.0-1.0) of real, individually-checked structural
  /// dimensions (see `EquivalenceComparator.compare`'s doc comment for the
  /// exact list) that this specific pair of packages agreed on. NOT a
  /// byte-identical/checksum score — a documented, itemized compatibility
  /// metric.
  final double compatibilityScore;

  /// 1.0 only when BOTH pipelines, independently re-run on the SAME input,
  /// produced structurally identical output (excluding real generation
  /// timestamps) — a real re-check performed by
  /// `EquivalenceComparator.checkDeterminism`, never assumed from R13/R17/
  /// R18's own prior, separate test suites.
  final double determinismScore;

  final List<String> dimensionsChecked;
  final List<String> dimensionsPassed;

  const EquivalenceReport({
    required this.missingComponents,
    required this.extraComponents,
    required this.behaviorDifferences,
    required this.capabilityDifferences,
    required this.legacyLatency,
    required this.compilerLatency,
    required this.compatibilityScore,
    required this.determinismScore,
    required this.dimensionsChecked,
    required this.dimensionsPassed,
  });

  bool get isFullyEquivalent => compatibilityScore == 1.0;
}
