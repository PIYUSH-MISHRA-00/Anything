/// Vision V11 — CopyrightBoundary / AttributionCheck / SoftwareReview.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/review_types.dart' show ReviewSeverity;
import 'package:anything/software_cognition/copyright_boundary.dart';
import 'package:anything/software_cognition/package_analyzer.dart';
import 'package:anything/software_cognition/package_model.dart';
import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/software_cognition/software_review.dart';

SoftwareProvenance _fullProvenance() => SoftwareProvenance(
  sourceUrl: 'https://example.com/repo',
  author: 'jane-doe',
  repositoryUrl: 'https://github.com/jane-doe/repo',
  commit: 'abc123',
  version: '1.0.0',
  retrievedAt: DateTime(2026, 8, 2),
  provider: 'test-fixture',
  license: const LicenseMetadata(policy: LicensePolicy.permissiveKnown, licenseId: 'MIT', confidence: 1.0),
);

void main() {
  group('CopyrightBoundary', () {
    test('a real transformed digest (short, distilled) passes clean', () {
      final original = 'def main():\n    return None\n' * 50;
      const digest = 'Repository purpose: fuel log tracker\nPrimary language: python\n';
      final result = const CopyrightBoundary().check(originalSource: original, digestText: digest);
      expect(result.isTransformative, isTrue);
    });

    test('a digest that verbatim-copies a large excerpt of the source is flagged', () {
      final original = 'x' * 500;
      final result = const CopyrightBoundary().check(originalSource: original, digestText: original);
      expect(result.isTransformative, isFalse);
      expect(result.violations, isNotEmpty);
    });

    test('a short shared substring (a word) is never flagged', () {
      final result = const CopyrightBoundary().check(originalSource: 'the quick brown fox', digestText: 'the quick');
      expect(result.isTransformative, isTrue);
    });

    test('empty original source never produces a false violation', () {
      final result = const CopyrightBoundary().check(originalSource: '', digestText: 'some digest text');
      expect(result.isTransformative, isTrue);
    });
  });

  group('AttributionCheck', () {
    test('a fully-populated provenance reports every field present', () {
      final completeness = const AttributionCheck().evaluate(_fullProvenance());
      expect(completeness.isComplete, isTrue);
      expect(completeness.present, containsAll(['source', 'author', 'repository', 'commit', 'version', 'license']));
    });

    test('a minimal provenance honestly reports what is missing — never fabricates it', () {
      final minimal = SoftwareProvenance(
        sourceUrl: 'https://example.com/repo',
        retrievedAt: DateTime(2026, 8, 2),
        provider: 'test-fixture',
        license: const LicenseMetadata(policy: LicensePolicy.unknownReviewRequired, confidence: 0.0),
      );
      final completeness = const AttributionCheck().evaluate(minimal);
      expect(completeness.isComplete, isFalse);
      expect(completeness.missing, containsAll(['author', 'repository', 'commit', 'version', 'license']));
      expect(completeness.present, contains('source'));
    });
  });

  group('SoftwareReview', () {
    test('a low-confidence repository understanding is flagged as a warning', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(
        source: '',
        metadata: RepositoryMetadata(name: 'empty', description: '', primaryLanguage: 'text', provenance: _fullProvenance()),
      ));
      final issues = const SoftwareReview().reviewRepository(model);
      expect(issues, isNotEmpty);
      expect(issues.first.severity, ReviewSeverity.warning);
    });

    test('a repository with no source URL is a critical issue', () {
      final noUrlProvenance = SoftwareProvenance(
        sourceUrl: '',
        retrievedAt: DateTime(2026, 8, 2),
        provider: 'test-fixture',
        license: const LicenseMetadata(policy: LicensePolicy.unknownReviewRequired),
      );
      final model = RepositoryAnalyzer().analyze(RepositoryContext(
        source: 'flutter\n',
        metadata: RepositoryMetadata(name: 'no-url', description: '', primaryLanguage: 'dart', provenance: noUrlProvenance),
      ));
      final issues = const SoftwareReview().reviewRepository(model);
      expect(const SoftwareReview().hasCriticalIssues(issues), isTrue);
    });

    test('a sound, well-provenanced package produces no issues', () {
      final metadata = PackageMetadata(name: 'good_pkg', version: '1.0.0', description: 'A well-formed package.', provenance: _fullProvenance());
      final model = const PackageAnalyzer().analyzePubspec(pubspecSource: 'dependencies:\n  http: ^1.0.0\n', metadata: metadata);
      final issues = const SoftwareReview().reviewPackage(model);
      expect(const SoftwareReview().hasCriticalIssues(issues), isFalse);
    });
  });
}
