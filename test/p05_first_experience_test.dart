/// Implementation Specification IS-P05 — first-user-experience completion.
///
/// Manual testing on a moto g45 5G reported several controls that did nothing.
/// These tests pin the behaviours that replaced them, so a dead button cannot
/// come back silently.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/features/onboarding/onboarding_screen.dart';
import 'package:anything/features/preferences/about_screen.dart';
import 'package:anything/features/preferences/protection_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Onboarding (finding 11)', () {
    test('a fresh install has not completed onboarding', () async {
      expect(await const OnboardingState().hasCompleted(), isFalse);
    });

    test('completing it is remembered, and can be replayed', () async {
      const state = OnboardingState();
      await state.markCompleted();
      expect(await state.hasCompleted(), isTrue);

      // Finding 12: a walkthrough you cannot see again is one you have to get
      // right on the first read.
      await state.reset();
      expect(await state.hasCompleted(), isFalse);
    });

    testWidgets('it renders, advances, and can be skipped', (t) async {
      var finished = false;
      await t.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () => finished = true)),
      );

      expect(find.text('Describe what you need'), findsOneWidget);

      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('You get an Experience'), findsOneWidget);

      await t.tap(find.text('Skip'));
      await t.pumpAndSettle();
      expect(finished, isTrue);
    });

    testWidgets('IT SAYS WHAT IS NOT BUILT', (t) async {
      // The project's documents state their own gaps; the first thing a user
      // reads should not be the exception. A new user told the truth early
      // forgives a limitation; one who discovers it alone does not.
      await t.pumpWidget(
        MaterialApp(home: OnboardingScreen(onFinished: () {})),
      );

      for (var i = 0; i < 2; i++) {
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
      }

      expect(
        find.textContaining('Only Groq is supported today'),
        findsOneWidget,
      );
    });

    testWidgets('it survives a 2.0x text scale', (t) async {
      // The same defect class IS-P03 found twice: an overflow paints a warning
      // rather than throwing, so nothing fails without an explicit check.
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(home: OnboardingScreen(onFinished: () {})),
        ),
      );

      final exception = t.takeException();
      expect(
        exception,
        isNull,
        reason: 'onboarding must not overflow at large system font sizes',
      );
    });
  });

  group('Dead buttons now lead somewhere (findings 7, 9)', () {
    testWidgets('Protection explains the model instead of doing nothing', (
      t,
    ) async {
      await t.pumpWidget(const MaterialApp(home: ProtectionScreen()));
      await t.pumpAndSettle();

      expect(find.text('Kaalka Protection'), findsOneWidget);
      expect(find.textContaining('Time-keyed encryption'), findsOneWidget);

      // Below the fold: a ListView only builds what is visible, so these have
      // to be scrolled to rather than merely existing in the source.
      await t.scrollUntilVisible(
        find.text('MANUAL TIME CONFIGURATION'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // Finding 8 is answered on screen rather than implemented, so the answer
      // has to actually be present.
      expect(find.text('MANUAL TIME CONFIGURATION'), findsOneWidget);

      await t.scrollUntilVisible(
        find.text('NOT BUILT YET'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // And it states what does not exist.
      expect(find.text('NOT BUILT YET'), findsOneWidget);
    });

    testWidgets('Protection routes to where protection actually happens', (
      t,
    ) async {
      var opened = false;
      await t.pumpWidget(
        MaterialApp(
          home: ProtectionScreen(onOpenExperiences: () => opened = true),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.text('Go to My Apps'));
      await t.pumpAndSettle();
      expect(opened, isTrue);
    });

    testWidgets('About renders without a platform channel', (t) async {
      // PackageInfo is unavailable in a widget test; the screen must degrade
      // to sensible defaults rather than showing a blank page.
      await t.pumpWidget(const MaterialApp(home: AboutScreen()));
      await t.pumpAndSettle();

      expect(find.text('About Anything'), findsOneWidget);

      await t.scrollUntilVisible(
        find.text('Apache License 2.0'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Apache License 2.0'), findsOneWidget);

      await t.scrollUntilVisible(
        find.textContaining('Experiences you create with Anything are yours'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Experiences you create with Anything are yours'),
        findsOneWidget,
      );
    });
  });
}
