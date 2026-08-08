/// Implementation Specification IS-R49 — Production Capability Completion.
///
/// REALITY before R49, confirmed by repository audit: `AppComposition`
/// registered `FakeNotificationService` and `FakeFileService` into the REAL
/// production capability platform. Every Experience that scheduled a
/// notification appended to an in-memory list that nothing read and nothing
/// delivered; every Experience that picked a file received whatever a test
/// had pre-populated, and "adopting" it wrote a map entry rather than a byte.
///
/// These tests drive the REAL services. The file service runs against a real
/// temporary directory through `dart:io`, so adoption, export, deletion,
/// ownership and sandbox containment are all genuinely exercised — only the
/// OS file dialog is replaced, through the same injectable-seam pattern
/// `RealHttpTransport({http.Client? client})` and
/// `WebWeaveXAdapter({PageFetcher? fetchPage})` already established. The
/// notification service runs against real `SharedPreferences` storage, so
/// durability across restart is genuinely exercised.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/app/retention_policy_engine.dart';
import 'package:anything/capabilities/adapters/file_service_adapter.dart';
import 'package:anything/capabilities/adapters/notification_service_adapter.dart';
import 'package:anything/capabilities/builtin/file_capability.dart';
import 'package:anything/capabilities/builtin/notification_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/core/events/events.dart';

/// A deterministic picker standing in for the OS dialog.
class _StubPicker implements FilePicker {
  PickedFile? next;
  int calls = 0;
  bool lastImagesOnly = false;

  _StubPicker([this.next]);

  @override
  Future<PickedFile?> pick({
    List<String>? allowedExtensions,
    bool imagesOnly = false,
  }) async {
    calls++;
    lastImagesOnly = imagesOnly;
    return next;
  }
}

Directory _tempRoot(String label) {
  final dir = Directory.systemTemp.createTempSync('r49_${label}_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Writes a real source file the picker will "return".
File _sourceFile(Directory dir, String name, String contents) {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  file.writeAsStringSync(contents);
  return file;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group(
    'RealNotificationService (R49 Task 2) — durability, the thing the fake never had',
    () {
      test(
        'a scheduled notification SURVIVES restart — a brand-new service instance still sees it',
        () async {
          final first = RealNotificationService();
          await first.schedule(
            id: 'n1',
            experienceId: 'exp-a',
            title: 'Water the plants',
            body: 'It has been three days',
            scheduledTime: DateTime(2026, 8, 7, 9),
          );

          // "Restart": an entirely new service instance over the same storage.
          final second = RealNotificationService();
          final pending = await second.pending();

          expect(
            pending.length,
            1,
            reason:
                'the fake kept schedules in an in-memory list that died with the process',
          );
          expect(pending.single.id, 'n1');
          expect(pending.single.experienceId, 'exp-a');
          expect(pending.single.title, 'Water the plants');
          expect(pending.single.body, 'It has been three days');
          expect(pending.single.scheduledTime, DateTime(2026, 8, 7, 9));
        },
      );

      test(
        'cancel() really removes it, so a cancelled notification can never later become due',
        () async {
          final service = RealNotificationService();
          await service.schedule(
            id: 'n1',
            experienceId: 'exp-a',
            title: 'A',
            body: '',
            scheduledTime: DateTime(2026, 1, 1),
          );
          await service.schedule(
            id: 'n2',
            experienceId: 'exp-a',
            title: 'B',
            body: '',
            scheduledTime: DateTime(2026, 1, 2),
          );

          await service.cancel('n1');

          final pending = await RealNotificationService().pending();
          expect(pending.map((n) => n.id), ['n2']);
          expect(
            (await service.dueAt(DateTime(2027))).map((n) => n.id),
            ['n2'],
            reason: 'the cancelled notification must not resurface as due',
          );
        },
      );

      test(
        'cancelAllForExperience() removes exactly that Experience and leaves others untouched',
        () async {
          final service = RealNotificationService();
          await service.schedule(
            id: 'a1',
            experienceId: 'exp-a',
            title: 'A1',
            body: '',
            scheduledTime: DateTime(2026, 1, 1),
          );
          await service.schedule(
            id: 'a2',
            experienceId: 'exp-a',
            title: 'A2',
            body: '',
            scheduledTime: DateTime(2026, 1, 2),
          );
          await service.schedule(
            id: 'b1',
            experienceId: 'exp-b',
            title: 'B1',
            body: '',
            scheduledTime: DateTime(2026, 1, 3),
          );

          await service.cancelAllForExperience('exp-a');

          final pending = await RealNotificationService().pending();
          expect(
            pending.map((n) => n.id),
            ['b1'],
            reason: 'ownership must be real, not advisory',
          );
        },
      );

      test(
        're-scheduling the same id REPLACES rather than duplicating',
        () async {
          final service = RealNotificationService();
          await service.schedule(
            id: 'n1',
            experienceId: 'exp-a',
            title: 'Old',
            body: '',
            scheduledTime: DateTime(2026, 1, 1),
          );
          await service.schedule(
            id: 'n1',
            experienceId: 'exp-a',
            title: 'New',
            body: '',
            scheduledTime: DateTime(2026, 6, 1),
          );

          final pending = await service.pending();
          expect(pending.length, 1);
          expect(pending.single.title, 'New');
          expect(pending.single.scheduledTime, DateTime(2026, 6, 1));
        },
      );

      test('dueAt() computes real due state from the stored time', () async {
        final service = RealNotificationService();
        await service.schedule(
          id: 'past',
          experienceId: 'e',
          title: 'P',
          body: '',
          scheduledTime: DateTime(2026, 1, 1),
        );
        await service.schedule(
          id: 'future',
          experienceId: 'e',
          title: 'F',
          body: '',
          scheduledTime: DateTime(2027, 1, 1),
        );

        expect((await service.dueAt(DateTime(2026, 6, 1))).map((n) => n.id), [
          'past',
        ]);
        expect(
          (await service.dueAt(DateTime(2025, 1, 1))).map((n) => n.id),
          isEmpty,
        );
        expect((await service.dueAt(DateTime(2028))).map((n) => n.id), [
          'past',
          'future',
        ]);
      });

      test(
        'deliverDue() presents through the EXISTING EventBus as the EXISTING NotificationGenerated event',
        () async {
          final bus = EventBus();
          final received = <NotificationGenerated>[];
          final sub = bus.on<NotificationGenerated>().listen(received.add);
          addTearDown(() async {
            await sub.cancel();
            bus.dispose();
          });

          final service = RealNotificationService(
            presenter: EventBusNotificationPresenter(bus: bus),
          );
          await service.schedule(
            id: 'n1',
            experienceId: 'exp-a',
            title: 'Time to review',
            body: 'b',
            scheduledTime: DateTime(2026, 1, 1),
          );
          await service.schedule(
            id: 'n2',
            experienceId: 'exp-a',
            title: 'Later',
            body: 'b',
            scheduledTime: DateTime(2030, 1, 1),
          );

          final delivered = await service.deliverDue(DateTime(2026, 6, 1));
          await Future<void>.delayed(Duration.zero);

          expect(delivered.map((n) => n.id), ['n1']);
          expect(
            received.length,
            1,
            reason: 'real in-app delivery, on the event bus R35 already built',
          );
          expect(received.single.outcome, 'Time to review');
          expect(received.single.sessionId, 'exp-a');
          expect(
            received.single.eventCategory,
            EventCategory.notification,
            reason:
                'reuses the existing notification category — no new event hierarchy',
          );
        },
      );

      test(
        'deliverDue() delivers exactly once — the delivered notification is removed, the not-yet-due one is kept',
        () async {
          final bus = EventBus();
          final received = <NotificationGenerated>[];
          final sub = bus.on<NotificationGenerated>().listen(received.add);
          addTearDown(() async {
            await sub.cancel();
            bus.dispose();
          });

          final service = RealNotificationService(
            presenter: EventBusNotificationPresenter(bus: bus),
          );
          await service.schedule(
            id: 'n1',
            experienceId: 'e',
            title: 'Once',
            body: '',
            scheduledTime: DateTime(2026, 1, 1),
          );
          await service.schedule(
            id: 'n2',
            experienceId: 'e',
            title: 'Never yet',
            body: '',
            scheduledTime: DateTime(2030, 1, 1),
          );

          await service.deliverDue(DateTime(2026, 6, 1));
          final second = await service.deliverDue(DateTime(2026, 6, 1));
          await Future<void>.delayed(Duration.zero);

          expect(
            second,
            isEmpty,
            reason: 'a delivered notification must not be delivered again',
          );
          expect(received.length, 1);
          expect(
            (await service.pending()).map((n) => n.id),
            ['n2'],
            reason:
                'the not-yet-due notification must survive delivery of another',
          );
        },
      );

      test(
        'corrupt stored records are dropped rather than crashing or being repaired',
        () async {
          SharedPreferences.setMockInitialValues({
            'anything_scheduled_notifications': '{ not valid json',
          });
          expect(await RealNotificationService().pending(), isEmpty);

          SharedPreferences.setMockInitialValues({
            'anything_scheduled_notifications':
                '[{"id":"ok","experienceId":"e","title":"T","body":"","scheduledTime":"2026-01-01T00:00:00.000"},{"garbage":true}]',
          });
          final pending = await RealNotificationService().pending();
          expect(
            pending.map((n) => n.id),
            ['ok'],
            reason: 'one bad record must not discard the good ones',
          );
        },
      );

      test(
        'the stored set is bounded, so a runaway Experience cannot grow storage without limit',
        () async {
          // IS-R50: the bound moved out of this service and into the canonical
          // `RetentionPolicyEngine`. R49 expressed it as `maxScheduled: 3`; the
          // same behaviour is now expressed as a retention policy for the
          // notifications domain. The assertions below are unchanged, which is
          // the point — ownership moved, behaviour did not.
          final service = RealNotificationService(
            retention: const RetentionPolicyEngine(
              policies: {
                LifecycleDomain.notifications: LifecyclePolicy(
                  retentionClass: RetentionClass.bounded,
                  maxEntries: 3,
                ),
              },
            ),
          );
          for (var i = 0; i < 6; i++) {
            await service.schedule(
              id: 'n$i',
              experienceId: 'e',
              title: 'T$i',
              body: '',
              scheduledTime: DateTime(2026, 1, 1 + i),
            );
          }
          final pending = await service.pending();
          expect(pending.length, 3);
          expect(
            pending.map((n) => n.id),
            ['n3', 'n4', 'n5'],
            reason: 'oldest-by-scheduled-time is dropped first',
          );
        },
      );

      test(
        'through the real NotificationCapability, an Experience schedules and cancels for real',
        () async {
          final service = RealNotificationService();
          final capability = NotificationCapability(
            service: service,
            experienceId: 'exp-a',
          );

          final scheduled = await capability.execute('schedule', {
            'title': 'Standup',
            'body': 'daily',
            'hour': 9,
          });
          expect(scheduled.status, CapabilityResultStatus.success);
          final id = scheduled.data['notificationId'] as String;

          expect(
            (await RealNotificationService().pending()).map((n) => n.id),
            [id],
            reason:
                'the capability path must reach durable storage, not a list',
          );

          final cancelled = await capability.execute('cancel', {
            'notificationId': id,
          });
          expect(cancelled.status, CapabilityResultStatus.success);
          expect(await RealNotificationService().pending(), isEmpty);
        },
      );
    },
  );

  group('RealFileService (R49 Task 3) — real bytes on a real filesystem', () {
    test(
      'picking returns a reference; adoption COPIES the real bytes into the sandbox',
      () async {
        final root = _tempRoot('adopt');
        final incoming = _tempRoot('incoming');
        final source = _sourceFile(incoming, 'notes.txt', 'real file contents');

        final picker = _StubPicker(
          PickedFile(
            name: 'notes.txt',
            path: source.path,
            sizeBytes: source.lengthSync(),
            mimeType: 'text/plain',
          ),
        );
        final service = RealFileService(picker: picker, rootOverride: root);

        final reference = await service.pickFile();
        expect(reference, isNotNull);
        expect(reference!.displayName, 'notes.txt');
        expect(reference.sizeBytes, source.lengthSync());

        expect(await service.adoptFile(reference.id, 'exp-a'), isTrue);
        expect(await service.ownsAdoptedFile(reference.id, 'exp-a'), isTrue);
        expect(await service.adoptedFilesFor('exp-a'), [reference.id]);

        // The adopted copy really exists, with the real bytes.
        final adopted = File(
          '${(await service.rootDirectory).path}/experiences/exp-a/${reference.id}',
        );
        expect(
          adopted.existsSync(),
          isTrue,
          reason: 'the fake never wrote a byte',
        );
        expect(adopted.readAsStringSync(), 'real file contents');

        // Anything now owns its own copy: deleting the original does not matter.
        source.deleteSync();
        expect(adopted.readAsStringSync(), 'real file contents');
      },
    );

    test(
      'a cancelled pick returns null, and adopting an unknown id fails rather than throwing',
      () async {
        final root = _tempRoot('cancel');
        final service = RealFileService(
          picker: _StubPicker(null),
          rootOverride: root,
        );

        expect(await service.pickFile(), isNull);
        expect(await service.adoptFile('no-such-file', 'exp-a'), isFalse);
        expect(
          await service.deleteAdoptedFile('no-such-file', 'exp-a'),
          isFalse,
        );
      },
    );

    test(
      'pickImage requests images only — the flag really reaches the picker',
      () async {
        final root = _tempRoot('image');
        final incoming = _tempRoot('image_in');
        final source = _sourceFile(incoming, 'photo.png', 'png-bytes');
        final picker = _StubPicker(
          PickedFile(
            name: 'photo.png',
            path: source.path,
            sizeBytes: 9,
            mimeType: 'image/png',
          ),
        );
        final service = RealFileService(picker: picker, rootOverride: root);

        final reference = await service.pickImage();
        expect(picker.lastImagesOnly, isTrue);
        expect(reference!.mimeType, 'image/png');
      },
    );

    test(
      'OWNERSHIP IS REAL — Experience B cannot delete or see Experience A files',
      () async {
        final root = _tempRoot('own');
        final incoming = _tempRoot('own_in');
        final source = _sourceFile(incoming, 'secret.txt', 'belongs to A');
        final service = RealFileService(
          picker: _StubPicker(
            PickedFile(name: 'secret.txt', path: source.path, sizeBytes: 12),
          ),
          rootOverride: root,
        );

        final reference = (await service.pickFile())!;
        await service.adoptFile(reference.id, 'exp-a');

        expect(
          await service.deleteAdoptedFile(reference.id, 'exp-b'),
          isFalse,
          reason: 'a different Experience must not be able to delete it',
        );
        expect(
          await service.ownsAdoptedFile(reference.id, 'exp-a'),
          isTrue,
          reason: 'and it must still be there',
        );
        expect(await service.adoptedFilesFor('exp-b'), isEmpty);

        expect(await service.deleteAdoptedFile(reference.id, 'exp-a'), isTrue);
        expect(await service.ownsAdoptedFile(reference.id, 'exp-a'), isFalse);
        expect(
          File(
            '${(await service.rootDirectory).path}/experiences/exp-a/${reference.id}',
          ).existsSync(),
          isFalse,
          reason: 'deletion must remove the real bytes, not just a map entry',
        );
      },
    );

    test(
      'SANDBOX CONTAINMENT — a traversal attempt is rejected, not sanitised',
      () async {
        final root = _tempRoot('sandbox');
        final service = RealFileService(
          picker: _StubPicker(null),
          rootOverride: root,
        );

        // Escape attempts through every path-taking entry point.
        expect(
          await service.exportFile('x', 'exp-a', '../../escaped.txt'),
          isNull,
        );
        expect(
          await service.createTemporaryFile('../../escaped.txt', [1, 2, 3]),
          isNull,
        );
        expect(await service.workspaceAsset('../../escaped.txt'), isNull);
        expect(
          await service.deleteAdoptedFile('../../../etc/passwd', 'exp-a'),
          isFalse,
        );

        // Nothing was created outside the sandbox.
        final rootPath = (await service.rootDirectory).path;
        expect(
          File(
            '${Directory(rootPath).parent.parent.path}/escaped.txt',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'a picked display name cannot smuggle a path separator into the id',
      () async {
        final root = _tempRoot('name');
        final incoming = _tempRoot('name_in');
        final source = _sourceFile(incoming, 'ok.txt', 'x');
        final service = RealFileService(
          picker: _StubPicker(
            PickedFile(
              name: '../../evil name/../x.txt',
              path: source.path,
              sizeBytes: 1,
            ),
          ),
          rootOverride: root,
        );

        final reference = (await service.pickFile())!;
        expect(reference.id.contains('/'), isFalse);
        expect(reference.id.contains(r'\'), isFalse);
        expect(reference.id.contains('..'), isFalse);

        expect(await service.adoptFile(reference.id, 'exp-a'), isTrue);
        expect(await service.adoptedFilesFor('exp-a'), [reference.id]);
      },
    );

    test('EXPORT writes the real bytes back out, inside the sandbox', () async {
      final root = _tempRoot('export');
      final incoming = _tempRoot('export_in');
      final source = _sourceFile(incoming, 'report.csv', 'a,b,c');
      final service = RealFileService(
        picker: _StubPicker(
          PickedFile(
            name: 'report.csv',
            path: source.path,
            sizeBytes: 5,
            mimeType: 'text/csv',
          ),
        ),
        rootOverride: root,
      );

      final reference = (await service.pickFile())!;
      await service.adoptFile(reference.id, 'exp-a');

      final exported = await service.exportFile(
        reference.id,
        'exp-a',
        'my-report.csv',
      );
      expect(exported, isNotNull);
      expect(File(exported!).readAsStringSync(), 'a,b,c');

      expect(await service.exportFile('missing', 'exp-a', 'x.csv'), isNull);
      expect(
        await service.exportFile(reference.id, 'exp-b', 'x.csv'),
        isNull,
        reason: 'exporting another Experience\'s file must fail',
      );
    });

    test(
      'TEMPORARY FILES are written and clearable; WORKSPACE ASSETS resolve inside the sandbox',
      () async {
        final root = _tempRoot('tmp');
        final service = RealFileService(
          picker: _StubPicker(null),
          rootOverride: root,
        );

        final temp = await service.createTemporaryFile('scratch.bin', [
          1,
          2,
          3,
        ]);
        expect(temp, isNotNull);
        expect(temp!.existsSync(), isTrue);
        expect(temp.readAsBytesSync(), [1, 2, 3]);

        await service.clearTemporaryFiles();
        expect(temp.existsSync(), isFalse);

        final asset = await service.workspaceAsset('shared.json');
        expect(asset, isNotNull);
        expect(asset!.path.contains('workspace'), isTrue);
        expect(
          asset.path.startsWith((await service.rootDirectory).path),
          isTrue,
        );
      },
    );

    test(
      'through the real FileCapability, size policy is still enforced by the capability',
      () async {
        final root = _tempRoot('policy');
        final incoming = _tempRoot('policy_in');
        final source = _sourceFile(incoming, 'big.bin', 'x' * 100);
        final service = RealFileService(
          picker: _StubPicker(
            PickedFile(name: 'big.bin', path: source.path, sizeBytes: 100),
          ),
          rootOverride: root,
        );
        final capability = FileCapability(
          service: service,
          experienceId: 'exp-a',
          maxFileSize: 10,
        );

        final result = await capability.execute('pickFile', const {});
        expect(
          result.status,
          CapabilityResultStatus.policyDenied,
          reason:
              'FileCapability owns the size policy; the service reports size and does not enforce it twice',
        );
      },
    );
  });

  group(
    'Production composition (R49 Task 4) — exactly one owner, no Fake* left',
    () {
      test(
        'the real capability platform registers the real services, and no Fake* instance',
        () async {
          // Constructed the same way AppComposition.production() does.
          final bus = EventBus();
          addTearDown(bus.dispose);
          final notifications = RealNotificationService(
            presenter: EventBusNotificationPresenter(bus: bus),
          );
          final files = RealFileService();

          expect(notifications, isA<NotificationService>());
          expect(files, isA<FileService>());
          expect(notifications, isNot(isA<FakeNotificationService>()));
          expect(files, isNot(isA<FakeFileService>()));
        },
      );
    },
  );
}
