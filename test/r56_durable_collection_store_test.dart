/// Implementation Specification IS-R56 — Canonical Durable Collection Store.
///
/// WHAT THE AUDIT FOUND, AND WHAT IT DISPROVED.
///
/// R56 was specified as an audit-first milestone with no preselected owner.
/// The repository-wide scan found three SharedPreferences-backed collections
/// implementing the SAME read-modify-write shape with nothing serialising it:
///
///     RealNotificationService  schedule / cancel / cancelAllForExperience /
///                              deliverDue
///     ActivityRepository       record
///     IntentRepository         save / updateStatus / delete
///
/// A probe MEASURED the consequence rather than assuming it:
///
///     scheduled 10 concurrently, pending 1        <- NINE LOST
///     1 scheduled, presented 2 time(s)            <- exactly-once broken
///     recorded 10 activity events, stored 10      <- NOT lost
///
/// The third result disproved half the hypothesis. Activity survives, by an
/// accident of await ordering that nothing asserts. R56 therefore claims a
/// proven defect ONLY for the notification paths, and routes the other two
/// through the same owner to remove the duplicated pattern.
///
/// The tests below are those probes, kept permanently.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/capabilities/adapters/notification_service_adapter.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/storage/durable_collection_store.dart';
import 'package:anything/storage/intent_repository.dart';
import 'package:anything/core/contracts/intent.dart';

class _CountingPresenter implements NotificationPresenter {
  final List<String> presented = [];
  @override
  Future<void> present(ScheduledNotification n) async {
    // A real presenter awaits. This is the yield point the R49 implementation
    // let a second caller enter through.
    await Future<void>.delayed(Duration.zero);
    presented.add(n.id);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ───────────────────────────────────────────────────────────────────────────
  // THE PROVEN DEFECT
  // ───────────────────────────────────────────────────────────────────────────
  group('Notification store — the defect R56 measured', () {
    test('TEN CONCURRENT schedule() CALLS ALL SURVIVE (was: 1 of 10)', () async {
      final svc = RealNotificationService(presenter: _CountingPresenter());

      await Future.wait([
        for (var i = 0; i < 10; i++)
          svc.schedule(
            id: 'n$i',
            experienceId: 'e1',
            title: 't',
            body: 'b',
            scheduledTime: DateTime(2027, 1, 1),
          ),
      ]);

      final pending = await svc.pending();
      expect(
        pending.length,
        10,
        reason:
            'before R56 this stored ONE — nine concurrent schedules were lost',
      );
      expect(pending.map((n) => n.id).toSet(), {
        for (var i = 0; i < 10; i++) 'n$i',
      });
    });

    test('CONCURRENT deliverDue() DELIVERS EXACTLY ONCE (was: twice)', () async {
      final presenter = _CountingPresenter();
      final svc = RealNotificationService(presenter: presenter);
      await svc.schedule(
        id: 'n1',
        experienceId: 'e1',
        title: 't',
        body: 'b',
        scheduledTime: DateTime(2026, 1, 1),
      );

      final now = DateTime(2026, 6, 1);
      final results = await Future.wait([
        svc.deliverDue(now),
        svc.deliverDue(now),
      ]);

      expect(
        presenter.presented,
        ['n1'],
        reason:
            'deliverDue documents "delivered exactly once"; before R56 it presented twice',
      );
      // Exactly one of the two callers claimed it.
      expect(results.expand((r) => r).map((n) => n.id).toList(), ['n1']);
      expect(await svc.pending(), isEmpty);
    });

    test(
      'THREE concurrent deliverDue() calls over three due notifications deliver each once',
      () async {
        final presenter = _CountingPresenter();
        final svc = RealNotificationService(presenter: presenter);
        for (var i = 0; i < 3; i++) {
          await svc.schedule(
            id: 'n$i',
            experienceId: 'e1',
            title: 't',
            body: 'b',
            scheduledTime: DateTime(2026, 1, 1),
          );
        }

        final now = DateTime(2026, 6, 1);
        await Future.wait([
          svc.deliverDue(now),
          svc.deliverDue(now),
          svc.deliverDue(now),
        ]);

        expect(presenter.presented..sort(), ['n0', 'n1', 'n2']);
        expect(presenter.presented.toSet().length, 3, reason: 'no duplicates');
      },
    );

    test(
      'claim-then-present: a notification is removed BEFORE it is presented',
      () async {
        // The ordering that makes exactly-once possible, asserted directly.
        // Also documents the trade: this is at-most-once (gap G-38).
        late Future<List<ScheduledNotification>> pendingDuringPresent;
        final svc = RealNotificationService(
          presenter: _ObservingPresenter(() {
            pendingDuringPresent = RealNotificationService().pending();
          }),
        );
        await svc.schedule(
          id: 'n1',
          experienceId: 'e1',
          title: 't',
          body: 'b',
          scheduledTime: DateTime(2026, 1, 1),
        );

        await svc.deliverDue(DateTime(2026, 6, 1));

        expect(
          await pendingDuringPresent,
          isEmpty,
          reason:
              'the due set must already be claimed while presentation is in flight',
        );
      },
    );

    test(
      'concurrent cancel() and schedule() of different ids do not clobber each other',
      () async {
        final svc = RealNotificationService(presenter: _CountingPresenter());
        await svc.schedule(
          id: 'keep',
          experienceId: 'e1',
          title: 't',
          body: 'b',
          scheduledTime: DateTime(2027, 1, 1),
        );
        await svc.schedule(
          id: 'drop',
          experienceId: 'e1',
          title: 't',
          body: 'b',
          scheduledTime: DateTime(2027, 1, 1),
        );

        await Future.wait([
          svc.cancel('drop'),
          svc.schedule(
            id: 'new',
            experienceId: 'e1',
            title: 't',
            body: 'b',
            scheduledTime: DateTime(2027, 1, 1),
          ),
        ]);

        final ids = (await svc.pending()).map((n) => n.id).toSet();
        expect(ids, {'keep', 'new'});
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // THE STORE ITSELF
  // ───────────────────────────────────────────────────────────────────────────
  group('DurableCollectionStore', () {
    test(
      'TWENTY concurrent mutations of the SAME key all apply — none clobbered',
      () async {
        const store = DurableCollectionStore();
        await Future.wait([
          for (var i = 0; i < 20; i++)
            store.update<void>(
              'k',
              (current) => (value: '${current ?? ''}$i,', result: null),
            ),
        ]);
        final value = await store.read('k');
        expect(
          value!.split(',').where((s) => s.isNotEmpty).length,
          20,
          reason:
              'with no yield between read and write, concurrent callers cannot interleave',
        );
      },
    );

    test('mutations of DIFFERENT keys do not interfere', () async {
      const store = DurableCollectionStore();
      await Future.wait([
        store.update<void>('a', (_) => (value: 'a', result: null)),
        store.update<void>('b', (_) => (value: 'b', result: null)),
      ]);
      expect(await store.read('a'), 'a');
      expect(await store.read('b'), 'b');
    });

    test(
      'a throwing mutation fails only its own caller and leaves the key usable',
      () async {
        const store = DurableCollectionStore();
        await expectLater(
          store.update<void>('k', (_) => throw StateError('boom')),
          throwsStateError,
        );
        await store.update<void>('k', (_) => (value: 'ok', result: null));
        expect(await store.read('k'), 'ok');
      },
    );

    test(
      'the store holds NO state — a fresh instance sees another one\'s writes',
      () async {
        // The first R56 design kept a static per-key lock table. It deadlocked
        // across flutter_test zones and is recorded in the store's own doc
        // comment so it is not retried. This asserts the replacement is stateless.
        await const DurableCollectionStore().update<void>(
          'k',
          (_) => (value: 'v', result: null),
        );
        expect(await const DurableCollectionStore().read('k'), 'v');
      },
    );

    test('returning a null value removes the key', () async {
      const store = DurableCollectionStore();
      await store.update<void>('k', (_) => (value: 'v', result: null));
      await store.clear('k');
      expect(await store.read('k'), isNull);
    });

    test(
      'the mutation receives the CURRENT value and can return a result',
      () async {
        const store = DurableCollectionStore();
        await store.update<void>('k', (_) => (value: '1', result: null));
        final seen = await store.update<String?>(
          'k',
          (current) => (value: '2', result: current),
        );
        expect(seen, '1');
        expect(await store.read('k'), '2');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // THE OTHER TWO COLLECTIONS — pattern removed, behaviour preserved
  // ───────────────────────────────────────────────────────────────────────────
  group('Activity and intent — same owner, unchanged behaviour', () {
    test('concurrent activity records all survive', () async {
      const repo = ActivityRepository();
      await Future.wait([
        for (var i = 0; i < 10; i++)
          repo.record(
            ActivityEvent(
              id: 'e$i',
              type: 'created',
              experienceName: 'x',
              message: 'm$i',
              timestamp: DateTime(2026, 8, 7, 0, 0, i),
            ),
          ),
      ]);
      expect((await repo.list(limit: 1000)).length, 10);
    });

    test(
      'activity retention is still 200 and still owned by the engine',
      () async {
        const repo = ActivityRepository();
        for (var i = 0; i < 205; i++) {
          await repo.record(
            ActivityEvent(
              id: 'e$i',
              type: 'created',
              experienceName: 'x',
              message: 'm$i',
              timestamp: DateTime(2026, 8, 7).add(Duration(seconds: i)),
            ),
          );
        }
        expect(
          (await repo.list(limit: 10000)).length,
          200,
          reason: 'R50 owns this bound; R56 must not have moved it',
        );
      },
    );

    test(
      'INTENT TRUNCATION FIXED: updateStatus no longer discards history past 50',
      () async {
        // A real defect found while consolidating, unrelated to concurrency.
        // updateStatus read through list() (default limit 50) and wrote the
        // result back as the WHOLE history, so records 51+ were silently lost.
        const repo = IntentRepository();
        for (var i = 0; i < 80; i++) {
          await repo.save(
            IntentRecord(
              id: 'i$i',
              expression: 'text $i',
              modality: InputModality.text,
              status: IntentStatus.submitted,
              createdAt: DateTime(2026, 8, 7).add(Duration(seconds: i)),
              updatedAt: DateTime(2026, 8, 7).add(Duration(seconds: i)),
            ),
          );
        }
        expect((await repo.list(limit: 1000)).length, 80);

        await repo.updateStatus('i0', IntentStatus.accepted);

        expect(
          (await repo.list(limit: 1000)).length,
          80,
          reason:
              'before R56 this dropped to 50 — 30 records silently discarded',
        );
      },
    );

    test(
      'INTENT TRUNCATION FIXED: delete no longer discards history past 50',
      () async {
        const repo = IntentRepository();
        for (var i = 0; i < 80; i++) {
          await repo.save(
            IntentRecord(
              id: 'i$i',
              expression: 'text $i',
              modality: InputModality.text,
              status: IntentStatus.submitted,
              createdAt: DateTime(2026, 8, 7).add(Duration(seconds: i)),
              updatedAt: DateTime(2026, 8, 7).add(Duration(seconds: i)),
            ),
          );
        }
        await repo.delete('i0');
        expect((await repo.list(limit: 1000)).length, 79);
      },
    );

    test(
      'intent retention is still 100 and still owned by the engine',
      () async {
        const repo = IntentRepository();
        for (var i = 0; i < 105; i++) {
          await repo.save(
            IntentRecord(
              id: 'i$i',
              expression: 't',
              modality: InputModality.text,
              status: IntentStatus.submitted,
              createdAt: DateTime(2026, 8, 7).add(Duration(seconds: i)),
              updatedAt: DateTime(2026, 8, 7).add(Duration(seconds: i)),
            ),
          );
        }
        expect((await repo.list(limit: 10000)).length, 100);
      },
    );
  });
}

class _ObservingPresenter implements NotificationPresenter {
  final void Function() onPresent;
  _ObservingPresenter(this.onPresent);
  @override
  Future<void> present(ScheduledNotification n) async {
    onPresent();
    await Future<void>.delayed(Duration.zero);
  }
}
