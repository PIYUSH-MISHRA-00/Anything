/// Tests for application shell and navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/app/app.dart';
import 'package:anything/app/app_composition.dart';
import 'package:anything/features/onboarding/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for widget tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // IS-P05: first launch now shows onboarding (finding 11), so `AnythingApp`
  // no longer goes straight to the shell. These tests exercise the RETURNING
  // user, which was always their implicit subject -- now stated explicitly
  // rather than relying on onboarding not existing.
  setUp(() {
    SharedPreferences.setMockInitialValues({
      OnboardingState.storageKey: 'true',
    });
    // IS-P07: the composition root is now a process-wide singleton, and it
    // caches the provider registry's in-flight storage load. `flutter_test`
    // replaces the zone between tests, so a future completed in the previous
    // test would never complete in this one and the launch gate would wait
    // forever. Each test here launches the real app, so each gets a new graph.
    AppComposition.resetForTesting();
  });

  // IS-P07: the launch gate now AWAITS provider initialisation before it
  // decides between onboarding and the shell, so reaching the shell takes
  // more asynchronous hops than the two pumps these tests used to do.
  // `pumpAndSettle` is still wrong here for the reason stated below, so pump
  // a bounded number of frames instead.
  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(const AnythingApp());
    // Pump rather than pumpAndSettle: the shell has continuous animations,
    // which would make pumpAndSettle time out.
    // Enough pumped time to cover the registry's bounded keystore wait: this
    // test does not mock `flutter_secure_storage`, and an unmocked channel
    // never answers, so the launch gate deliberately gives up after its
    // timeout and starts the app anyway. That is the behaviour under test.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('AnythingApp', () {
    testWidgets('renders MaterialApp', (tester) async {
      await launch(tester);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows Anything title', (tester) async {
      await launch(tester);
      expect(find.text('Anything'), findsOneWidget);
    });

    testWidgets('has home navigation icon', (tester) async {
      await launch(tester);
      expect(find.byIcon(Icons.home_filled), findsOneWidget);
    });
  });

  group('Theme switching', () {
    testWidgets('defaults to system theme', (tester) async {
      await launch(tester);
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.system);
    });
  });
}
