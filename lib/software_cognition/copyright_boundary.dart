/// Copyright / attribution boundary enforcement (Vision Milestone V11).
///
/// Two independent, real, deterministic checks:
///  - CopyrightBoundary: catches a transformed digest that is actually a
///    large verbatim excerpt of the original acquired source — a
///    concrete, checkable signal of "this stopped being transformative,"
///    not a legal copyright determination.
///  - AttributionCompleteness: reports which of License/Source/Author/
///    Repository/Commit/Version a given SoftwareProvenance is actually
///    carrying, so "everything traceable" is a verifiable fact rather
///    than an aspiration nobody checks.
library;

import 'software_provenance.dart';

class CopyrightBoundaryResult {
  final List<String> violations;

  const CopyrightBoundaryResult({this.violations = const []});

  bool get isTransformative => violations.isEmpty;
}

class CopyrightBoundary {
  const CopyrightBoundary();

  /// The minimum verbatim-excerpt length treated as a genuine violation —
  /// short shared substrings (a common word, a package name) are
  /// expected and not a copyright concern.
  static const int _verbatimExcerptThreshold = 200;

  CopyrightBoundaryResult check({required String originalSource, required String digestText}) {
    final violations = <String>[];
    final trimmedDigest = digestText.trim();

    if (originalSource.isNotEmpty &&
        trimmedDigest.length >= _verbatimExcerptThreshold &&
        originalSource.contains(trimmedDigest)) {
      violations.add('digest text is a verbatim excerpt of the original acquired source (${trimmedDigest.length} chars)');
    }

    return CopyrightBoundaryResult(violations: violations);
  }
}

class AttributionCompleteness {
  final List<String> present;
  final List<String> missing;

  const AttributionCompleteness({required this.present, required this.missing});

  bool get isComplete => missing.isEmpty;
}

class AttributionCheck {
  const AttributionCheck();

  AttributionCompleteness evaluate(SoftwareProvenance provenance) {
    final present = <String>[];
    final missing = <String>[];

    void record(String field, bool hasValue) => hasValue ? present.add(field) : missing.add(field);

    record('source', provenance.sourceUrl.isNotEmpty);
    record('author', provenance.author != null && provenance.author!.isNotEmpty);
    record('repository', provenance.repositoryUrl != null && provenance.repositoryUrl!.isNotEmpty);
    record('commit', provenance.commit != null && provenance.commit!.isNotEmpty);
    record('version', provenance.version != null && provenance.version!.isNotEmpty);
    record(
      'license',
      provenance.license.licenseId != null || provenance.license.licenseName != null,
    );

    return AttributionCompleteness(present: present, missing: missing);
  }
}
