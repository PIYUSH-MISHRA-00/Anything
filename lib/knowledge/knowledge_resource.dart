/// Knowledge resource model for Anything.
///
/// Normalized representation of an external knowledge resource.
/// Every resource retains provenance and trust metadata.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Types of knowledge resources.
enum KnowledgeResourceType {
  webDocument,
  documentationPage,
  apiReference,
  repositoryMetadata,
  sourceFile,
  codeExample,
  packageInformation,
  structuredData,
  schema,
  generalArticle,
}

/// Trust classification for a resource.
enum TrustLevel { official, highConfidence, community, unknown, untrusted }

/// License classification for a resource.
enum LicensePolicy {
  permissiveKnown,
  attributionRequired,
  copyleftReviewRequired,
  restrictedOrIncompatible,
  unknownReviewRequired,
}

/// A normalized knowledge resource.
class KnowledgeResource {
  final String id;
  final KnowledgeResourceType type;
  final String title;
  final String sourceUri;
  final String sourceDomain;
  final DateTime retrievedAt;
  final String? content;
  final String? contentHash;
  final String language;
  final String format;
  final ResourceProvenance provenance;
  final LicenseMetadata license;
  final TrustMetadata trust;
  final FreshnessMetadata freshness;
  final RankingMetadata ranking;

  const KnowledgeResource({
    required this.id,
    required this.type,
    required this.title,
    required this.sourceUri,
    required this.sourceDomain,
    required this.retrievedAt,
    this.content,
    this.contentHash,
    this.language = 'en',
    this.format = 'text/html',
    required this.provenance,
    required this.license,
    required this.trust,
    required this.freshness,
    required this.ranking,
  });

  /// Compute content hash from content string.
  static String computeHash(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  /// IS-R48: `content` is now included.
  ///
  /// REALITY before R48: `toJson()` omitted `content` entirely and
  /// `fromJson()` never read it, so `KnowledgeResource.fromJson(r.toJson())`
  /// silently returned a resource with `content == null`. That was already a
  /// latent round-trip bug in `KnowledgeBundle.toJson()/fromJson()` (the only
  /// consumers), and it becomes load-bearing once resources are persisted:
  /// `WebWeaveXAdapter.canonicalRepresentation()` includes `content`, so a
  /// content-less round trip would produce a DIFFERENT canonical
  /// representation after restart — breaking this milestone's central
  /// guarantee.
  ///
  /// `retrievedAt` remains a separate, first-class field rather than part of
  /// identity: it is real provenance about WHEN a fetch happened, and IS-R47
  /// deliberately excludes it from the canonical representation.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'sourceUri': sourceUri,
    'sourceDomain': sourceDomain,
    'retrievedAt': retrievedAt.toIso8601String(),
    'content': content,
    'contentHash': contentHash,
    'language': language,
    'format': format,
    'provenance': provenance.toJson(),
    'license': license.toJson(),
    'trust': trust.toJson(),
    'freshness': freshness.toJson(),
    'ranking': ranking.toJson(),
  };

  factory KnowledgeResource.fromJson(Map<String, dynamic> json) {
    return KnowledgeResource(
      id: json['id'] as String,
      type: KnowledgeResourceType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => KnowledgeResourceType.webDocument,
      ),
      title: json['title'] as String,
      sourceUri: json['sourceUri'] as String,
      sourceDomain: json['sourceDomain'] as String,
      retrievedAt: DateTime.parse(json['retrievedAt'] as String),
      content: json['content'] as String?,
      contentHash: json['contentHash'] as String?,
      language: json['language'] as String? ?? 'en',
      format: json['format'] as String? ?? 'text/html',
      provenance: ResourceProvenance.fromJson(
        json['provenance'] as Map<String, dynamic>,
      ),
      license: LicenseMetadata.fromJson(
        json['license'] as Map<String, dynamic>,
      ),
      trust: TrustMetadata.fromJson(json['trust'] as Map<String, dynamic>),
      freshness: FreshnessMetadata.fromJson(
        json['freshness'] as Map<String, dynamic>,
      ),
      ranking: RankingMetadata.fromJson(
        json['ranking'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Provenance information for a resource.
class ResourceProvenance {
  final String sourceUrl;
  final String sourceDomain;
  final DateTime retrievedAt;
  final String provider;
  final String? contentHash;

  const ResourceProvenance({
    required this.sourceUrl,
    required this.sourceDomain,
    required this.retrievedAt,
    required this.provider,
    this.contentHash,
  });

  Map<String, dynamic> toJson() => {
    'sourceUrl': sourceUrl,
    'sourceDomain': sourceDomain,
    'retrievedAt': retrievedAt.toIso8601String(),
    'provider': provider,
    'contentHash': contentHash,
  };

  factory ResourceProvenance.fromJson(Map<String, dynamic> json) {
    return ResourceProvenance(
      sourceUrl: json['sourceUrl'] as String,
      sourceDomain: json['sourceDomain'] as String,
      retrievedAt: DateTime.parse(json['retrievedAt'] as String),
      provider: json['provider'] as String,
      contentHash: json['contentHash'] as String?,
    );
  }
}

/// License metadata for a resource.
class LicenseMetadata {
  final String? licenseId;
  final String? licenseName;
  final LicensePolicy policy;
  final String? source;
  final double confidence;

  const LicenseMetadata({
    this.licenseId,
    this.licenseName,
    required this.policy,
    this.source,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'licenseId': licenseId,
    'licenseName': licenseName,
    'policy': policy.name,
    'source': source,
    'confidence': confidence,
  };

  factory LicenseMetadata.fromJson(Map<String, dynamic> json) {
    return LicenseMetadata(
      licenseId: json['licenseId'] as String?,
      licenseName: json['licenseName'] as String?,
      policy: LicensePolicy.values.firstWhere(
        (p) => p.name == json['policy'],
        orElse: () => LicensePolicy.unknownReviewRequired,
      ),
      source: json['source'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Trust metadata for a resource.
class TrustMetadata {
  final TrustLevel level;
  final String reason;
  final double confidence;

  const TrustMetadata({
    required this.level,
    required this.reason,
    this.confidence = 0.5,
  });

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'reason': reason,
    'confidence': confidence,
  };

  factory TrustMetadata.fromJson(Map<String, dynamic> json) {
    return TrustMetadata(
      level: TrustLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => TrustLevel.unknown,
      ),
      reason: json['reason'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

/// Freshness metadata.
class FreshnessMetadata {
  final DateTime? publishedAt;
  final DateTime? lastModified;
  final String? freshnessIndicator;

  const FreshnessMetadata({
    this.publishedAt,
    this.lastModified,
    this.freshnessIndicator,
  });

  Map<String, dynamic> toJson() => {
    'publishedAt': publishedAt?.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
    'freshnessIndicator': freshnessIndicator,
  };

  factory FreshnessMetadata.fromJson(Map<String, dynamic> json) {
    return FreshnessMetadata(
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
      freshnessIndicator: json['freshnessIndicator'] as String?,
    );
  }
}

/// Ranking metadata.
class RankingMetadata {
  final double relevanceScore;
  final double authorityScore;
  final double freshnessScore;

  const RankingMetadata({
    this.relevanceScore = 0.0,
    this.authorityScore = 0.0,
    this.freshnessScore = 0.0,
  });

  double get overallScore =>
      (relevanceScore * 0.5) + (authorityScore * 0.3) + (freshnessScore * 0.2);

  Map<String, dynamic> toJson() => {
    'relevanceScore': relevanceScore,
    'authorityScore': authorityScore,
    'freshnessScore': freshnessScore,
  };

  factory RankingMetadata.fromJson(Map<String, dynamic> json) {
    return RankingMetadata(
      relevanceScore: (json['relevanceScore'] as num?)?.toDouble() ?? 0.0,
      authorityScore: (json['authorityScore'] as num?)?.toDouble() ?? 0.0,
      freshnessScore: (json['freshnessScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
