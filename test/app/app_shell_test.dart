/// Tests for application shell and navigation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/app/app.dart';
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
  });

  group('AnythingApp', () {
    testWidgets('renders MaterialApp', (tester) async {
      await tester.pumpWidget(const AnythingApp());
      // Use pump instead of pumpAndSettle to avoid timeout from continuous animations
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows Anything title', (tester) async {
      await tester.pumpWidget(const AnythingApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Anything'), findsOneWidget);
    });

    testWidgets('has home navigation icon', (tester) async {
      await tester.pumpWidget(const AnythingApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.home_filled), findsOneWidget);
    });
  });

  group('Theme switching', () {
    testWidgets('defaults to system theme', (tester) async {
      await tester.pumpWidget(const AnythingApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.system);
    });
  });
}
