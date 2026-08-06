/// Implementation Specification IS-R48 — Canonical Knowledge Persistence.
///
/// REALITY before R48: `KnowledgeCache` was purely in-memory and
/// process-scoped, documented in its own doc comment as a known limitation.
/// Every restart discarded all acquired knowledge and re-fetched it.
///
/// R47 removed the real blocker: resource ids and cache keys became canonical
/// (derived from `stableSerialize` rather than `DateTime.now()`), so persisted
/// rows finally mean something across runs. R48 persists them.
///
/// WHAT "RESTART" MEANS IN THESE TESTS. A genuinely new `KnowledgeCache` (and
/// where relevant a genuinely new `KnowledgeRepository` and
/// `KnowledgeAcquisitionEngine`) is constructed over the SAME database file,
/// with the previous instances closed first. No in-memory state is shared, so
/// anything that survives really came off disk.
///
/// A LATENT BUG THIS MILESTONE HAD TO FIX FIRST: `KnowledgeResource.toJson()`
/// omitted `content` entirely and `fromJson()` never read it, so
/// `fromJson(toJson(r))` silently produced `content == null`. Harmless while
/// nothing round-tripped resources; fatal here, because
/// `canonicalRepresentation()` includes `content` — a content-less round trip
/// would produce a DIFFERENT canonical representation after restart. Tested
/// directly below.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/storage/knowledge_repository.dart';

String _page(String title, String body) =>
    '<html><head><title>$title</title></head><body><p>$body</p></body></html>';

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

/// Counts real fetches, so "served from disk" can be proven by the absence of
/// network work rather than asserted.
class _CountingFetcher {
  final Map<String, String> pages;
  int fetches = 0;
  _CountingFetcher(this.pages);

  Future<Map<String, dynamic>> call(String url) async {
    fetches++;
    final html = pages[url];
    if (html == null) {
      return {'url': url, 'status': 404, 'html': '', 'available': false};
    }
    return {'url': url, 'status': 200, 'html': html, 'available': true};
  }
}

KnowledgeRequirement _req(String objective) =>
    KnowledgeRequirement(objective: objective, resourceType: 'webDocument');

var _dbSeq = 0;
String _freshDbName() => 'r48_knowledge_${_dbSeq++}_'
    '${DateTime.now().microsecondsSinceEpoch}.db';

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('Round-trip integrity (R48) — the latent toJson bug that had to be fixed first', () {
    test('KnowledgeResource.fromJson(toJson(r)) now preserves content — before R48 it silently returned null', () {
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor(const {}));
      final now = DateTime(2026, 8, 6, 12, 30);
      final original = KnowledgeResource(
        id: 'wwx-abc',
        type: KnowledgeResourceType.webDocument,
        title: 'Title',
        sourceUri: 'https://example.com/a',
        sourceDomain: 'example.com',
        retrievedAt: now,
        content: 'the actual knowledge body',
        contentHash: KnowledgeResource.computeHash('the actual knowledge body'),
        provenance: ResourceProvenance(
          sourceUrl: 'https://example.com/a',
          sourceDomain: 'example.com',
          retrievedAt: now,
          provider: 'webweavex',
        ),
        license: const LicenseMetadata(policy: LicensePolicy.unknownReviewRequired),
        trust: const TrustMetadata(level: TrustLevel.unknown, reason: 'r'),
        freshness: FreshnessMetadata(lastModified: now),
        ranking: const RankingMetadata(relevanceScore: 0.5),
      );

      final restored = KnowledgeResource.fromJson(original.toJson());

      expect(restored.content, original.content, reason: 'the R48 fix: content must survive the round trip');
      expect(restored.contentHash, original.contentHash);
      expect(restored.retrievedAt, original.retrievedAt, reason: 'retrievedAt is preserved SEPARATELY as provenance');
      expect(
        adapter.canonicalRepresentation(restored),
        adapter.canonicalRepresentation(original),
        reason: 'the canonical representation depends on content, so a content-less round trip would silently change it',
      );
    });
  });

  group('Repository (R48) — the durable store, exercised directly', () {
    test('stores and returns resources for exactly one key, preserving order, identity, hash and canonical representation', () async {
      final repo = KnowledgeRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/a': _page('Alpha', 'first body'),
        'https://example.com/b': _page('Beta', 'second body'),
      }));

      final a = (await adapter.extract('https://example.com/a'))!;
      final b = (await adapter.extract('https://example.com/b'))!;

      await repo.putResources('k1', [
        PersistedKnowledgeResource(resource: a, canonicalRepresentation: adapter.canonicalRepresentation(a)),
        PersistedKnowledgeResource(resource: b, canonicalRepresentation: adapter.canonicalRepresentation(b)),
      ]);

      final loaded = await repo.resourcesFor('k1');
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[0].resource.id, a.id, reason: 'stored order must be preserved, not merely set-equality');
      expect(loaded[1].resource.id, b.id);
      expect(loaded[0].resource.contentHash, a.contentHash);
      expect(loaded[0].canonicalRepresentation, adapter.canonicalRepresentation(a));
      expect(adapter.canonicalRepresentation(loaded[0].resource), adapter.canonicalRepresentation(a));

      expect(await repo.resourcesFor('unknown-key'), isNull, reason: 'a miss must be null, distinguishable from a genuinely empty hit');
    });

    test('putResources REPLACES a key rather than accumulating — the existing replace-on-put semantics, applied to storage', () async {
      final repo = KnowledgeRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/a': _page('Alpha', 'first body'),
        'https://example.com/b': _page('Beta', 'second body'),
      }));
      final a = (await adapter.extract('https://example.com/a'))!;
      final b = (await adapter.extract('https://example.com/b'))!;

      await repo.putResources('k1', [
        PersistedKnowledgeResource(resource: a, canonicalRepresentation: adapter.canonicalRepresentation(a)),
        PersistedKnowledgeResource(resource: b, canonicalRepresentation: adapter.canonicalRepresentation(b)),
      ]);
      expect(await repo.resourceCount(), 2);

      await repo.putResources('k1', [
        PersistedKnowledgeResource(resource: b, canonicalRepresentation: adapter.canonicalRepresentation(b)),
      ]);

      expect(await repo.resourceCount(), 1, reason: 'no stale rows may accumulate for a replaced key');
      final loaded = await repo.resourcesFor('k1');
      expect(loaded!.single.resource.id, b.id);
    });

    test('a row whose content no longer matches its stored hash is DROPPED, never repaired and never served', () async {
      final dbName = _freshDbName();
      final repo = KnowledgeRepository(dbName: dbName);
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/a': _page('Alpha', 'trustworthy body'),
      }));
      final a = (await adapter.extract('https://example.com/a'))!;
      await repo.putResources('k1', [
        PersistedKnowledgeResource(resource: a, canonicalRepresentation: adapter.canonicalRepresentation(a)),
      ]);

      // Tamper with the persisted content, leaving the hash column intact.
      final db = await repo.database;
      final rows = await db.query('knowledge_resources');
      final json = rows.first['resource_json'] as String;
      await db.update(
        'knowledge_resources',
        {'resource_json': json.replaceAll('trustworthy body', 'tampered body')},
        where: 'cache_key = ?',
        whereArgs: ['k1'],
      );

      expect(await repo.resourcesFor('k1'), isNull,
          reason: 'serving silently-corrupted knowledge to the reasoner would be worse than a cache miss');
      await repo.close();
    });

    test('clear() and removeKey() really empty the durable store', () async {
      final repo = KnowledgeRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({'https://example.com/a': _page('A', 'body')}));
      final a = (await adapter.extract('https://example.com/a'))!;

      await repo.putResources('k1', [PersistedKnowledgeResource(resource: a, canonicalRepresentation: adapter.canonicalRepresentation(a))]);
      await repo.putResources('k2', [PersistedKnowledgeResource(resource: a, canonicalRepresentation: adapter.canonicalRepresentation(a))]);
      expect((await repo.cacheKeys()).length, 2);

      await repo.removeKey('k1');
      expect(await repo.cacheKeys(), ['k2']);

      await repo.clear();
      expect(await repo.cacheKeys(), isEmpty);
      expect(await repo.resourceCount(), 0);
    });
  });

  group('Restart equivalence (R48) — the load-bearing guarantee', () {
    test('canonical ids, hashes and representations are IDENTICAL after a genuine restart', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/a': _page('Alpha', 'durable knowledge body'),
      }));
      const key = KnowledgeCacheKey(query: 'durable topic', language: 'en');

      // ── Session 1 ──
      final repo1 = KnowledgeRepository(dbName: dbName);
      final cache1 = KnowledgeCache(repository: repo1, canonicalizer: adapter);
      expect(cache1.isPersistent, isTrue);
      final original = (await adapter.extract('https://example.com/a'))!;
      await cache1.put(key, [original]);
      await repo1.close();

      // ── Restart: brand-new repository and cache over the same file ──
      final repo2 = KnowledgeRepository(dbName: dbName);
      addTearDown(repo2.close);
      final cache2 = KnowledgeCache(repository: repo2, canonicalizer: adapter);
      expect(cache2.size, 0, reason: 'a fresh cache starts with nothing resident — no eager load');

      final restored = await cache2.get(key);
      expect(restored, isNotNull, reason: 'knowledge must survive restart');
      expect(restored!.length, 1);

      final r = restored.single;
      expect(r.id, original.id, reason: 'canonical id must be identical after restart');
      expect(r.contentHash, original.contentHash, reason: 'canonical hash must be identical after restart');
      expect(r.content, original.content);
      expect(
        adapter.canonicalRepresentation(r),
        adapter.canonicalRepresentation(original),
        reason: 'canonical representation must be byte-identical after restart',
      );

      // Provenance and metadata survive too.
      expect(r.retrievedAt, original.retrievedAt);
      expect(r.sourceUri, original.sourceUri);
      expect(r.sourceDomain, original.sourceDomain);
      expect(r.title, original.title);
      expect(r.trust.level, original.trust.level);
      expect(r.trust.reason, original.trust.reason);
      expect(r.license.policy, original.license.policy);
      expect(r.ranking.relevanceScore, original.ranking.relevanceScore);
      expect(r.ranking.overallScore, original.ranking.overallScore);
      expect(r.provenance.provider, original.provenance.provider);
      expect(r.provenance.sourceUrl, original.provenance.sourceUrl);
      expect(r.freshness.lastModified, original.freshness.lastModified);
    });

    test('a resource RE-EXTRACTED after restart matches the one restored from disk — proves the id is canonical, not merely round-tripped', () async {
      // The restart test above would still pass if ids were timestamp-derived,
      // because it extracts ONCE and then only round-trips the stored value.
      // This one re-extracts the same page in "session 2" and requires the
      // fresh id to equal the persisted one — which is only true if identity
      // is genuinely canonical. A mutation reintroducing
      // `DateTime.now().microsecondsSinceEpoch` fails here.
      final dbName = _freshDbName();
      final pages = {'https://example.com/a': _page('Alpha', 'canonical body')};
      const key = KnowledgeCacheKey(query: 'canonical topic', language: 'en');

      final repo1 = KnowledgeRepository(dbName: dbName);
      final adapter1 = WebWeaveXAdapter(fetchPage: _fetcherFor(pages));
      final acquired = (await adapter1.extract('https://example.com/a'))!;
      await KnowledgeCache(repository: repo1, canonicalizer: adapter1).put(key, [acquired]);
      await repo1.close();

      // Session 2: a brand-new adapter re-extracts the same page.
      final repo2 = KnowledgeRepository(dbName: dbName);
      addTearDown(repo2.close);
      final adapter2 = WebWeaveXAdapter(fetchPage: _fetcherFor(pages));
      final restored = (await KnowledgeCache(repository: repo2, canonicalizer: adapter2).get(key))!.single;
      final reExtracted = (await adapter2.extract('https://example.com/a'))!;

      expect(reExtracted.id, restored.id,
          reason: 'a freshly-extracted resource must carry the SAME canonical id as the one persisted in a previous session');
      expect(reExtracted.contentHash, restored.contentHash);
      expect(adapter2.canonicalRepresentation(reExtracted), adapter2.canonicalRepresentation(restored));
    });

    test('repeated loads are byte-identical to each other — deterministic replay, not merely deterministic once', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/a': _page('Alpha', 'replayable body'),
      }));
      const key = KnowledgeCacheKey(query: 'replay topic', language: 'en');

      final repo1 = KnowledgeRepository(dbName: dbName);
      final original = (await adapter.extract('https://example.com/a'))!;
      await KnowledgeCache(repository: repo1, canonicalizer: adapter).put(key, [original]);
      await repo1.close();

      final representations = <String>[];
      for (var i = 0; i < 3; i++) {
        final repo = KnowledgeRepository(dbName: dbName);
        final loaded = await KnowledgeCache(repository: repo, canonicalizer: adapter).get(key);
        representations.add(adapter.canonicalRepresentation(loaded!.single));
        await repo.close();
      }

      expect(representations.toSet().length, 1, reason: 'three independent loads must produce ONE canonical representation');
      expect(representations.first, adapter.canonicalRepresentation(original));
    });

    test('the full acquisition pipeline survives restart — a new engine serves from disk WITHOUT re-fetching', () async {
      final dbName = _freshDbName();
      final fetcher = _CountingFetcher({'https://example.com/a': _page('Alpha', 'engine-level body')});
      final adapter = WebWeaveXAdapter(fetchPage: fetcher.call);

      // ── Session 1: real acquisition ──
      final repo1 = KnowledgeRepository(dbName: dbName);
      final engine1 = KnowledgeAcquisitionEngine(
        searchProvider: const _FixedSearchProvider(['https://example.com/a']),
        webweavexAdapter: adapter,
        cache: KnowledgeCache(repository: repo1, canonicalizer: adapter),
      );
      final first = await engine1.acquire(requirements: [_req('engine topic')], queryHints: const []);
      expect(first.status, BundleStatus.ready);
      expect(first.resources, isNotEmpty);
      final fetchesAfterFirst = fetcher.fetches;
      expect(fetchesAfterFirst, greaterThan(0), reason: 'sanity: session 1 really fetched');
      await repo1.close();

      // ── Restart: brand-new engine, repository and cache ──
      final repo2 = KnowledgeRepository(dbName: dbName);
      addTearDown(repo2.close);
      final engine2 = KnowledgeAcquisitionEngine(
        searchProvider: const _FixedSearchProvider(['https://example.com/a']),
        webweavexAdapter: adapter,
        cache: KnowledgeCache(repository: repo2, canonicalizer: adapter),
      );
      final second = await engine2.acquire(requirements: [_req('engine topic')], queryHints: const []);

      expect(fetcher.fetches, fetchesAfterFirst, reason: 'THE point of R48: after restart the knowledge came off disk, with zero new network work');
      expect(second.status, BundleStatus.offlineCached);
      expect(
        second.resources.map(adapter.canonicalRepresentation).toList(),
        first.resources.map(adapter.canonicalRepresentation).toList(),
        reason: 'restored bundle must be canonically identical to the acquired one',
      );
      expect(second.resources.map((r) => r.id).toList(), first.resources.map((r) => r.id).toList());
    });
  });

  group('Restoration is lazy and incremental (R48 performance rules)', () {
    test('a fresh persistent cache loads NOTHING until a key is actually requested', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/a': _page('A', 'body a'),
        'https://example.com/b': _page('B', 'body b'),
      }));
      const keyA = KnowledgeCacheKey(query: 'topic a', language: 'en');
      const keyB = KnowledgeCacheKey(query: 'topic b', language: 'en');

      final repo1 = KnowledgeRepository(dbName: dbName);
      final cache1 = KnowledgeCache(repository: repo1, canonicalizer: adapter);
      await cache1.put(keyA, [(await adapter.extract('https://example.com/a'))!]);
      await cache1.put(keyB, [(await adapter.extract('https://example.com/b'))!]);
      await repo1.close();

      final repo2 = KnowledgeRepository(dbName: dbName);
      addTearDown(repo2.close);
      final cache2 = KnowledgeCache(repository: repo2, canonicalizer: adapter);

      expect(cache2.size, 0, reason: 'construction must not eagerly load anything');
      expect((await repo2.cacheKeys()).length, 2, reason: 'both keys really are on disk');

      await cache2.get(keyA);
      expect(cache2.size, 1, reason: 'exactly ONE key was hydrated — not the whole store');

      await cache2.get(keyB);
      expect(cache2.size, 2);
    });

    test('a hydrated key is promoted into memory, so the second read does not touch storage again', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({'https://example.com/a': _page('A', 'body')}));
      const key = KnowledgeCacheKey(query: 'promote', language: 'en');

      final repo1 = KnowledgeRepository(dbName: dbName);
      await KnowledgeCache(repository: repo1, canonicalizer: adapter)
          .put(key, [(await adapter.extract('https://example.com/a'))!]);
      await repo1.close();

      final repo2 = KnowledgeRepository(dbName: dbName);
      final cache2 = KnowledgeCache(repository: repo2, canonicalizer: adapter);
      final firstRead = await cache2.get(key);
      expect(firstRead, isNotNull);
      expect(cache2.size, 1);

      // Close the store: a second read that still succeeds proves it was
      // served from memory, not re-read from disk.
      await repo2.close();
      final secondRead = await cache2.get(key);
      expect(secondRead, isNotNull);
      expect(secondRead!.single.id, firstRead!.single.id);
    });
  });

  group('Single-cache and invalidation semantics (R48)', () {
    test('clear() empties BOTH memory and durable storage — one cache, one clear', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({'https://example.com/a': _page('A', 'body')}));
      const key = KnowledgeCacheKey(query: 'clearable', language: 'en');

      final repo = KnowledgeRepository(dbName: dbName);
      addTearDown(repo.close);
      final cache = KnowledgeCache(repository: repo, canonicalizer: adapter);
      await cache.put(key, [(await adapter.extract('https://example.com/a'))!]);
      expect(await repo.resourceCount(), 1);

      await cache.clear();

      expect(cache.size, 0);
      expect(await repo.resourceCount(), 0, reason: 'a cleared cache must not leave durable rows behind to resurrect');
      expect(await cache.get(key), isNull);
    });

    test('re-putting a key replaces it in storage too, so restart sees the NEW value', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/old': _page('Old', 'stale body'),
        'https://example.com/new': _page('New', 'fresh body'),
      }));
      const key = KnowledgeCacheKey(query: 'replaceable', language: 'en');

      final repo1 = KnowledgeRepository(dbName: dbName);
      final cache1 = KnowledgeCache(repository: repo1, canonicalizer: adapter);
      await cache1.put(key, [(await adapter.extract('https://example.com/old'))!]);
      final fresh = (await adapter.extract('https://example.com/new'))!;
      await cache1.put(key, [fresh]);
      await repo1.close();

      final repo2 = KnowledgeRepository(dbName: dbName);
      addTearDown(repo2.close);
      final restored = await KnowledgeCache(repository: repo2, canonicalizer: adapter).get(key);

      expect(restored!.single.id, fresh.id);
      expect(restored.single.content, contains('fresh body'));
      expect(await repo2.resourceCount(), 1, reason: 'the replaced value must not linger alongside the new one');
    });
  });

  group('Backward compatibility (R48)', () {
    test('a bare KnowledgeCache() is still purely in-memory and behaves exactly as before', () async {
      final cache = KnowledgeCache();
      expect(cache.isPersistent, isFalse);

      const key = KnowledgeCacheKey(query: 'ephemeral', language: 'en');
      expect(await cache.get(key), isNull);
      expect(cache.size, 0);

      final now = DateTime(2026);
      final resource = KnowledgeResource(
        id: 'x',
        type: KnowledgeResourceType.webDocument,
        title: 'T',
        sourceUri: 'https://example.com/x',
        sourceDomain: 'example.com',
        retrievedAt: now,
        content: 'body',
        contentHash: KnowledgeResource.computeHash('body'),
        provenance: ResourceProvenance(sourceUrl: 'https://example.com/x', sourceDomain: 'example.com', retrievedAt: now, provider: 'webweavex'),
        license: const LicenseMetadata(policy: LicensePolicy.unknownReviewRequired),
        trust: const TrustMetadata(level: TrustLevel.unknown, reason: 'r'),
        freshness: FreshnessMetadata(lastModified: now),
        ranking: const RankingMetadata(),
      );

      await cache.put(key, [resource]);
      expect((await cache.get(key))!.single.id, 'x');
      expect(cache.size, 1);
      await cache.clear();
      expect(cache.size, 0);
    });

    test('a cache with a repository but NO canonicalizer stays in-memory rather than persisting something it cannot canonicalize', () async {
      final repo = KnowledgeRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final cache = KnowledgeCache(repository: repo);

      expect(cache.isPersistent, isFalse);

      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({'https://example.com/a': _page('A', 'body')}));
      await cache.put(const KnowledgeCacheKey(query: 'q', language: 'en'), [
        (await adapter.extract('https://example.com/a'))!,
      ]);

      expect(await repo.resourceCount(), 0, reason: 'half-configured persistence must be inert, not partial');
    });

    test('the bare, network-free KnowledgeAcquisitionEngine() is completely unchanged by R48', () async {
      final engine = KnowledgeAcquisitionEngine();
      final bundle = await engine.acquire(requirements: [_req('anything at all')], queryHints: const []);

      expect(bundle.status, BundleStatus.failed);
      expect(bundle.resources, isEmpty);
      expect(bundle.unresolvedRequirements, contains('anything at all'));
    });

    test('the legacy pre-seeded pool (store/findRelevant) still works and is unaffected by persistence', () async {
      final repo = KnowledgeRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({'https://example.com/guide': _page('Loan Guide', 'body')}));
      final cache = KnowledgeCache(repository: repo, canonicalizer: adapter);

      await cache.store([(await adapter.extract('https://example.com/guide'))!]);

      expect(cache.findRelevant('loan'), isNotNull);
      expect(cache.findRelevant('nothing-like-this'), isNull);
    });
  });
}
