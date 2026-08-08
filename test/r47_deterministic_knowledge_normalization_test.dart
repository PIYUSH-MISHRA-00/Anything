/// Implementation Specification IS-R47 Task 4 - Deterministic Knowledge
/// Normalization.
///
/// REALITY before R47, confirmed by reading `lib/knowledge/webweavex_adapter.dart`:
///
///   1. Every extracted resource took `id: 'wwx-${now.microsecondsSinceEpoch}'`,
///      so the SAME page acquired twice produced DIFFERENT ids and no two
///      acquisitions were ever comparable.
///   2. `content` was hashed exactly as served. Byte-different but
///      canonically-EQUIVALENT content - CRLF vs LF, NFC vs NFD Unicode,
///      trailing whitespace - produced DIFFERENT `contentHash` values.
///      `KnowledgeAcquisitionEngine._deduplicate()` keys on exactly that
///      hash, so genuinely duplicate knowledge survived deduplication and
///      was handed to the reasoner twice.
///
/// R47 routes extraction through WebWeaveX's OWN canonical primitives -
/// `normalizeRuntimeValue` and `stableSerialize` - inside the existing
/// adapter. No bespoke normalizer, no second serializer, no second cache,
/// no second knowledge engine.
///
/// These tests use the adapter's real, already-existing injectable
/// `PageFetcher` seam, so the REAL WebWeaveX parsing, normalization and
/// serialization all execute; only the network is replaced.
///
/// ENCODING HAZARD, GUARDED. The NFC/NFD case depends on two string
/// constants being genuinely different byte sequences. A careless
/// re-encoding of this file could collapse them into two identical (or two
/// equally mojibake) strings and make the test pass for the wrong reason —
/// this really happened once while writing this file. The NFC/NFD test
/// therefore asserts up front that the two constants differ and have
/// different lengths BEFORE asserting that normalization unifies them, so
/// corruption fails the test instead of silently satisfying it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';

/// "cafe" with a precomposed e-acute (NFC, one codepoint).
const _nfc = 'café latte';

/// "cafe" with e + COMBINING ACUTE ACCENT (NFD, two codepoints).
const _nfd = 'café latte';

/// Builds a real HTML page whose body is [body].
String _page(String title, String body) =>
    '<html><head><title>$title</title></head><body><p>$body</p></body></html>';

/// A real PageFetcher over an in-memory url -> html map. Real WebWeaveX
/// parsing/normalization still runs on whatever this returns.
PageFetcher _fetcherFor(Map<String, String> pages) {
  return (String url) async {
    final html = pages[url];
    if (html == null) {
      return {'url': url, 'status': 404, 'html': '', 'available': false};
    }
    return {'url': url, 'status': 200, 'html': html, 'available': true};
  };
}

class _FixedSearchProvider implements SearchProvider {
  final List<String> urls;
  const _FixedSearchProvider(this.urls);

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async =>
      urls.take(maxResults).map((u) => SearchResult(url: u)).toList();
}

KnowledgeRequirement _req(String objective) =>
    KnowledgeRequirement(objective: objective, resourceType: 'webDocument');

void main() {
  group(
    'Deterministic identity (R47) - the same page acquired twice is genuinely the same resource',
    () {
      test(
        'two independent extractions of the identical page produce the SAME id, contentHash and canonical representation',
        () async {
          const url = 'https://example.com/a';
          final pages = {url: _page('Alpha', 'Hello world')};

          // Two separate adapters, two separate extractions, deliberately at
          // different wall-clock moments.
          final first = await WebWeaveXAdapter(
            fetchPage: _fetcherFor(pages),
          ).extract(url);
          await Future<void>.delayed(const Duration(milliseconds: 5));
          final adapterB = WebWeaveXAdapter(fetchPage: _fetcherFor(pages));
          final second = await adapterB.extract(url);

          expect(first, isNotNull);
          expect(second, isNotNull);
          expect(
            second!.id,
            first!.id,
            reason:
                'identity must derive from canonical content, never from DateTime.now() - this was the pre-R47 defect',
          );
          expect(second.contentHash, first.contentHash);
          expect(
            adapterB.canonicalRepresentation(second),
            adapterB.canonicalRepresentation(first),
            reason:
                'repeated acquisitions must produce identical normalized representations',
          );
        },
      );

      test(
        'the canonical representation deliberately EXCLUDES retrievedAt, so real provenance stays truthful without breaking determinism',
        () async {
          const url = 'https://example.com/a';
          final adapter = WebWeaveXAdapter(
            fetchPage: _fetcherFor({url: _page('Alpha', 'Hello world')}),
          );

          final first = (await adapter.extract(url))!;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          final second = (await adapter.extract(url))!;

          // Provenance stays honest: the two fetches really did happen at
          // different moments, and the resources still say so.
          expect(
            second.retrievedAt.isAfter(first.retrievedAt) ||
                second.retrievedAt == first.retrievedAt,
            isTrue,
          );
          // Yet the canonical representation is identical.
          expect(
            adapter.canonicalRepresentation(second),
            adapter.canonicalRepresentation(first),
          );
          expect(
            adapter.canonicalRepresentation(first).contains('retrievedAt'),
            isFalse,
            reason:
                'a timestamp inside the canonical form would defeat the entire purpose',
          );
        },
      );

      test(
        'genuinely different content still produces different identity - normalization must not collapse real distinctions',
        () async {
          final adapter = WebWeaveXAdapter(
            fetchPage: _fetcherFor({
              'https://example.com/a': _page('Alpha', 'Hello world'),
              'https://example.com/b': _page(
                'Beta',
                'Completely different text',
              ),
            }),
          );

          final a = (await adapter.extract('https://example.com/a'))!;
          final b = (await adapter.extract('https://example.com/b'))!;

          expect(a.id, isNot(b.id));
          expect(a.contentHash, isNot(b.contentHash));
          expect(
            adapter.canonicalRepresentation(a),
            isNot(adapter.canonicalRepresentation(b)),
          );
        },
      );

      test(
        'the same content served from a DIFFERENT url is a different resource - sourceUri is identity-bearing',
        () async {
          final adapter = WebWeaveXAdapter(
            fetchPage: _fetcherFor({
              'https://example.com/a': _page('Alpha', 'Hello world'),
              'https://mirror.example.org/a': _page('Alpha', 'Hello world'),
            }),
          );

          final a = (await adapter.extract('https://example.com/a'))!;
          final mirror = (await adapter.extract(
            'https://mirror.example.org/a',
          ))!;

          expect(
            a.contentHash,
            mirror.contentHash,
            reason: 'identical text really is identical text',
          );
          expect(
            a.id,
            isNot(mirror.id),
            reason:
                'but provenance differs, so the resources are not interchangeable',
          );
        },
      );
    },
  );

  group('Canonical normalization (R47) - equivalent encodings converge', () {
    test(
      'CRLF and LF line endings produce the SAME contentHash - so deduplication actually works across them',
      () async {
        final adapter = WebWeaveXAdapter(
          fetchPage: _fetcherFor({
            'https://example.com/lf': _page('T', 'line one\nline two'),
            'https://example.com/crlf': _page('T', 'line one\r\nline two'),
          }),
        );

        final lf = (await adapter.extract('https://example.com/lf'))!;
        final crlf = (await adapter.extract('https://example.com/crlf'))!;

        expect(
          crlf.contentHash,
          lf.contentHash,
          reason:
              'CRLF vs LF is not a real knowledge difference; before R47 these hashed differently and both survived dedup',
        );
        expect(crlf.content, lf.content);
      },
    );

    test(
      'NFC and NFD Unicode forms produce the SAME contentHash (real NFKC normalization, not a string trim)',
      () async {
        // Sanity first: these really must be different Dart strings, or the
        // test below would pass for the wrong reason.
        expect(
          _nfc == _nfd,
          isFalse,
          reason: 'the two forms must genuinely differ before normalization',
        );
        expect(_nfc.length, isNot(_nfd.length));

        final adapter = WebWeaveXAdapter(
          fetchPage: _fetcherFor({
            'https://example.com/nfc': _page('T', _nfc),
            'https://example.com/nfd': _page('T', _nfd),
          }),
        );

        final a = (await adapter.extract('https://example.com/nfc'))!;
        final b = (await adapter.extract('https://example.com/nfd'))!;

        expect(
          b.contentHash,
          a.contentHash,
          reason:
              'WebWeaveX normalizeRuntimeValue applies real NFKC; a plain trim/lowercase could never do this',
        );
        expect(b.content, a.content);
      },
    );

    test(
      'trailing whitespace is normalized away rather than changing identity',
      () async {
        final adapter = WebWeaveXAdapter(
          fetchPage: _fetcherFor({
            'https://example.com/clean': _page('T', 'some knowledge'),
            'https://example.com/ws': _page('T', 'some knowledge   '),
          }),
        );

        final clean = (await adapter.extract('https://example.com/clean'))!;
        final ws = (await adapter.extract('https://example.com/ws'))!;

        expect(ws.contentHash, clean.contentHash);
      },
    );

    test(
      'normalizeText is a pure delegation and is idempotent - normalizing twice changes nothing',
      () {
        final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor(const {}));
        for (final input in [_nfc, _nfd, 'a\r\nb', 'trailing   ', 'plain']) {
          final once = adapter.normalizeText(input);
          expect(
            adapter.normalizeText(once),
            once,
            reason: 'normalization must be idempotent for "$input"',
          );
        }
        expect(adapter.normalizeText(_nfd), adapter.normalizeText(_nfc));
        expect(adapter.normalizeText('a\r\nb'), 'a\nb');
      },
    );
  });

  group(
    'End-to-end through the real engine (R47) - the normalization actually changes acquisition behavior',
    () {
      test(
        'two URLs whose content differs ONLY by encoding now deduplicate to a single resource',
        () async {
          final engine = KnowledgeAcquisitionEngine(
            searchProvider: const _FixedSearchProvider([
              'https://example.com/lf',
              'https://example.com/crlf',
            ]),
            webweavexAdapter: WebWeaveXAdapter(
              fetchPage: _fetcherFor({
                'https://example.com/lf': _page('Guide', 'step one\nstep two'),
                'https://example.com/crlf': _page(
                  'Guide',
                  'step one\r\nstep two',
                ),
              }),
            ),
          );

          final bundle = await engine.acquire(
            requirements: [_req('how to do the thing')],
            queryHints: const [],
          );

          expect(bundle.status, BundleStatus.ready);
          expect(
            bundle.resources.length,
            1,
            reason:
                'before R47 these two hashed differently and BOTH reached the reasoner as separate knowledge',
          );
        },
      );

      test(
        'genuinely distinct sources are still both retained - dedup did not become over-eager',
        () async {
          final engine = KnowledgeAcquisitionEngine(
            searchProvider: const _FixedSearchProvider([
              'https://example.com/one',
              'https://example.com/two',
            ]),
            webweavexAdapter: WebWeaveXAdapter(
              fetchPage: _fetcherFor({
                'https://example.com/one': _page(
                  'One',
                  'first distinct body of knowledge',
                ),
                'https://example.com/two': _page(
                  'Two',
                  'second entirely separate body',
                ),
              }),
            ),
          );

          final bundle = await engine.acquire(
            requirements: [_req('topic')],
            queryHints: const [],
          );

          expect(bundle.resources.length, 2);
        },
      );

      test(
        'repeated acquisition of the same requirement yields byte-identical normalized representations',
        () async {
          final adapter = WebWeaveXAdapter(
            fetchPage: _fetcherFor({
              'https://example.com/a': _page('Alpha', 'stable knowledge'),
            }),
          );
          final engine = KnowledgeAcquisitionEngine(
            searchProvider: const _FixedSearchProvider([
              'https://example.com/a',
            ]),
            webweavexAdapter: adapter,
          );

          final first = await engine.acquire(
            requirements: [_req('stable topic')],
            queryHints: const [],
          );
          final second = await engine.acquire(
            requirements: [_req('stable topic')],
            queryHints: const [],
          );

          expect(first.resources, isNotEmpty);
          expect(second.resources, isNotEmpty);
          expect(
            second.resources.map(adapter.canonicalRepresentation).toList(),
            first.resources.map(adapter.canonicalRepresentation).toList(),
            reason:
                'THE headline R47 guarantee: repeated acquisitions produce identical normalized representations',
          );
          // Served from the EXISTING cache - no second cache layer was
          // introduced, the existing one simply now keys canonically.
          expect(second.status, BundleStatus.offlineCached);
        },
      );

      test(
        'canonically-equivalent QUERIES hit the same cache entry (Unicode-normalized cache key)',
        () async {
          var fetches = 0;
          final adapter = WebWeaveXAdapter(
            fetchPage: (url) async {
              fetches++;
              return {
                'url': url,
                'status': 200,
                'html': _page('Alpha', 'body'),
                'available': true,
              };
            },
          );
          final engine = KnowledgeAcquisitionEngine(
            searchProvider: const _FixedSearchProvider([
              'https://example.com/a',
            ]),
            webweavexAdapter: adapter,
          );

          await engine.acquire(
            requirements: [_req('$_nfc setup')],
            queryHints: const [],
          );
          final afterFirst = fetches;
          expect(
            afterFirst,
            greaterThan(0),
            reason: 'sanity: the first acquisition really did fetch',
          );

          await engine.acquire(
            requirements: [_req('$_nfd setup')],
            queryHints: const [],
          );

          expect(
            fetches,
            afterFirst,
            reason:
                'the NFD spelling of the same query must reuse the cached NFC entry rather than re-fetching',
          );
        },
      );
    },
  );

  group('Backward compatibility (R47)', () {
    test(
      'a bare KnowledgeAcquisitionEngine() is still completely network-free and unchanged',
      () async {
        final engine = KnowledgeAcquisitionEngine();
        final bundle = await engine.acquire(
          requirements: [_req('anything at all')],
          queryHints: const [],
        );

        expect(bundle.status, BundleStatus.failed);
        expect(bundle.resources, isEmpty);
        expect(bundle.unresolvedRequirements, contains('anything at all'));
        expect(
          bundle.warnings.any(
            (w) => w.contains('No knowledge provider configured'),
          ),
          isTrue,
        );
      },
    );

    test(
      'an empty requirement list still short-circuits to a ready, empty bundle',
      () async {
        final bundle = await KnowledgeAcquisitionEngine().acquire(
          requirements: const [],
          queryHints: const [],
        );
        expect(bundle.status, BundleStatus.ready);
        expect(bundle.resources, isEmpty);
      },
    );

    test(
      'an unreachable page still yields null rather than throwing - one bad candidate must not abort the rest',
      () async {
        final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor(const {}));
        expect(await adapter.extract('https://example.com/missing'), isNull);
        expect(await adapter.extract('not-a-url'), isNull);
        expect(
          await adapter.extractAll([
            'not-a-url',
            'https://example.com/missing',
          ]),
          isEmpty,
        );
      },
    );
  });
}
