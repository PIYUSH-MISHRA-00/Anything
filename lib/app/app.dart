/// Anything application root.
///
/// Sets up theme, navigation, and the app shell.
library;

import 'package:flutter/material.dart';

import '../design_system/theme/anything_theme.dart';
import '../design_system/theme/theme_provider.dart';
import 'app_shell.dart';

/// The Anything application.
class AnythingApp extends StatefulWidget {
  const AnythingApp({super.key});

  @override
  State<AnythingApp> createState() => _AnythingAppState();
}

class _AnythingAppState extends State<AnythingApp> {
  final AnythingThemeNotifier _themeNotifier = AnythingThemeNotifier();

  @override
  void initState() {
    super.initState();
    _themeNotifier.load();
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'Anything',
          debugShowCheckedModeBanner: false,
          theme: buildAnythingLightTheme(),
          darkTheme: buildAnythingDarkTheme(),
          themeMode: _themeNotifier.themeMode,
          home: AnythingAppShell(themeNotifier: _themeNotifier),
        );
      },
    );
  }
}
