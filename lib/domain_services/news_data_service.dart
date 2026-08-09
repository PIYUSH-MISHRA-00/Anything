/// Structured news retrieval — Google News RSS (no API key).
///
/// Distinct from WebWeaveX/generic knowledge. Returns article items, never
/// a Wikipedia page extract as the primary result.
library;

import 'package:http/http.dart' as http;

/// One news article.
class NewsArticle {
  final String title;
  final String source;
  final String? publishedAt;
  final String? summary;
  final String? url;
  final String? imageUrl;
  final DateTime retrievedAt;
  final String provider;

  const NewsArticle({
    required this.title,
    required this.source,
    required this.retrievedAt,
    this.publishedAt,
    this.summary,
    this.url,
    this.imageUrl,
    this.provider = 'google-news-rss',
  });

  Map<String, dynamic> toResultMap() => {
    'title': title,
    'content': _block,
    'sourceType': 'structuredNews',
    'provider': provider,
    'sourceUri': url ?? '',
    'source': source,
    'publishedAt': publishedAt,
    'summary': summary,
    'imageUrl': imageUrl,
    'retrievedAt': retrievedAt.toIso8601String(),
  };

  String get _block {
    // Never dump raw image/article URLs as the primary visual — URLs live in
    // structured fields (url / imageUrl) for ImageNode / link binding.
    final buf = StringBuffer()..writeln(title);
    if (source.isNotEmpty) buf.writeln('Source: $source');
    if (publishedAt != null && publishedAt!.isNotEmpty) {
      buf.writeln('Published: $publishedAt');
    }
    if (summary != null && summary!.trim().isNotEmpty) {
      final cleaned = summary!
          .trim()
          .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty) buf.writeln(cleaned);
    }
    buf.writeln('Retrieved: ${retrievedAt.toLocal().toIso8601String()}');
    buf.writeln('Source type: structured news ($provider)');
    return buf.toString().trim();
  }
}

/// Fetches real headlines via Google News RSS search.
class NewsDataService {
  NewsDataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<NewsArticle>> searchArticles(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) throw ArgumentError('Query is required');

    final uri = Uri.https('news.google.com', '/rss/search', {
      'q': q,
      'hl': 'en-US',
      'gl': 'US',
      'ceid': 'US:en',
    });
    final res = await _client
        .get(uri, headers: {'User-Agent': 'Anything/2.0 (news)'})
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw StateError('News provider failed (HTTP ${res.statusCode})');
    }

    final now = DateTime.now().toUtc();
    final items = _extractItems(res.body);
    if (items.isEmpty) {
      return const [];
    }

    return items.take(limit).map((item) {
      final title = _stripCdata(_tag(item, 'title') ?? 'Untitled');
      final link = _stripCdata(_tag(item, 'link') ?? '');
      final pub = _stripCdata(_tag(item, 'pubDate') ?? '');
      final desc = _stripHtml(_stripCdata(_tag(item, 'description') ?? ''));
      final source = _stripCdata(_tag(item, 'source') ?? '');
      final imageUrl = _extractImageUrl(item);
      return NewsArticle(
        title: title,
        source: source.isEmpty ? 'Google News' : source,
        publishedAt: pub.isEmpty ? null : pub,
        summary: desc.isEmpty ? null : desc,
        url: link.isEmpty ? null : link,
        imageUrl: imageUrl,
        retrievedAt: now,
      );
    }).toList();
  }

  static List<String> _extractItems(String xml) {
    final out = <String>[];
    final re = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false);
    for (final m in re.allMatches(xml)) {
      out.add(m.group(1) ?? '');
    }
    return out;
  }

  static String? _tag(String xml, String name) {
    final re = RegExp(
      '<$name(?:\\s[^>]*)?>([\\s\\S]*?)</$name>',
      caseSensitive: false,
    );
    return re.firstMatch(xml)?.group(1);
  }

  /// Prefer media:content / enclosure / img src when present in the item XML.
  static String? _extractImageUrl(String itemXml) {
    final media = RegExp(
      r'''<(?:media:content|media:thumbnail)[^>]+url=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(itemXml)?.group(1);
    if (media != null && media.trim().isNotEmpty) return media.trim();

    final enclosure = RegExp(
      r'''<enclosure[^>]+url=["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
    ).firstMatch(itemXml);
    if (enclosure != null) {
      final url = enclosure.group(1)?.trim();
      final type = RegExp(
        r'''type=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(enclosure.group(0) ?? '')?.group(1);
      if (url != null &&
          url.isNotEmpty &&
          (type == null || type.startsWith('image/'))) {
        return url;
      }
    }

    final img = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(itemXml)?.group(1);
    if (img != null && img.trim().isNotEmpty) return img.trim();
    return null;
  }

  static String _stripCdata(String raw) {
    final t = raw.trim();
    final m = RegExp(
      r'<!\[CDATA\[([\s\S]*?)\]\]>',
      caseSensitive: false,
    ).firstMatch(t);
    return (m?.group(1) ?? t).trim();
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
