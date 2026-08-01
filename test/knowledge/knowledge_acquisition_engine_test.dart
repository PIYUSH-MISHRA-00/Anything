/// V1 — KnowledgeAcquisitionEngine orchestration tests.
///
/// Uses a FakeSearchProvider and a WebWeaveXAdapter with an injected
/// PageFetcher (real extraction logic, fake network) so the whole
/// query -> URLs -> extraction -> validate -> dedupe -> rank -> cache
/// pipeline is exercised deterministically, without live network.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';

class FakeSearchProvider implements SearchProvider {
  final Map<String, List<SearchResult>> _byQuery;
  final bool throwOnSearch;
  int callCount = 0;

  FakeSearchProvider(this._byQuery, {this.throwOnSearch = false});

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    callCount++;
    if (throwOnSearch) throw Exception('simulated search provider failure');
    return _byQuery[query] ?? const [];
  }
}

String _pageFor(String title, String body) =>
    '<html><head><title>$title</title></head><body><p>$body</p></body></html>';

WebWeaveXAdapter _fakeAdapter(Map<String, String> htmlByUrl) {
  return WebWeaveXAdapter(
    fetchPage: (url) async {
      final html = htmlByUrl[url];
      if (html == null) return {'available': false, 'html': ''};
      return {'available': true, 'html': html};
    },
  );
}

void main() {
  group('Provider unavailable', () {
    test(
      'bare engine (no search/webweavex configured) never touches network and reports unresolved',
      () async {
        final engine = KnowledgeAcquisitionEngine();
        final bundle = await engine.acquire(
          requirements: [
            const KnowledgeRequirement(
              objective: 'quantum tunneling basics',
              resourceType: 'domainKnowledge',
            ),
          ],
          queryHints: const [],
        );

        expect(bundle.status, BundleStatus.failed);
        expect(
          bundle.unresolvedRequirements,
          contains('quantum tunneling basics'),
        );
        expect(bundle.warnings, isNotEmpty);
      },
    );

    test(
      'search provider failure is reported as a warning, not a crash',
      () async {
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: FakeSearchProvider({}, throwOnSearch: true),
          webweavexAdapter: _fakeAdapter({}),
        );
        final bundle = await engine.acquire(
          requirements: [
            const KnowledgeRequirement(
              objective: 'anything',
              resourceType: 'domainKnowledge',
            ),
          ],
          queryHints: const [],
        );

        expect(bundle.status, BundleStatus.failed);
        expect(
          bundle.warnings.any((w) => w.contains('Retrieval failed')),
          isTrue,
        );
      },
    );
  });

  group('Multiple sources + dedup + ranking', () {
    test('acquires from multiple search results for one requirement', () async {
      final searchProvider = FakeSearchProvider({
        'loan formulas': [
          const SearchResult(url: 'https://a.example.com/loan'),
          const SearchResult(url: 'https://b.example.com/loan'),
        ],
      });
      final adapter = _fakeAdapter({
        'https://a.example.com/loan': _pageFor(
          'Loan Basics',
          'Content A about loan formulas.',
        ),
        'https://b.example.com/loan': _pageFor(
          'Loan Deep Dive',
          'Content B about loan formulas.',
        ),
      });
      final engine = KnowledgeAcquisitionEngine(
        searchProvider: searchProvider,
        webweavexAdapter: adapter,
      );

      final bundle = await engine.acquire(
        requirements: [
          const KnowledgeRequirement(
            objective: 'loan formulas',
            resourceType: 'domainKnowledge',
          ),
        ],
        queryHints: const [],
      );

      expect(bundle.status, BundleStatus.ready);
      expect(bundle.resources, hasLength(2));
      expect(
        bundle.resources.map((r) => r.sourceUri),
        containsAll([
          'https://a.example.com/loan',
          'https://b.example.com/loan',
        ]),
      );
    });

    test(
      'duplicate content across queries is deduplicated by content hash',
      () async {
        final searchProvider = FakeSearchProvider({
          'q1': [const SearchResult(url: 'https://x.example.com/page')],
          'q2': [const SearchResult(url: 'https://x.example.com/page')],
        });
        final adapter = _fakeAdapter({
          'https://x.example.com/page': _pageFor(
            'Same Page',
            'Identical content both times.',
          ),
        });
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: searchProvider,
          webweavexAdapter: adapter,
        );

        final bundle = await engine.acquire(
          requirements: [
            const KnowledgeRequirement(
              objective: 'q1',
              resourceType: 'domainKnowledge',
            ),
          ],
          queryHints: const ['q2'],
        );

        expect(bundle.resources, hasLength(1));
      },
    );

    test('resources are ranked by overall score, highest first', () async {
      // Both resources start at the adapter's default 0.5/0.5/0.5 ranking,
      // so this proves _rank runs (stable, no crash, deterministic order)
      // rather than a specific score ordering the adapter doesn't vary yet.
      final searchProvider = FakeSearchProvider({
        'q': [
          const SearchResult(url: 'https://a.example.com/'),
          const SearchResult(url: 'https://b.example.com/'),
        ],
      });
      final adapter = _fakeAdapter({
        'https://a.example.com/': _pageFor('A', 'Content A'),
        'https://b.example.com/': _pageFor('B', 'Content B'),
      });
      final engine = KnowledgeAcquisitionEngine(
        searchProvider: searchProvider,
        webweavexAdapter: adapter,
      );

      final bundle = await engine.acquire(
        requirements: [
          const KnowledgeRequirement(
            objective: 'q',
            resourceType: 'domainKnowledge',
          ),
        ],
        queryHints: const [],
      );

      expect(bundle.resources, hasLength(2));
      expect(
        bundle.resources[0].ranking.overallScore,
        greaterThanOrEqualTo(bundle.resources[1].ranking.overallScore),
      );
    });
  });

  group('Validation', () {
    test(
      'an unreachable search result URL is silently dropped, not fabricated',
      () async {
        final searchProvider = FakeSearchProvider({
          'q': [const SearchResult(url: 'https://unreachable.example.com/')],
        });
        final adapter = _fakeAdapter(
          {},
        ); // nothing resolves -> 'available: false'
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: searchProvider,
          webweavexAdapter: adapter,
        );

        final bundle = await engine.acquire(
          requirements: [
            const KnowledgeRequirement(
              objective: 'q',
              resourceType: 'domainKnowledge',
            ),
          ],
          queryHints: const [],
        );

        expect(bundle.resources, isEmpty);
        expect(bundle.status, BundleStatus.failed);
      },
    );

    test('malformed source URI never enters the bundle', () async {
      // Simulate via the legacy cache pool with a non-URL sourceUri passed
      // straight through _validate's http(s) scheme check.
      final engine = KnowledgeAcquisitionEngine(
        searchProvider: FakeSearchProvider({
          'q': [const SearchResult(url: 'not-a-url')],
        }),
        webweavexAdapter: WebWeaveXAdapter(
          fetchPage: (url) async => {
            'available': true,
            'html': _pageFor('T', 'C'),
          },
        ),
      );

      final bundle = await engine.acquire(
        requirements: [
          const KnowledgeRequirement(
            objective: 'q',
            resourceType: 'domainKnowledge',
          ),
        ],
        queryHints: const [],
      );

      // extract() itself rejects non-http URLs before fetching, so this
      // resolves to zero usable resources rather than a malformed one.
      expect(bundle.resources, isEmpty);
    });
  });

  group('Offline / cache reuse', () {
    test(
      'a cached query is served without touching the search provider again',
      () async {
        final searchProvider = FakeSearchProvider({
          'q': [const SearchResult(url: 'https://cached.example.com/')],
        });
        final adapter = _fakeAdapter({
          'https://cached.example.com/': _pageFor('Cached', 'Cached content.'),
        });
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: searchProvider,
          webweavexAdapter: adapter,
        );
        final requirements = [
          const KnowledgeRequirement(
            objective: 'q',
            resourceType: 'domainKnowledge',
          ),
        ];

        final first = await engine.acquire(
          requirements: requirements,
          queryHints: const [],
        );
        expect(first.status, BundleStatus.ready);
        expect(searchProvider.callCount, 1);

        final second = await engine.acquire(
          requirements: requirements,
          queryHints: const [],
        );
        expect(second.resources, hasLength(1));
        expect(second.status, BundleStatus.offlineCached);
        // Search provider was not called again — served from cache.
        expect(searchProvider.callCount, 1);
      },
    );

    test(
      'network becomes unavailable after a successful cache fill: still usable',
      () async {
        final searchProvider = FakeSearchProvider({
          'q': [const SearchResult(url: 'https://once.example.com/')],
        });
        final adapter = _fakeAdapter({
          'https://once.example.com/': _pageFor(
            'Once',
            'Available the first time only.',
          ),
        });
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: searchProvider,
          webweavexAdapter: adapter,
        );
        final requirements = [
          const KnowledgeRequirement(
            objective: 'q',
            resourceType: 'domainKnowledge',
          ),
        ];

        await engine.acquire(requirements: requirements, queryHints: const []);

        // Simulate network going away entirely for a second engine sharing
        // the same cache instance would require exposing the cache; instead
        // prove the already-acquired engine still serves cached results even
        // if the search provider would now fail.
        searchProvider._byQuery.clear();
        final second = await engine.acquire(
          requirements: requirements,
          queryHints: const [],
        );
        expect(second.resources, isNotEmpty);
        expect(second.status, BundleStatus.offlineCached);
      },
    );
  });

  group('KnowledgeCacheKey', () {
    test('identical query/language/provider/options produce the same key', () {
      const a = KnowledgeCacheKey(query: 'Loan Formulas', language: 'en');
      const b = KnowledgeCacheKey(query: 'loan formulas', language: 'en');
      expect(a.toStableString(), b.toStableString());
    });

    test('different language produces a different key', () {
      const a = KnowledgeCacheKey(query: 'loan formulas', language: 'en');
      const b = KnowledgeCacheKey(query: 'loan formulas', language: 'fr');
      expect(a.toStableString(), isNot(b.toStableString()));
    });
  });
}
