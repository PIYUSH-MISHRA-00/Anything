/// IS-P26 — default protection-time preference + Settings control.
///
/// Verifies the persisted default seeds the per-Experience protect flow and
/// never claims to be a global override. No mocks of Kaalka — this tests the
/// preference contract and the Settings control's presence/persistence.
library;

import 'package:anything/features/preferences/protection_preferences.dart';
import 'package:anything/features/preferences/protection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProtectionPreferences', () {
    test('defaults to use-current-time when nothing is stored', () async {
      final pref = await const ProtectionPreferences().load();
      expect(pref.useCurrentTime, isTrue);
      expect(pref.label, 'Use current time');
    });

    test('persists a custom time and survives a fresh load', () async {
      await const ProtectionPreferences().setCustomTime(3, 23);
      final pref = await const ProtectionPreferences().load();
      expect(pref.useCurrentTime, isFalse);
      expect(pref.hour, 3);
      expect(pref.minute, 23);
      expect(pref.label, '03:23');
    });

    test('setUseCurrentTime clears a previously custom default', () async {
      await const ProtectionPreferences().setCustomTime(9, 5);
      await const ProtectionPreferences().setUseCurrentTime();
      final pref = await const ProtectionPreferences().load();
      expect(pref.useCurrentTime, isTrue);
    });

    test(
      'invalid seed values are clamped, never written out of range',
      () async {
        await const ProtectionPreferences().setCustomTime(99, -7);
        final pref = await const ProtectionPreferences().load();
        expect(pref.hour, inInclusiveRange(0, 23));
        expect(pref.minute, inInclusiveRange(0, 59));
      },
    );
  });

  group('ProtectionScreen control', () {
    testWidgets('shows the Default protection time control', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: ProtectionScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Default protection time'), findsOneWidget);
      expect(find.text('Use current time'), findsWidgets);
      // Honest framing: it is a default, not a global override.
      expect(find.textContaining('never changes'), findsOneWidget);
    });

    testWidgets('reflects a persisted custom default on open', (tester) async {
      SharedPreferences.setMockInitialValues({
        'anything_protection_time_mode': 1,
        'anything_protection_time_hour': 3,
        'anything_protection_time_minute': 23,
      });
      await tester.pumpWidget(const MaterialApp(home: ProtectionScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('03:23'), findsWidgets);
    });
  });
}
