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
///
/// DETERMINISTIC NORMALIZATION (Implementation Specification IS-R47 Task 4).
/// REALITY before R47, confirmed by reading this file: extracted `content`
/// was hashed and cached exactly as the page produced it, and each resource
/// took an id derived from `DateTime.now().microsecondsSinceEpoch`. Two
/// consequences, both real:
///
///   1. The SAME page fetched twice produced DIFFERENT resource ids, so no
///      two acquisitions were ever comparable.
///   2. Byte-equivalent-but-differently-encoded content — CRLF vs LF, NFC vs
///      NFD Unicode, trailing whitespace — produced DIFFERENT `contentHash`
///      values. `KnowledgeAcquisitionEngine._deduplicate()` keys on exactly
///      that hash, so genuinely duplicate knowledge survived deduplication
///      and was fed to the reasoner twice.
///
/// R47 closes this using WebWeaveX's OWN canonical determinism primitives —
/// `normalizeRuntimeValue` (NFKC + CRLF->LF + trailing-whitespace strip) and
/// `stableSerialize` (canonical JSON with sorted keys). No bespoke
/// normalizer, no second serializer, no second cache: the existing
/// `KnowledgeCache` and the existing dedup/rank pipeline are untouched and
/// simply receive already-canonical input.
///
/// WebWeaveX types still stop at this adapter boundary. The engine never
/// imports `package:webweavex`; when it needs a canonical representation it
/// calls [canonicalRepresentation] here. That keeps R46 invariant I-21b
/// (WebWeaveX imported only by its documented adapters) unchanged.
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

    // IS-R47: normalize through WebWeaveX's own canonical normalizer BEFORE
    // anything downstream sees the text — so hashing, deduplication and
    // caching all operate on a canonical form rather than on whatever byte
    // sequence the page happened to serve.
    final title = wwx.normalizeRuntimeValue(
      (semanticHtml['title'] as String? ?? '').trim(),
    );
    final paragraphs = (semanticContent['paragraphs'] as List? ?? [])
        .cast<String>();
    final fullText = semanticHtml['text'] as String? ?? '';
    var content = wwx.normalizeRuntimeValue(
      paragraphs.isNotEmpty ? paragraphs.join('\n\n') : fullText,
    );
    if (content.isEmpty) return null;

    // Trusted knowledge-size ceiling — a single huge page must not blow the
    // reasoning-prompt budget downstream (see RuntimeSecurityLimits and
    // ModelApplicationReasoner's own tighter per-prompt truncation).
    //
    // Truncation happens AFTER normalization deliberately: normalizing first
    // means the ceiling applies to the canonical form, so two encodings of
    // the same page truncate at the same point and still agree. Truncating
    // first could cut mid-sequence and leave the two forms diverging.
    if (content.length > RuntimeSecurityLimits.maxKnowledgeBytes) {
      content = wwx.normalizeRuntimeValue(
        content.substring(0, RuntimeSecurityLimits.maxKnowledgeBytes),
      );
    }

    final now = DateTime.now();
    final contentHash = KnowledgeResource.computeHash(content);
    final imageUrl = _extractImageUrl(html, uri);

    return KnowledgeResource(
      // IS-R47: identity derived from the canonical serialization of the
      // identity-bearing fields, never from a wall clock. The same page with
      // the same normalized content now yields the SAME id on every
      // acquisition, which is what makes repeat acquisitions comparable.
      // `retrievedAt` is deliberately excluded — it is real provenance about
      // WHEN this fetch happened, not part of WHAT was fetched.
      id: _deterministicId(
        sourceUri: url,
        title: title.isNotEmpty ? title : uri.host,
        contentHash: contentHash,
      ),
      type: KnowledgeResourceType.webDocument,
      title: title.isNotEmpty ? title : uri.host,
      sourceUri: url,
      sourceDomain: uri.host,
      retrievedAt: now,
      content: content,
      contentHash: contentHash,
      imageUrl: imageUrl,
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

  /// Representative page image from og:image / twitter:image meta tags,
  /// resolved to an absolute http(s) URL. Presentation metadata only —
  /// excluded from identity and canonical representation. Scans only the
  /// document head region, where these tags live.
  static String? _extractImageUrl(String html, Uri pageUri) {
    final head = html.length > 20000 ? html.substring(0, 20000) : html;
    final patterns = [
      RegExp(
        '<meta[^>]+(?:property|name)=["\'](?:og:image|twitter:image)["\']'
        '[^>]*content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\']'
        '[^>]*(?:property|name)=["\'](?:og:image|twitter:image)["\']',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(head);
      if (match == null) continue;
      final parsed = Uri.tryParse(match.group(1)!.trim());
      if (parsed == null) continue;
      final absolute = parsed.hasScheme ? parsed : pageUri.resolveUri(parsed);
      if (absolute.scheme == 'http' || absolute.scheme == 'https') {
        return absolute.toString();
      }
    }
    return null;
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

  /// The canonical, deterministic representation of a resource's
  /// identity-bearing content (Implementation Specification IS-R47 Task 4).
  ///
  /// Produced by WebWeaveX's OWN `stableSerialize` — canonical JSON with
  /// stably-sorted keys — over the fields that define WHAT was acquired.
  /// `retrievedAt`, `id` and the scoring/trust metadata are excluded on
  /// purpose: they describe when a fetch happened and how it was judged, not
  /// what it contains, and including them would make the representation
  /// differ between two acquisitions of identical content.
  ///
  /// This exists so `KnowledgeAcquisitionEngine` and its tests can obtain a
  /// canonical representation WITHOUT importing `package:webweavex`
  /// themselves — the adapter boundary (R46 invariant I-21b) stays intact.
  ///
  /// Guarantee: two resources acquired from the same URL with the same
  /// normalized content produce byte-identical strings here.
  String canonicalRepresentation(KnowledgeResource resource) {
    return wwx.stableSerialize(<String, dynamic>{
      'sourceUri': resource.sourceUri,
      'sourceDomain': resource.sourceDomain,
      'type': resource.type.name,
      'title': resource.title,
      'language': resource.language,
      'format': resource.format,
      'contentHash': resource.contentHash,
      'content': resource.content,
      'provider': resource.provenance.provider,
    });
  }

  /// Normalize an arbitrary text value through WebWeaveX's canonical
  /// normalizer (NFKC, CRLF -> LF, trailing-whitespace strip).
  ///
  /// Exposed so other Anything code can normalize consistently without
  /// importing `package:webweavex`. It is a straight delegation — this
  /// adapter deliberately implements no normalization rules of its own.
  String normalizeText(String value) => wwx.normalizeRuntimeValue(value);

  /// Deterministic resource identity: a short digest of the canonical
  /// serialization of the identity-bearing fields.
  static String _deterministicId({
    required String sourceUri,
    required String title,
    required String contentHash,
  }) {
    final canonical = wwx.stableSerialize(<String, dynamic>{
      'sourceUri': sourceUri,
      'title': title,
      'contentHash': contentHash,
    });
    return 'wwx-${KnowledgeResource.computeHash(canonical).substring(0, 24)}';
  }

  /// Get WebWeaveX version info.
  String get version => '3.0.0';
}
