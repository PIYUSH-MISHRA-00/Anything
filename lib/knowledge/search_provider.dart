/// Search Provider — resolves a text query to candidate URLs.
///
/// Independent from WebWeaveX by design: WebWeaveX extracts content from a
/// URL it is given; it has no search/query-resolution capability of its
/// own. This abstraction owns exactly the "find URLs for this query" step,
/// nothing else, so it can be swapped (a different search backend, a
/// paid API, a self-hosted index) without touching the Kernel or the
/// WebWeaveX extraction boundary.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One candidate result from a search.
class SearchResult {
  final String url;
  final String title;
  final String snippet;

  const SearchResult({required this.url, this.title = '', this.snippet = ''});
}

/// Resolves a text query to candidate URLs. Implementations own their own
/// backend (a search engine, a paid API, a fixed allow-list) — the rest of
/// the knowledge pipeline only depends on this interface.
abstract class SearchProvider {
  /// Returns up to [maxResults] candidate URLs for [query]. Returns an
  /// empty list (never throws for "no results") when nothing is found;
  /// throws only for a genuine transport/provider failure.
  Future<List<SearchResult>> search(String query, {int maxResults = 5});
}

/// Default SearchProvider: DuckDuckGo's key-less HTML results endpoint.
///
/// This is one interchangeable implementation, not an architectural
/// dependency — nothing outside this class knows or cares that DuckDuckGo
/// is behind it. It never touches WebWeaveX; it does its own bounded HTTP
/// fetch and a narrow, purpose-built parse of DuckDuckGo's result-link
/// markup (not a general HTML/content extractor — that job belongs to
/// WebWeaveX, downstream of this class).
class DuckDuckGoSearchProvider implements SearchProvider {
  static const _endpoint = 'https://html.duckduckgo.com/html/';
  static const _maxResponseBytes = 2 * 1024 * 1024; // 2 MB
  static final _resultLinkPattern = RegExp(
    r'class="result__a"[^>]*href="([^"]+)"',
  );

  final http.Client _client;
  final Duration _timeout;

  DuckDuckGoSearchProvider({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 15);

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) return const [];

    final uri = Uri.parse(_endpoint).replace(queryParameters: {'q': query});
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'User-Agent': 'AnythingKnowledgeEngine/1.0'})
          .timeout(_timeout);
    } catch (_) {
      // Network unavailable / DNS failure / timeout — no results, not a crash.
      return const [];
    }

    if (response.statusCode != 200) return const [];
    final body = response.bodyBytes.length > _maxResponseBytes
        ? utf8.decode(response.bodyBytes.sublist(0, _maxResponseBytes))
        : response.body;

    final urls = <String>[];
    for (final match in _resultLinkPattern.allMatches(body)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final resolved = _resolveResultUrl(raw);
      if (resolved != null && !urls.contains(resolved)) {
        urls.add(resolved);
      }
      if (urls.length >= maxResults) break;
    }

    return urls.map((u) => SearchResult(url: u)).toList();
  }

  /// DuckDuckGo's HTML results wrap the real target in a redirect link:
  /// `//duckduckgo.com/l/?uddg=<url-encoded-target>&rut=...`. Decode that
  /// when present; otherwise treat the href as already-direct.
  String? _resolveResultUrl(String href) {
    final normalized = href.startsWith('//') ? 'https:$href' : href;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return null;

    final uddg = uri.queryParameters['uddg'];
    if (uddg != null && uddg.isNotEmpty) {
      final target = Uri.tryParse(Uri.decodeComponent(uddg));
      if (target != null && target.scheme.startsWith('http')) {
        return target.toString();
      }
      return null;
    }

    return uri.scheme.startsWith('http') ? uri.toString() : null;
  }
}
