/// V1 — SearchProvider tests.
///
/// DuckDuckGoSearchProvider is the default, swappable SearchProvider
/// implementation. All tests here inject a fake http.Client (no live
/// network) to stay deterministic; the real-network proof lives in
/// knowledge_pipeline_production_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:anything/knowledge/search_provider.dart';

void main() {
  group('DuckDuckGoSearchProvider', () {
    test('parses direct result links from the HTML results page', () async {
      final client = MockClient((request) async {
        return http.Response('''
          <div class="result">
            <a class="result__a" href="https://example.com/a">Example A</a>
          </div>
          <div class="result">
            <a class="result__a" href="https://example.org/b">Example B</a>
          </div>
        ''', 200);
      });

      final provider = DuckDuckGoSearchProvider(client: client);
      final results = await provider.search('loan amortization formula');

      expect(results.length, 2);
      expect(results[0].url, 'https://example.com/a');
      expect(results[1].url, 'https://example.org/b');
    });

    test('decodes DuckDuckGo redirect-wrapped result links', () async {
      final target = Uri.encodeComponent(
        'https://real-target.example.com/page',
      );
      final client = MockClient((request) async {
        return http.Response(
          '<a class="result__a" href="//duckduckgo.com/l/?uddg=$target&rut=1">T</a>',
          200,
        );
      });

      final provider = DuckDuckGoSearchProvider(client: client);
      final results = await provider.search('some query');

      expect(results, hasLength(1));
      expect(results.first.url, 'https://real-target.example.com/page');
    });

    test('empty query returns no results without a request', () async {
      var requested = false;
      final client = MockClient((request) async {
        requested = true;
        return http.Response('', 200);
      });

      final provider = DuckDuckGoSearchProvider(client: client);
      final results = await provider.search('   ');

      expect(results, isEmpty);
      expect(requested, isFalse);
    });

    test(
      'network failure returns empty results, not a thrown exception',
      () async {
        final client = MockClient((request) async {
          throw Exception('simulated network failure');
        });

        final provider = DuckDuckGoSearchProvider(client: client);
        final results = await provider.search('anything');

        expect(results, isEmpty);
      },
    );

    test('non-200 response returns empty results', () async {
      final client = MockClient((request) async => http.Response('', 503));

      final provider = DuckDuckGoSearchProvider(client: client);
      final results = await provider.search('anything');

      expect(results, isEmpty);
    });

    test('respects maxResults even when more links are present', () async {
      final links = List.generate(
        10,
        (i) => '<a class="result__a" href="https://example.com/$i">$i</a>',
      ).join('\n');
      final client = MockClient((request) async => http.Response(links, 200));

      final provider = DuckDuckGoSearchProvider(client: client);
      final results = await provider.search('anything', maxResults: 3);

      expect(results, hasLength(3));
    });

    test('duplicate result links are not returned twice', () async {
      final client = MockClient((request) async {
        return http.Response('''
          <a class="result__a" href="https://example.com/a">A</a>
          <a class="result__a" href="https://example.com/a">A again</a>
        ''', 200);
      });

      final provider = DuckDuckGoSearchProvider(client: client);
      final results = await provider.search('anything');

      expect(results, hasLength(1));
    });
  });
}
