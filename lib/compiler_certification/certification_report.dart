/// Certification report types — Implementation Milestone R23. Every
/// aggregate here is a real, deterministic function of the per-fixture
/// `EquivalenceReport`s the EXISTING, unmodified `EquivalenceComparator`
/// (R19-R22) already produces — never a second scoring engine, never an
/// invented number.
library;

import '../compiler_integration/equivalence_report.dart';

/// One fixture's real result: its category label, the real
/// `EquivalenceReport` `EquivalenceComparator.compare()` produced, and a
/// real determinism re-check (both pipelines run twice on the same
/// input — the same pattern R19's own tests use, since no
/// `checkDeterminism` method exists on the comparator to call).
class FixtureCertification {
  final String category;
  final EquivalenceReport report;
  final bool legacyDeterministic;
  final bool compilerDeterministic;

  const FixtureCertification({
    required this.category,
    required this.report,
    required this.legacyDeterministic,
    required this.compilerDeterministic,
  });
}

/// Corpus-level aggregate — every field is a plain, documented formula
/// over [fixtures], never a hand-waved constant.
class CertificationReport {
  final List<FixtureCertification> fixtures;

  const CertificationReport({required this.fixtures});

  /// Mean per-fixture `compatibilityScore` — the same real, itemized
  /// metric `EquivalenceReport` already defines, averaged across the
  /// corpus.
  double get structuralEquivalence => fixtures.isEmpty
      ? 0.0
      : fixtures
                .map((f) => f.report.compatibilityScore)
                .reduce((a, b) => a + b) /
            fixtures.length;

  /// Fraction of fixtures with zero real, named behavior differences
  /// (`EquivalenceReport.behaviorDifferences`, e.g. derived-value node
  /// count mismatches — R20's own documented, expected gap).
  double get behaviorEquivalence =>
      _fraction((f) => f.report.behaviorDifferences.isEmpty);

  /// Fraction of fixtures whose `navigationShapeMatch` dimension passed
  /// (both packages agree on none-vs-bottomNavigation) — a real,
  /// already-checked dimension name, read back out of
  /// `dimensionsPassed`/`dimensionsChecked`, never re-derived.
  double get navigationEquivalence => _fraction(
    (f) => f.report.dimensionsPassed.contains('navigationShapeMatch'),
  );

  /// Fraction of fixtures certified with the real R22 identity-aware
  /// comparison active (`screenIdentityCoverage` present among the
  /// dimensions checked — only true when a fixture's `legacyBlueprint`/
  /// `compilerModel` were supplied to `compare()`).
  double get identityCoverage => _fraction(
    (f) => f.report.dimensionsChecked.contains('screenIdentityCoverage'),
  );

  /// Fraction of fixtures whose `sharedFieldMetadataParity` dimension
  /// (R20) passed.
  double get fieldMetadataCoverage => _fraction(
    (f) => f.report.dimensionsPassed.contains('sharedFieldMetadataParity'),
  );

  /// Fraction of fixtures whose `screenCountParity` dimension (R21 view
  /// coverage) passed.
  double get viewCoverage =>
      _fraction((f) => f.report.dimensionsPassed.contains('screenCountParity'));

  /// Fraction of fixtures where BOTH pipelines independently re-ran
  /// deterministic.
  double get determinismRate =>
      _fraction((f) => f.legacyDeterministic && f.compilerDeterministic);

  /// Real, documented formula: the unweighted mean of the six equivalence
  /// dimensions above plus the determinism rate — a transparent, equally
  /// weighted average, never a black-box constant. This is a READINESS
  /// signal for a future milestone's own explicit compiler-by-default
  /// decision, never itself a decision to flip that default.
  double get migrationReadinessScore =>
      (structuralEquivalence +
          behaviorEquivalence +
          navigationEquivalence +
          identityCoverage +
          fieldMetadataCoverage +
          viewCoverage +
          determinismRate) /
      7;

  /// Same value as [migrationReadinessScore] today — kept as a distinct,
  /// separately-named field per R23's own "Confidence Score" ask, so a
  /// future milestone can diverge the two formulas (e.g. weighting corpus
  /// coverage breadth) without an API break.
  double get confidenceScore => migrationReadinessScore;

  /// Every real, named difference across the whole corpus, deduplicated —
  /// the union of every fixture's `missingComponents`/`extraComponents`/
  /// `behaviorDifferences`/`capabilityDifferences`, never summarized away.
  List<String> get knownDifferences {
    final all = <String>{};
    for (final f in fixtures) {
      all.addAll(
        f.report.missingComponents.map((c) => '${f.category}: missing $c'),
      );
      all.addAll(
        f.report.extraComponents.map((c) => '${f.category}: extra $c'),
      );
      all.addAll(
        f.report.behaviorDifferences.map(
          (d) => '${f.category}: ${d.category} — ${d.description}',
        ),
      );
      all.addAll(
        f.report.capabilityDifferences.map(
          (d) => '${f.category}: ${d.category} — ${d.description}',
        ),
      );
    }
    return all.toList()..sort();
  }

  double _fraction(bool Function(FixtureCertification) predicate) {
    if (fixtures.isEmpty) return 0.0;
    return fixtures.where(predicate).length / fixtures.length;
  }

  Map<String, dynamic> toJson() => {
    'fixtureCount': fixtures.length,
    'structuralEquivalence': structuralEquivalence,
    'behaviorEquivalence': behaviorEquivalence,
    'navigationEquivalence': navigationEquivalence,
    'identityCoverage': identityCoverage,
    'fieldMetadataCoverage': fieldMetadataCoverage,
    'viewCoverage': viewCoverage,
    'determinismRate': determinismRate,
    'migrationReadinessScore': migrationReadinessScore,
    'confidenceScore': confidenceScore,
    'perFixture': {
      for (final f in fixtures) f.category: f.report.compatibilityScore,
    },
  };
}
