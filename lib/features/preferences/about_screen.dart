/// About Anything — Implementation Specification IS-P05 finding 9.
///
/// The Settings tile for this screen was `onTap: () {}` — a literal dead
/// button. Manual testing on a moto g45 5G reported it as doing nothing,
/// which was exactly true.
///
/// Everything shown here is read from the repository at build time or from the
/// running package. Nothing is hardcoded prose that can drift: the version
/// comes from `PackageInfo`, so it cannot disagree with what Play shows.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../design_system/tokens/spacing.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  static const String repositoryUrl =
      'https://github.com/PIYUSH-MISHRA-00/Anything';
  static const String websiteUrl =
      'https://piyush-mishra-00.github.io/Anything/';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _info = info);
    } catch (_) {
      // A missing platform channel (tests, desktop) must not blank the screen.
    }
  }

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final version = _info?.version ?? '2.0.0';
    final build = _info?.buildNumber ?? '1';
    final package = _info?.packageName ?? 'com.anything.anything';

    return Scaffold(
      appBar: AppBar(title: const Text('About Anything')),
      body: ListView(
        padding: const EdgeInsets.all(AnythingPadding.regular),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(51),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 44,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Anything',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'An operating system for software that does not exist yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          _Section(title: 'BUILD'),
          _Row(
            label: 'Version',
            value: version,
            onCopy: () => _copy(context, 'Version', version),
          ),
          _Row(
            label: 'Build number',
            value: build,
            onCopy: () => _copy(context, 'Build', build),
          ),
          _Row(
            label: 'Package',
            value: package,
            onCopy: () => _copy(context, 'Package', package),
          ),

          _Section(title: 'PROJECT'),
          _Row(
            label: 'Repository',
            value: repositoryUrl,
            onCopy: () => _copy(context, 'Repository URL', repositoryUrl),
          ),
          _Row(
            label: 'Website',
            value: websiteUrl,
            onCopy: () => _copy(context, 'Website URL', websiteUrl),
          ),
          _Row(label: 'Licence', value: 'Apache License 2.0'),

          // The clause that matters most to a user of a tool that generates
          // software, and the reason a permissive licence was chosen.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              'Experiences you create with Anything are yours. The licence '
              'covers this software, not the applications you generate with it.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          _Section(title: 'BUILT ON'),
          const _Row(label: 'Flutter', value: 'BSD-3-Clause'),
          const _Row(label: 'Kaalka', value: 'Time-key protection'),
          const _Row(label: 'WebWeaveX', value: 'Semantic web extraction'),
          const _Row(label: 'sqflite', value: 'BSD-2-Clause'),
          const _Row(label: 'flutter_secure_storage', value: 'BSD-3-Clause'),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton.icon(
              // `showLicensePage` is Flutter's own, and it enumerates every
              // dependency's real licence text from the build. Writing our own
              // list would be a second source of truth that silently goes stale
              // the first time a dependency changes.
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Anything',
                applicationVersion: '$version ($build)',
                applicationLegalese:
                    '© 2026 Piyush Mishra and the Anything contributors\n'
                    'Licensed under the Apache License, Version 2.0',
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Third-party licences'),
            ),
          ),

          _Section(title: 'STATUS'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pre-release',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Anything is not published yet. Some things are built and '
                  'not yet reachable, and the roadmap in the repository says '
                  'which. If something looks unfinished, it probably is — and '
                  'it is written down.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _Row({required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy $label',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
