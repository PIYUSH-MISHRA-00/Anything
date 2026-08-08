/// Anything application root.
///
/// Sets up theme, navigation, and the app shell.
library;

import 'package:flutter/material.dart';

import '../design_system/theme/anything_theme.dart';
import '../design_system/theme/theme_provider.dart';
import 'app_shell.dart';
import '../features/onboarding/onboarding_screen.dart';

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
          home: _AnythingRoot(themeNotifier: _themeNotifier),
        );
      },
    );
  }
}

/// Decides whether a launch shows onboarding or the app (IS-P05 finding 11).
///
/// A gate rather than a route so there is still exactly ONE entry point and
/// one app widget — the property I-85 certifies.
class _AnythingRoot extends StatefulWidget {
  final AnythingThemeNotifier themeNotifier;

  const _AnythingRoot({required this.themeNotifier});

  @override
  State<_AnythingRoot> createState() => _AnythingRootState();
}

class _AnythingRootState extends State<_AnythingRoot> {
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    var completed = false;
    try {
      completed = await const OnboardingState().hasCompleted();
    } catch (_) {
      // If the preference cannot be read, show the app rather than trapping
      // the user in onboarding they cannot get past.
      completed = true;
    }
    if (mounted) setState(() => _needsOnboarding = !completed);
  }

  @override
  Widget build(BuildContext context) {
    // One frame of the plain surface colour while the preference is read.
    // Deliberately not a spinner: it would flash on every launch for a check
    // that takes microseconds.
    if (_needsOnboarding == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: const SizedBox.expand(),
      );
    }
    if (_needsOnboarding!) {
      return OnboardingScreen(
        onFinished: () => setState(() => _needsOnboarding = false),
      );
    }
    return AnythingAppShell(themeNotifier: widget.themeNotifier);
  }
}
