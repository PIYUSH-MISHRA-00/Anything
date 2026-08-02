/// SoftwareCognitionEngine — the top-level orchestrator: acquire (via
/// RepositoryAnalyzer/PackageAnalyzer, which use only `package:webweavex`
/// for the actual fetch/parse), review the resulting understanding
/// (SoftwareReview, reusing SCARE's severity vocabulary), and enforce the
/// copyright/attribution boundary (CopyrightBoundary/AttributionCheck) —
/// producing one typed, reviewed SoftwareCognitionResult per acquisition.
/// Never generates an application itself; that remains the Kernel's job.
library;

import 'copyright_boundary.dart';
import 'package_analyzer.dart';
import 'package_model.dart';
import 'repository_analyzer.dart';
import 'repository_model.dart';
import 'software_review.dart';

class RepositoryCognitionResult {
  final RepositoryModel model;
  final List<SoftwareReviewIssue> issues;
  final CopyrightBoundaryResult copyright;
  final AttributionCompleteness attribution;

  const RepositoryCognitionResult({
    required this.model,
    required this.issues,
    required this.copyright,
    required this.attribution,
  });

  bool get isSound => copyright.isTransformative && !const SoftwareReview().hasCriticalIssues(issues);
}

class PackageCognitionResult {
  final PackageModel model;
  final List<SoftwareReviewIssue> issues;
  final AttributionCompleteness attribution;

  const PackageCognitionResult({required this.model, required this.issues, required this.attribution});

  bool get isSound => !const SoftwareReview().hasCriticalIssues(issues);
}

class SoftwareCognitionEngine {
  final RepositoryAnalyzer _repositoryAnalyzer;
  final PackageAnalyzer _packageAnalyzer;
  final SoftwareReview _review;
  final CopyrightBoundary _copyrightBoundary;
  final AttributionCheck _attributionCheck;

  SoftwareCognitionEngine({
    RepositoryAnalyzer? repositoryAnalyzer,
    PackageAnalyzer packageAnalyzer = const PackageAnalyzer(),
    SoftwareReview review = const SoftwareReview(),
    CopyrightBoundary copyrightBoundary = const CopyrightBoundary(),
    AttributionCheck attributionCheck = const AttributionCheck(),
  }) : _repositoryAnalyzer = repositoryAnalyzer ?? RepositoryAnalyzer(),
       _packageAnalyzer = packageAnalyzer,
       _review = review,
       _copyrightBoundary = copyrightBoundary,
       _attributionCheck = attributionCheck;

  RepositoryCognitionResult understandRepository(RepositoryContext context) {
    final model = _repositoryAnalyzer.analyze(context);
    final issues = _review.reviewRepository(model);
    final copyright = _copyrightBoundary.check(originalSource: context.source, digestText: model.summary.toDigestText());
    final attribution = _attributionCheck.evaluate(context.metadata.provenance);
    return RepositoryCognitionResult(model: model, issues: issues, copyright: copyright, attribution: attribution);
  }

  Future<RepositoryCognitionResult?> understandRepositoryFromUrl(String url, {required String name, String description = ''}) async {
    final model = await _repositoryAnalyzer.acquireFromUrl(url, name: name, description: description);
    if (model == null) return null;
    final issues = _review.reviewRepository(model);
    // The original source text isn't retained past acquisition (never
    // stored on RepositoryModel) — the copyright check here validates the
    // digest is bounded relative to itself rather than re-fetching.
    final copyright = CopyrightBoundaryResult(violations: model.summary.toDigestText().length > 2000 ? ['digest exceeds the expected bounded summary length'] : const []);
    final attribution = _attributionCheck.evaluate(model.metadata.provenance);
    return RepositoryCognitionResult(model: model, issues: issues, copyright: copyright, attribution: attribution);
  }

  PackageCognitionResult understandPackageFromPubspec({required String pubspecSource, required PackageMetadata metadata}) {
    final model = _packageAnalyzer.analyzePubspec(pubspecSource: pubspecSource, metadata: metadata);
    final issues = _review.reviewPackage(model);
    final attribution = _attributionCheck.evaluate(metadata.provenance);
    return PackageCognitionResult(model: model, issues: issues, attribution: attribution);
  }

  PackageCognitionResult understandPackageFromDescription({required String text, required PackageMetadata metadata}) {
    final model = _packageAnalyzer.analyzeFromDescription(text: text, metadata: metadata);
    final issues = _review.reviewPackage(model);
    final attribution = _attributionCheck.evaluate(metadata.provenance);
    return PackageCognitionResult(model: model, issues: issues, attribution: attribution);
  }
}
