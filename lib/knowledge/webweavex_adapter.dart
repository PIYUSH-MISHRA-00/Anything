/// WebWeaveX adapter for Anything.
///
/// Translates a candidate URL into a normalized, provenance-carrying
/// KnowledgeResource using the published `package:webweavex` extraction
/// primitives. This adapter never resolves a text query to a URL — that is
/// SearchProvider's job (see search_provider.dart). WebWeaveX-specific
/// types stop at this adapter boundary; only this file imports
/// `package:webweavex/...`.
///
/// Architecture:
///   SearchProvider (query -> URLs) -> WebWeaveXAdapter (URL -> KnowledgeResource)
library;

import 'package:webweavex/webweavex.dart' as wwx;

import '../security/runtime_security_limits.dart';
import 'knowledge_resource.dart';

/// Fetches a page and returns WebWeaveX's `renderPage` shape
/// (`{url, status, html, available}`). Injectable purely so tests can
/// exercise the real WebWeaveX parsing/extraction logic below without
/// touching live network; production always uses `wwx.renderPage`, the
/// package's own real, bounded HTTP fetch.
typedef PageFetcher = Future<Map<String, dynamic>> Function(String url);

/// Adapter for WebWeaveX-backed knowledge extraction.
///
/// Uses the published `webweavex` package's real HTTP fetch (`renderPage`)
/// and real HTML parsing (`extractSemanticHtml`/`extractSemanticContent`,
/// its bs4-parity Soup engine) — no bespoke fetch/parse logic is
/// duplicated here.
class WebWeaveXAdapter {
  final PageFetcher _fetchPage;

  WebWeaveXAdapter({PageFetcher? fetchPage})
    : _fetchPage = fetchPage ?? wwx.renderPage;

  /// Extract a single candidate URL into a KnowledgeResource.
  ///
  /// Returns null (not a thrown exception) when the page is unreachable or
  /// yields no usable content — a network/target failure for one candidate
  /// must not abort acquisition of the others.
  Future<KnowledgeResource?> extract(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.scheme.startsWith('http')) return null;

    Map<String, dynamic> rendered;
    try {
      rendered = await _fetchPage(url);
    } catch (_) {
      return null;
    }

    if (rendered['available'] != true) return null;
    final html = rendered['html'] as String? ?? '';
    if (html.isEmpty) return null;

    final semanticHtml = wwx.extractSemanticHtml(html);
    final semanticContent = wwx.extractSemanticContent(html);

    final title = (semanticHtml['title'] as String? ?? '').trim();
    final paragraphs = (semanticContent['paragraphs'] as List? ?? [])
        .cast<String>();
    final fullText = semanticHtml['text'] as String? ?? '';
    var content = paragraphs.isNotEmpty ? paragraphs.join('\n\n') : fullText;
    if (content.isEmpty) return null;

    // Trusted knowledge-size ceiling — a single huge page must not blow the
    // reasoning-prompt budget downstream (see RuntimeSecurityLimits and
    // ModelApplicationReasoner's own tighter per-prompt truncation).
    if (content.length > RuntimeSecurityLimits.maxKnowledgeBytes) {
      content = content.substring(0, RuntimeSecurityLimits.maxKnowledgeBytes);
    }

    final now = DateTime.now();
    final contentHash = KnowledgeResource.computeHash(content);

    return KnowledgeResource(
      id: 'wwx-${now.microsecondsSinceEpoch}',
      type: KnowledgeResourceType.webDocument,
      title: title.isNotEmpty ? title : uri.host,
      sourceUri: url,
      sourceDomain: uri.host,
      retrievedAt: now,
      content: content,
      contentHash: contentHash,
      provenance: ResourceProvenance(
        sourceUrl: url,
        sourceDomain: uri.host,
        retrievedAt: now,
        provider: 'webweavex',
        contentHash: contentHash,
      ),
      license: const LicenseMetadata(
        policy: LicensePolicy.unknownReviewRequired,
        source: 'webweavex',
        confidence: 0.5,
      ),
      trust: const TrustMetadata(
        level: TrustLevel.unknown,
        reason:
            'Retrieved from the open web via WebWeaveX; not independently '
            'verified.',
        confidence: 0.5,
      ),
      freshness: FreshnessMetadata(lastModified: now),
      ranking: const RankingMetadata(
        relevanceScore: 0.5,
        authorityScore: 0.5,
        freshnessScore: 0.5,
      ),
    );
  }

  /// Extract multiple candidate URLs, dropping any that fail individually.
  Future<List<KnowledgeResource>> extractAll(List<String> urls) async {
    final results = <KnowledgeResource>[];
    for (final url in urls) {
      final resource = await extract(url);
      if (resource != null) results.add(resource);
    }
    return results;
  }

  /// Get WebWeaveX version info.
  String get version => '3.0.0';
}
