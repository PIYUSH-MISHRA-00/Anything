/// Tests for theme system.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anything/design_system/theme/anything_theme.dart';
import 'package:anything/design_system/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnythingThemeNotifier', () {
    test('defaults to system mode', () {
      final notifier = AnythingThemeNotifier();
      expect(notifier.mode, AnythingThemeMode.system);
      expect(notifier.themeMode, ThemeMode.system);
    });

    test('setMode changes mode', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AnythingThemeNotifier();
      await notifier.setMode(AnythingThemeMode.dark);
      expect(notifier.mode, AnythingThemeMode.dark);
      expect(notifier.themeMode, ThemeMode.dark);
    });

    test('setMode notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AnythingThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);
      await notifier.setMode(AnythingThemeMode.light);
      expect(notified, isTrue);
    });

    test('setMode with same value does not notify', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AnythingThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);
      await notifier.setMode(AnythingThemeMode.system);
      expect(notified, isFalse);
    });

    test('load restores persisted mode', () async {
      SharedPreferences.setMockInitialValues({
        'anything_theme_mode': 2, // dark
      });
      final notifier = AnythingThemeNotifier();
      await notifier.load();
      expect(notifier.mode, AnythingThemeMode.dark);
    });
  });

  group('ThemeData', () {
    testWidgets('light theme has correct brightness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildAnythingLightTheme(), home: const Scaffold()),
      );
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.brightness, Brightness.light);
    });

    testWidgets('dark theme has correct brightness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildAnythingDarkTheme(), home: const Scaffold()),
      );
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.brightness, Brightness.dark);
    });

    testWidgets('both themes use Material 3', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildAnythingLightTheme(), home: const Scaffold()),
      );
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.useMaterial3, isTrue);
    });
  });
}
