/// IS-P11 — KnowledgeAcquisitionEngine invokes WebWeaveX on retrieved sources.
library;

import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

class _AnyQuerySearch implements SearchProvider {
  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    return [
      SearchResult(
        url: 'https://example.com/weather/lucknow',
        title: 'Lucknow weather',
        snippet: 'Current conditions for $query',
      ),
    ];
  }
}

void main() {
  test('search → WebWeaveX extract → KnowledgeResource content', () async {
    var webweavexCalls = 0;
    final adapter = WebWeaveXAdapter(
      fetchPage: (url) async {
        webweavexCalls++;
        return {
          'available': true,
          'html':
              '<html><head><title>Lucknow Weather</title></head>'
              '<body><h1>Lucknow</h1><p>Temperature 32 C Sunny</p></body></html>',
          'finalUrl': url,
        };
      },
    );

    final engine = KnowledgeAcquisitionEngine(
      searchProvider: _AnyQuerySearch(),
      webweavexAdapter: adapter,
    );

    final bundle = await engine.acquire(
      requirements: [
        const KnowledgeRequirement(
          objective: 'current weather conditions for Lucknow',
          resourceType: 'domainKnowledge',
        ),
      ],
      queryHints: const ['Lucknow weather'],
    );

    expect(webweavexCalls, greaterThan(0));
    expect(bundle.status, BundleStatus.ready);
    expect(bundle.resources, isNotEmpty);
    final joined = bundle.resources
        .map((r) => '${r.title} ${r.content ?? ''}')
        .join(' ')
        .toLowerCase();
    expect(joined, contains('32'));
    expect(joined, anyOf(contains('sunny'), contains('lucknow')));
  });
}
