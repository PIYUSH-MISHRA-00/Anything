/// Implementation Specification IS-R50 — Canonical Lifecycle, Retention and
/// Policy Framework.
///
/// REALITY before R50, established by repository audit: retention was invented
/// independently, three times, with three unexplained magic numbers — and one
/// domain had none at all.
///
///     IntentRepository._maxRecords          = 100   hardcoded, enforced inline
///     ActivityRepository._maxEvents         = 200   hardcoded, enforced inline
///     RealNotificationService.maxScheduled  = 200   hardcoded, added by R49
///     KnowledgeRepository                   = none  unbounded (gap G-18)
///     RealFileService tmp/exports           = none  wiped only on demand
///
/// Each was locally reasonable and collectively unreviewable: nobody could
/// answer "what does this application retain, and for how long?" without
/// reading five files.
///
/// R50 moves every one of those decisions into `RetentionPolicyEngine`. The
/// numbers are DELIBERATELY UNCHANGED (100/200/200) so this milestone changes
/// ownership without silently changing behaviour — which these tests assert
/// directly, because "we refactored and nothing moved" is a claim that has to
/// be demonstrated.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/retention_policy_engine.dart';
import 'package:anything/capabilities/adapters/file_service_adapter.dart';
import 'package:anything/capabilities/adapters/notification_service_adapter.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/intent_repository.dart';
import 'package:anything/storage/knowledge_repository.dart';

LifecycleCandidate _c(String id, DateTime at, {int? bytes, bool protected = false}) =>
    LifecycleCandidate(id: id, timestamp: at, sizeBytes: bytes, isProtected: protected);

PageFetcher _fetcherFor(Map<String, String> pages) => (String url) async {
  final html = pages[url];
  if (html == null) return {'url': url, 'status': 404, 'html': '', 'available': false};
  return {'url': url, 'status': 200, 'html': html, 'available': true};
};

String _page(String title, String body) =>
    '<html><head><title>$title</title></head><body><p>$body</p></body></html>';

var _dbSeq = 0;
String _freshDbName() => 'r50_${_dbSeq++}_${DateTime.now().microsecondsSinceEpoch}.db';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('RetentionPolicyEngine (R50) — the ONE decision-maker', () {
    const engine = RetentionPolicyEngine();
    final now = DateTime(2026, 8, 7, 12);

    test('an unregistered domain is UNBOUNDED — an unknown domain must never have data silently reclaimed', () {
      final evaluation = engine.evaluate(
        domain: 'not-a-real-domain',
        candidates: [for (var i = 0; i < 1000; i++) _c('x$i', now)],
        now: now,
      );
      expect(evaluation.reclaimsAnything, isFalse);
      expect(evaluation.policy.retentionClass, RetentionClass.durable);
    });

    test('count bound keeps the NEWEST and reclaims the oldest surplus', () {
      final evaluation = engine.evaluate(
        domain: LifecycleDomain.intents,
        candidates: [for (var i = 0; i < 130; i++) _c('i$i', now.subtract(Duration(minutes: i)))],
        now: now,
      );
      expect(evaluation.retainedIds.length, 100, reason: 'the pre-R50 intent bound of 100, unchanged');
      expect(evaluation.retainedIds.first, 'i0', reason: 'newest retained');
      expect(evaluation.reclaimedIds.length, 30);
      expect(evaluation.reclaimedIds, contains('i129'), reason: 'oldest reclaimed');
      expect(evaluation.evictedIds.length, 30, reason: 'over-budget, not aged out');
    });

    test('age bound EXPIRES rather than evicts — the reason reported is the honest one', () {
      final evaluation = engine.evaluate(
        domain: LifecycleDomain.temporaryFiles,
        candidates: [
          _c('fresh', now.subtract(const Duration(hours: 2))),
          _c('stale', now.subtract(const Duration(days: 3))),
        ],
        now: now,
      );
      expect(evaluation.retainedIds, ['fresh']);
      expect(evaluation.expiredIds, ['stale']);
      expect(evaluation.evictedIds, isEmpty, reason: 'aged-out records must not be mislabelled as over-budget');
      expect(
        evaluation.decisions.firstWhere((d) => d.id == 'stale').reason,
        contains('maximum age'),
      );
    });

    test('PROTECTED outranks every budget — a manual exemption that a budget can override is not an exemption', () {
      final evaluation = engine.evaluate(
        domain: LifecycleDomain.intents,
        candidates: [
          _c('protected-and-ancient', DateTime(2000), protected: true),
          for (var i = 0; i < 200; i++) _c('i$i', now.subtract(Duration(minutes: i))),
        ],
        now: now,
      );
      expect(evaluation.retainedIds, contains('protected-and-ancient'));
      expect(evaluation.reclaimedIds, isNot(contains('protected-and-ancient')));
    });

    test('byte bound evicts newest-first until the remainder fits', () {
      const tight = RetentionPolicyEngine(policies: {
        'sized': LifecyclePolicy(retentionClass: RetentionClass.bounded, maxBytes: 250),
      });
      final evaluation = tight.evaluate(
        domain: 'sized',
        candidates: [
          _c('a', now, bytes: 100),
          _c('b', now.subtract(const Duration(minutes: 1)), bytes: 100),
          _c('c', now.subtract(const Duration(minutes: 2)), bytes: 100),
        ],
        now: now,
      );
      expect(evaluation.retainedIds, ['a', 'b'], reason: '200 fits, 300 does not');
      expect(evaluation.evictedIds, ['c']);
      expect(evaluation.decisions.last.reason, contains('bytes'));
    });

    test('evaluation is deterministic — identical input yields identical decisions', () {
      final candidates = [for (var i = 0; i < 150; i++) _c('i$i', now.subtract(Duration(minutes: i % 40)))];
      final first = engine.evaluate(domain: LifecycleDomain.intents, candidates: candidates, now: now);
      final second = engine.evaluate(domain: LifecycleDomain.intents, candidates: candidates.reversed.toList(), now: now);
      expect(second.reclaimedIds, first.reclaimedIds,
          reason: 'ties are broken by id, so input ORDER cannot change the outcome');
    });

    test('the engine decides but never deletes — it holds no storage handle and performs no I/O', () {
      // Structural: evaluate() is pure and synchronous. If it ever needed to
      // delete, it could not be.
      final evaluation = engine.evaluate(domain: LifecycleDomain.intents, candidates: [_c('a', now)], now: now);
      expect(evaluation, isA<LifecycleEvaluation>());
      expect(evaluation.domain, LifecycleDomain.intents);
    });

    test('every canonical domain has a registered policy', () {
      for (final domain in LifecycleDomain.all) {
        expect(engine.policyFor(domain).isBounded, isTrue, reason: '$domain must have a real bound');
      }
    });
  });

  group('Behaviour is UNCHANGED where it was already bounded (R50 Task 9)', () {
    test('IntentRepository still keeps exactly 100 — the bound moved, it did not change', () async {
      const repo = IntentRepository();
      for (var i = 0; i < 130; i++) {
        await repo.save(IntentRecord(
          id: 'intent-$i',
          expression: 'e$i',
          modality: InputModality.text,
          status: IntentStatus.accepted,
          createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          updatedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ));
      }
      final all = await repo.list(limit: 1000);
      expect(all.length, 100, reason: 'identical to the pre-R50 _maxRecords behaviour');
      expect(all.any((r) => r.id == 'intent-129'), isTrue, reason: 'newest kept');
      expect(all.any((r) => r.id == 'intent-0'), isFalse, reason: 'oldest dropped');
    });

    test('ActivityRepository still keeps exactly 200', () async {
      const repo = ActivityRepository();
      for (var i = 0; i < 230; i++) {
        await repo.record(ActivityEvent(
          id: 'evt-$i',
          type: 'test',
          experienceName: 'X',
          message: 'm$i',
          timestamp: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ));
      }
      final all = await repo.list(limit: 1000);
      expect(all.length, 200, reason: 'identical to the pre-R50 _maxEvents behaviour');
    });

    test('RealNotificationService still keeps exactly 200', () async {
      final service = RealNotificationService();
      for (var i = 0; i < 230; i++) {
        await service.schedule(
          id: 'n$i',
          experienceId: 'e',
          title: 'T$i',
          body: '',
          scheduledTime: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        );
      }
      expect((await service.pending()).length, 200, reason: 'identical to R49\'s maxScheduled behaviour');
    });

    test('a caller may inject a different policy — the bound is now configurable rather than compiled in', () async {
      const tight = RetentionPolicyEngine(policies: {
        LifecycleDomain.intents: LifecyclePolicy(retentionClass: RetentionClass.bounded, maxEntries: 5),
      });
      const repo = IntentRepository(retention: tight);
      for (var i = 0; i < 20; i++) {
        await repo.save(IntentRecord(
          id: 'intent-$i',
          expression: 'e',
          modality: InputModality.text,
          status: IntentStatus.accepted,
          createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          updatedAt: DateTime(2026, 1, 1),
        ));
      }
      expect((await repo.list(limit: 1000)).length, 5,
          reason: 'the same repository, a different policy — which was impossible before R50');
    });
  });

  group('Knowledge retention (R50 Task 3) — closing gap G-18', () {
    test('persisted knowledge is now bounded, and the repository is TOLD what to drop rather than deciding', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({
        'https://example.com/a': _page('A', 'body a'),
        'https://example.com/b': _page('B', 'body b'),
        'https://example.com/c': _page('C', 'body c'),
      }));
      const tight = RetentionPolicyEngine(policies: {
        LifecycleDomain.knowledge: LifecyclePolicy(retentionClass: RetentionClass.bounded, maxEntries: 2),
      });

      final repo = KnowledgeRepository(dbName: dbName);
      addTearDown(repo.close);
      final cache = KnowledgeCache(repository: repo, canonicalizer: adapter, retention: tight);

      for (final letter in ['a', 'b', 'c']) {
        await cache.put(
          KnowledgeCacheKey(query: 'topic $letter', language: 'en'),
          [(await adapter.extract('https://example.com/$letter'))!],
        );
      }

      final keys = await repo.cacheKeys();
      expect(keys.length, 2, reason: 'before R50 this grew without any bound at all');
    });

    test('applyRetention() reclaims by AGE and reports what it reclaimed', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({'https://example.com/a': _page('A', 'body')}));
      const aged = RetentionPolicyEngine(policies: {
        LifecycleDomain.knowledge: LifecyclePolicy(retentionClass: RetentionClass.bounded, maxAge: Duration(days: 7)),
      });

      final repo = KnowledgeRepository(dbName: dbName);
      addTearDown(repo.close);
      final cache = KnowledgeCache(repository: repo, canonicalizer: adapter, retention: aged);
      await cache.put(const KnowledgeCacheKey(query: 'aged topic', language: 'en'),
          [(await adapter.extract('https://example.com/a'))!]);

      expect((await repo.cacheKeys()).length, 1);

      // Evaluate far in the future: the entry is now older than the policy.
      final reclaimed = await cache.applyRetention(now: DateTime.now().add(const Duration(days: 30)));

      expect(reclaimed.length, 1);
      expect(await repo.cacheKeys(), isEmpty);
    });

    test('keySummaries() reports facts without loading content — repository stays storage-only', () async {
      final dbName = _freshDbName();
      final adapter = WebWeaveXAdapter(fetchPage: _fetcherFor({'https://example.com/a': _page('A', 'body')}));
      final repo = KnowledgeRepository(dbName: dbName);
      addTearDown(repo.close);
      final cache = KnowledgeCache(repository: repo, canonicalizer: adapter);
      await cache.put(const KnowledgeCacheKey(query: 'q', language: 'en'),
          [(await adapter.extract('https://example.com/a'))!]);

      final summaries = await repo.keySummaries();
      expect(summaries.length, 1);
      expect(summaries.single.entryCount, 1);
      expect(summaries.single.totalBytes, greaterThan(0));
      expect(summaries.single.newestRetrievedAt.year, greaterThan(2000));
    });

    test('a non-persistent cache applying retention is a safe no-op', () async {
      expect(await KnowledgeCache().applyRetention(), isEmpty);
    });
  });

  group('File retention (R50 Task 6)', () {
    test('temporary files past their age are reclaimed; fresh ones and adopted Experience assets are not', () async {
      final root = Directory.systemTemp.createTempSync('r50_files_');
      addTearDown(() { if (root.existsSync()) root.deleteSync(recursive: true); });

      final service = RealFileService(rootOverride: root);
      await service.createTemporaryFile('scratch.bin', [1, 2, 3]);

      // An adopted Experience asset must NEVER be reclaimed by policy.
      final assetDir = Directory('${(await service.rootDirectory).path}/experiences/exp-a')..createSync(recursive: true);
      final asset = File('${assetDir.path}/precious.txt')..writeAsStringSync('user document');

      // Nothing is old yet.
      expect(await service.applyRetention(), isEmpty);

      // Far in the future, the scratch file has aged out.
      final deleted = await service.applyRetention(now: DateTime.now().add(const Duration(days: 5)));
      expect(deleted.length, 1);
      expect(deleted.single.contains('scratch.bin'), isTrue);

      expect(asset.existsSync(), isTrue,
          reason: 'a user\'s adopted document is never a retention outcome — only an explicit delete');
    });

    test('clearTemporaryFiles() remains an unconditional caller-initiated wipe, deliberately not policy-driven', () async {
      final root = Directory.systemTemp.createTempSync('r50_wipe_');
      addTearDown(() { if (root.existsSync()) root.deleteSync(recursive: true); });

      final service = RealFileService(rootOverride: root);
      final temp = await service.createTemporaryFile('fresh.bin', [1]);
      expect(temp!.existsSync(), isTrue);

      await service.clearTemporaryFiles();
      expect(temp.existsSync(), isFalse, reason: 'an explicit wipe must not consult a retention age');
    });
  });

  group('Ownership separation (R50) — two engines, disjoint domains', () {
    test('the retention engine decides nothing about runtimes, and returns retention actions only', () {
      const engine = RetentionPolicyEngine();
      final evaluation = engine.evaluate(
        domain: LifecycleDomain.intents,
        candidates: [_c('a', DateTime(2026))],
        now: DateTime(2026),
      );
      for (final decision in evaluation.decisions) {
        expect(LifecycleAction.values, contains(decision.action));
      }
      // The runtime vocabulary (pause/resume/terminate/restore) is a DIFFERENT
      // enum owned by WorkspaceLifecyclePolicyEngine. Merging them was
      // considered and rejected — see retention_policy_engine.dart's own doc
      // comment for the four concrete reasons.
      expect(LifecycleAction.values.map((a) => a.name),
          ['retain', 'evict', 'expire']);
    });
  });
}
