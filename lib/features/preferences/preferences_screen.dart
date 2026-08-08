/// Preferences / Settings screen.
///
/// Real local behavior for theme switching.
/// Other sections are visual shells for future implementation.
library;

import 'package:flutter/material.dart';

import '../../design_system/components/components.dart';
import '../../design_system/theme/theme_provider.dart';
import '../../design_system/tokens/spacing.dart';
import 'provider_preferences_screen.dart';
import 'about_screen.dart';
import 'developer_screen.dart';
import 'protection_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Preferences screen.
class PreferencesScreen extends StatelessWidget {
  final AnythingThemeNotifier themeNotifier;

  /// Lets the Protection screen send the user to My Apps, which is where
  /// protection is actually applied (IS-P05 finding 7). Optional, so this
  /// screen stays usable and testable outside the shell.
  final VoidCallback? onOpenExperiences;

  const PreferencesScreen({
    super.key,
    required this.themeNotifier,
    this.onOpenExperiences,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              16,
              AnythingPadding.regular,
              0,
            ),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                letterSpacing: -0.01,
              ),
            ),
          ),
        ),

        // Appearance section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              24,
              AnythingPadding.regular,
              0,
            ),
            child: AnythingSectionHeader(title: 'Appearance'),
          ),
        ),

        // Theme selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AnythingPadding.regular,
            ),
            child: _ThemeSelector(themeNotifier: themeNotifier),
          ),
        ),

        // AI Providers section (shell)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              24,
              AnythingPadding.regular,
              0,
            ),
            child: AnythingSectionHeader(title: 'AI Providers'),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AnythingPadding.regular,
            ),
            child: AnythingListTile(
              leading: Icons.psychology,
              title: 'AI Providers',
              subtitle: 'Configure your AI provider',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProviderPreferencesScreen(),
                  ),
                );
              },
            ),
          ),
        ),

        // Security section (shell)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              24,
              AnythingPadding.regular,
              0,
            ),
            child: AnythingSectionHeader(title: 'Security'),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AnythingPadding.regular,
            ),
            child: AnythingListTile(
              leading: Icons.shield,
              title: 'Kaalka Protection',
              subtitle: 'Time-based encryption',
              // IS-P05 finding 7: was `onTap: () {}`.
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProtectionScreen(onOpenExperiences: onOpenExperiences),
                ),
              ),
            ),
          ),
        ),

        // About section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              24,
              AnythingPadding.regular,
              0,
            ),
            child: AnythingSectionHeader(title: 'About'),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AnythingPadding.regular,
            ),
            child: Column(
              children: [
                AnythingListTile(
                  leading: Icons.info_outline,
                  title: 'About Anything',
                  // No hardcoded version here any more: AboutScreen reads it
                  // from the running package, so the two cannot disagree.
                  subtitle: 'Version, licence and project links',
                  // IS-P05 finding 9: was `onTap: () {}`.
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                // IS-P05 finding 12 — the walkthrough is replayable. A
                // walkthrough you can only see once is one you have to get
                // right on the first read.
                AnythingListTile(
                  leading: Icons.school_outlined,
                  title: 'Replay walkthrough',
                  subtitle: 'See the introduction again',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OnboardingScreen(
                        onFinished: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                AnythingListTile(
                  leading: Icons.code,
                  title: 'Developer Mode',
                  subtitle: 'Technical diagnostics',
                  // IS-P05 finding 10: was `onTap: () {}`.
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeveloperScreen()),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

/// Theme selector widget.
class _ThemeSelector extends StatelessWidget {
  final AnythingThemeNotifier themeNotifier;

  const _ThemeSelector({required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            _ThemeOption(
              title: 'System',
              icon: Icons.brightness_auto,
              isSelected: themeNotifier.mode == AnythingThemeMode.system,
              onTap: () => themeNotifier.setMode(AnythingThemeMode.system),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withAlpha(51),
              indent: 56,
            ),
            _ThemeOption(
              title: 'Light',
              icon: Icons.light_mode,
              isSelected: themeNotifier.mode == AnythingThemeMode.light,
              onTap: () => themeNotifier.setMode(AnythingThemeMode.light),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withAlpha(51),
              indent: 56,
            ),
            _ThemeOption(
              title: 'Dark',
              icon: Icons.dark_mode,
              isSelected: themeNotifier.mode == AnythingThemeMode.dark,
              onTap: () => themeNotifier.setMode(AnythingThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20),
      title: Text(title),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}
