/// Anything application shell with bottom navigation.
///
/// Follows the Stitch floating pill bottom nav pattern.
/// Home | My Apps | Activity | Preferences
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/theme/theme_provider.dart';
import '../features/home/home_screen.dart';
import '../features/experiences/experiences_screen.dart';
import '../features/activity/activity_screen.dart';
import '../features/preferences/preferences_screen.dart';
import 'app_composition.dart';

/// The main application shell with bottom navigation.
class AnythingAppShell extends StatefulWidget {
  final AnythingThemeNotifier themeNotifier;

  const AnythingAppShell({super.key, required this.themeNotifier});

  @override
  State<AnythingAppShell> createState() => _AnythingAppShellState();
}

class _AnythingAppShellState extends State<AnythingAppShell> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  /// The ONE canonical production composition root (Implementation
  /// Milestone R1), constructed exactly once for the lifetime of this
  /// shell and threaded to every screen that needs a shared instance.
  final AppComposition _composition = AppComposition.production();

  late final List<Widget Function()> _screenBuilders = [
    () => HomeScreen(key: _homeKey, composition: _composition),
    () => ExperiencesScreen(
      composition: _composition,
      onCreateRequested: () {
        setState(() => _currentIndex = 0);
        _homeKey.currentState?.focusIntentField();
      },
    ),
    () => const ActivityScreen(),
    () => PreferencesScreen(themeNotifier: widget.themeNotifier),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _screenBuilders.map((b) => b()).toList(),
          ),
        ),
        bottomNavigationBar: _buildFloatingNav(context),
      ),
    );
  }

  Widget _buildFloatingNav(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final items = [
      _NavItem(icon: Icons.home_filled, label: 'Home', index: 0),
      _NavItem(icon: Icons.auto_awesome, label: 'My Apps', index: 1),
      _NavItem(icon: Icons.notifications_none, label: 'Activity', index: 2),
      _NavItem(icon: Icons.tune, label: 'Settings', index: 3),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceBright.withAlpha(204)
              : colorScheme.surfaceBright.withAlpha(204),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(13)
                : Colors.white.withAlpha(26),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 51 : 13),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final isSelected = _currentIndex == item.index;
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = item.index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 56 : 48,
                height: isSelected ? 56 : 48,
                margin: EdgeInsets.only(top: isSelected ? 0 : 4),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withAlpha(51),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.icon,
                  size: isSelected ? 24 : 22,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
