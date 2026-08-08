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
    () => HomeScreen(
      key: _homeKey,
      composition: _composition,
      onOpenSettings: () => setState(() => _currentIndex = 3),
    ),
    () => ExperiencesScreen(
      composition: _composition,
      onCreateRequested: () {
        setState(() => _currentIndex = 0);
        _homeKey.currentState?.focusIntentField();
      },
    ),
    () => const ActivityScreen(),
    () => PreferencesScreen(
      themeNotifier: widget.themeNotifier,
      // IS-P05 finding 7: the Protection screen explains that protection is
      // applied per-Experience, and sends the user to where that happens.
      onOpenExperiences: () => setState(() => _currentIndex = 1),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // EDGE-TO-EDGE (IS-P05 finding 2). Android 15 (API 35) enforces
    // edge-to-edge for every app targeting it, so the system bars are drawn
    // OVER the app whether or not the app is ready for it. Making the bars
    // transparent and handling insets ourselves is the only correct response;
    // the alternative is the floating nav pill sitting under the gesture bar,
    // which is exactly what manual testing reported.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        // `false` at the bottom: the nav pill below owns that inset and pads
        // itself. Letting SafeArea consume it too would double-count and leave
        // a dead band above the pill.
        body: SafeArea(
          bottom: false,
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

    // THE FIX for the reported overlap. The padding was a hardcoded
    // `fromLTRB(16, 0, 16, 32)`, which assumes every device reserves exactly
    // 32 logical pixels at the bottom. Nothing does:
    //
    //   gesture navigation  ~24 dp handle
    //   3-button navigation ~48 dp bar
    //   tablets / foldables vary again, and change on fold
    //
    // `viewPadding.bottom` is the value the system actually reserves, so the
    // pill clears the bar on every one of them. The 12 dp is breathing room
    // between the pill and the bar, and the `max` keeps a sensible gap on
    // devices that report no inset at all (most emulators, some tablets).
    final systemInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPadding = systemInset > 0 ? systemInset + 12 : 24.0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
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
