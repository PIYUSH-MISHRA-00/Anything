/// Implementation Specification IS-P04 — durable crash log and touch targets.
///
/// WHAT THE IS-P03 AUDIT FOUND. `main.dart`'s three error handlers all ended at
/// `debugPrint`, which reaches logcat and dies with the process. A user who hit
/// a crash had nothing to send and a maintainer had nothing to read (security
/// finding S-2). Separately, the compact button was 40 dp tall — below the
/// 48 dp minimum touch target.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anything/app/crash_log.dart';
import 'package:anything/design_system/components/anything_button.dart';

void main() {
  late Directory root;
  late CrashLog log;

  setUp(() {
    root = Directory.systemTemp.createTempSync('p04_crash_');
    log = CrashLog(rootOverride: root);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('A crash survives the process (IS-P04)', () {
    test('a recorded failure can be read back', () async {
      await log.record(
        StateError('runtime failed to open'),
        StackTrace.fromString('#0  AnythingRuntime.openExperience'),
        'zone',
      );

      final entries = await log.read();
      expect(entries, hasLength(1));
      expect(entries.single, contains('runtime failed to open'));
      expect(entries.single, contains('source : zone'));
      expect(
        entries.single,
        contains('AnythingRuntime.openExperience'),
        reason: 'the stack trace is the part worth keeping',
      );
    });

    test('a crash with no stack trace is still recorded', () async {
      await log.record('plain string failure', null, 'platform');
      final entries = await log.read();
      expect(entries.single, contains('plain string failure'));
    });

    test('entries are kept oldest first', () async {
      for (var i = 0; i < 3; i++) {
        await log.record('failure $i', null, 'flutter');
      }
      final entries = await log.read();
      expect(entries, hasLength(3));
      expect(entries.first, contains('failure 0'));
      expect(entries.last, contains('failure 2'));
    });

    test(
      'THE LOG IS BOUNDED — an unbounded file on a phone is a bug',
      () async {
        for (var i = 0; i < CrashLog.maxEntries + 12; i++) {
          await log.record('failure $i', null, 'zone');
        }

        final entries = await log.read();
        expect(entries, hasLength(CrashLog.maxEntries));
        expect(
          entries.last,
          contains('failure ${CrashLog.maxEntries + 11}'),
          reason: 'the MOST RECENT crashes are the ones worth keeping',
        );
        expect(
          entries.first,
          isNot(contains('failure 0')),
          reason: 'the oldest must have been dropped',
        );
      },
    );

    test(
      'a stack trace full of newlines does not corrupt the boundaries',
      () async {
        // The separator has to survive multi-line content, or two crashes read
        // back as one and the log becomes useless exactly when it matters.
        final noisy = StackTrace.fromString(
          '#0  a\n#1  b\n===== not a real separator =====\n#2  c',
        );
        await log.record('first', noisy, 'zone');
        await log.record('second', noisy, 'zone');

        final entries = await log.read();
        expect(entries, hasLength(2));
        expect(entries.first, contains('first'));
        expect(entries.last, contains('second'));
      },
    );

    test('clear() empties it', () async {
      await log.record('failure', null, 'zone');
      expect(await log.read(), hasLength(1));
      await log.clear();
      expect(await log.read(), isEmpty);
    });

    test(
      'reading before anything is recorded returns empty, not an error',
      () async {
        expect(await log.read(), isEmpty);
      },
    );
  });

  group('The logger never makes things worse (IS-P04)', () {
    test('RECORDING INTO AN IMPOSSIBLE LOCATION DOES NOT THROW', () async {
      // The load-bearing property. This runs inside an error handler: a logger
      // that throws while logging a crash turns one failure into two, and on
      // the zone path it can recurse forever.
      // A path that CANNOT become a directory, because a regular file already
      // occupies it. Deleting a directory would not do: `record` recreates its
      // parent, which is correct behaviour and would make this probe pass for
      // the wrong reason.
      final blocker = File('${root.path}${Platform.pathSeparator}blocked');
      blocker.writeAsStringSync('not a directory');
      final doomed = CrashLog(
        rootOverride: Directory(
          '${blocker.path}${Platform.pathSeparator}nested',
        ),
      );

      await expectLater(
        doomed.record(StateError('boom'), StackTrace.current, 'zone'),
        completes,
      );
      expect(await doomed.read(), isEmpty);
    });

    test('clear() on a missing file does not throw', () async {
      await expectLater(log.clear(), completes);
    });
  });

  group('Touch targets (IS-P04)', () {
    testWidgets('THE COMPACT BUTTON MEETS THE 48 dp MINIMUM', (t) async {
      // It was 40 dp — below the Material minimum and flagged by Android's own
      // accessibility scanner. "Compact" now means tighter padding and a
      // smaller font, not a smaller target.
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnythingButton(
                label: 'Compact',
                isCompact: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        t.getSize(find.byType(AnythingButton)).height,
        greaterThanOrEqualTo(48.0),
      );
    });

    testWidgets('the standard button also meets it', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnythingButton(label: 'Standard', onPressed: () {}),
            ),
          ),
        ),
      );

      expect(
        t.getSize(find.byType(AnythingButton)).height,
        greaterThanOrEqualTo(48.0),
      );
    });
  });
}
