/// Kaalka Protection — Implementation Specification IS-P05 findings 7 and 8.
///
/// The Settings tile was `onTap: () {}`. Manual testing reported it as doing
/// nothing, which was true.
///
/// WHAT THIS SCREEN IS. Protection in Anything is PER-EXPERIENCE, not an app
/// setting: an Experience is protected from My Apps, and resumed by supplying
/// its time seed. There is no global "turn protection on" switch to expose,
/// because none exists in the architecture and inventing one here would be a
/// second owner of a decision `ExperienceProtectionService` already owns.
///
/// So this screen explains the model, sends the user to where protection is
/// actually applied, and states plainly what is not built. That is the honest
/// alternative to a dead button — and to a fake switch, which would be worse.
///
/// FINDING 8 — MANUAL TIME CONFIGURATION. Answered rather than implemented,
/// with the reason, below. `TimeSeed` is supplied per protect/resume operation
/// and there is no app-wide clock setting to configure; a global time control
/// would change the seed for Experiences already protected under a different
/// one, and make them unrecoverable.
library;

import 'package:flutter/material.dart';

import '../../design_system/tokens/spacing.dart';

class ProtectionScreen extends StatelessWidget {
  /// Invoked when the user chooses to go and protect something. Optional so
  /// the screen is testable and usable outside the shell.
  final VoidCallback? onOpenExperiences;

  const ProtectionScreen({super.key, this.onOpenExperiences});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kaalka Protection')),
      body: ListView(
        padding: const EdgeInsets.all(AnythingPadding.regular),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(38),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.shield_outlined,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time-keyed encryption',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Protection happens on your device and nowhere else. '
                        'No key leaves the phone, and there is no server '
                        'holding anything.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const _Heading('HOW IT WORKS'),
          const _Step(
            n: '1',
            title: 'Protect an app',
            body:
                'Open My Apps, press and hold an app, and choose Protect. '
                'Protection is applied to that app, not to Anything as a whole.',
          ),
          const _Step(
            n: '2',
            title: 'A time seed is used',
            body:
                'Encryption is derived from a time seed rather than a password '
                'you have to remember and reuse.',
          ),
          const _Step(
            n: '3',
            title: 'Resume with the same seed',
            body:
                'Reopening a protected app asks for its seed. The recovered '
                'app is written back in a single transaction, so a failure '
                'part-way cannot leave it half-restored.',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: FilledButton.icon(
              onPressed: () {
                if (onOpenExperiences != null) {
                  Navigator.of(context).pop();
                  onOpenExperiences!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.apps),
              label: const Text('Go to My Apps'),
            ),
          ),

          const _Heading('WHY THERE IS NO GLOBAL SWITCH'),
          _Note(
            colorScheme: colorScheme,
            text:
                'Protection belongs to an individual app, so a single '
                'device-wide toggle would be misleading: it could not describe '
                'what is protected and what is not. Each app carries its own '
                'state, and My Apps is where you can see it.',
          ),

          const _Heading('MANUAL TIME CONFIGURATION'),
          _Note(
            colorScheme: colorScheme,
            text:
                'A time seed is chosen when an app is protected, and the same '
                'seed is required to reopen it. There is deliberately no '
                'app-wide time setting: changing it centrally would alter the '
                'seed for apps already protected under a different one, and '
                'they could not be recovered.',
          ),

          const _Heading('NOT BUILT YET'),
          _Note(
            colorScheme: colorScheme,
            text:
                'Key rotation — re-protecting an app under a new seed — does '
                'not exist. Neither does signature verification for shared '
                'apps, and exported .anything files are not encrypted. These '
                'are written down in the repository rather than implied here.',
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  final String n;
  final String title;
  final String body;
  const _Step({required this.n, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final ColorScheme colorScheme;
  final String text;
  const _Note({required this.colorScheme, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
