/// Kaalka Protection settings (IS-P05 findings 7/8; IS-P26 time control).
///
/// Protection in Anything is PER-EXPERIENCE, not an app-wide switch: an
/// Experience is protected from My Apps and resumed by supplying its time
/// seed. This screen explains that model and — new in IS-P26 — exposes a
/// real, persisted DEFAULT protection time that the per-Experience Protect
/// action uses, so a user who always wants the same protection time does not
/// re-pick it each time.
///
/// It is a DEFAULT for NEW protections, never a global clock override: each
/// protected Experience stores its own seed, so changing this can never make
/// an already-protected app unrecoverable (the hazard the earlier screen
/// correctly refused to create).
library;

import 'package:flutter/material.dart';

import '../../design_system/tokens/spacing.dart';
import 'protection_preferences.dart';

class ProtectionScreen extends StatefulWidget {
  /// Invoked when the user chooses to go and protect something. Optional so
  /// the screen is testable and usable outside the shell.
  final VoidCallback? onOpenExperiences;

  /// Injectable for tests; production uses the SharedPreferences-backed store.
  final ProtectionPreferences preferences;

  const ProtectionScreen({
    super.key,
    this.onOpenExperiences,
    this.preferences = const ProtectionPreferences(),
  });

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen> {
  ProtectionTimePreference _pref = const ProtectionTimePreference(
    useCurrentTime: true,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pref = await widget.preferences.load();
    if (mounted) setState(() => _pref = pref);
  }

  Future<void> _edit() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Default protection time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Use current time'),
                subtitle: const Text(
                  'Protect using the clock at the moment you protect an app',
                ),
                trailing: Icon(
                  _pref.useCurrentTime
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _pref.useCurrentTime
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                onTap: () => Navigator.pop(sheetContext, 'current'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Custom time'),
                subtitle: Text(
                  _pref.useCurrentTime
                      ? 'Pick a fixed protection time'
                      : 'Fixed at ${_pref.label}',
                ),
                trailing: Icon(
                  _pref.useCurrentTime
                      ? Icons.radio_button_unchecked
                      : Icons.radio_button_checked,
                  color: _pref.useCurrentTime
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
                onTap: () => Navigator.pop(sheetContext, 'custom'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice == 'current') {
      await widget.preferences.setUseCurrentTime();
    } else {
      final initial = _pref.useCurrentTime
          ? TimeOfDay.now()
          : TimeOfDay(hour: _pref.hour, minute: _pref.minute);
      if (!mounted) return;
      final picked = await showTimePicker(
        context: context,
        initialTime: initial,
      );
      if (picked == null) return;
      await widget.preferences.setCustomTime(picked.hour, picked.minute);
    }
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(showCloseIcon: true, content: Text('Default protection time: ${_pref.label}')),
      );
    }
  }

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

          // IS-P26 — the real, persisted default protection-time control.
          const _Heading('PROTECTION TIME'),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(Icons.schedule, color: colorScheme.primary),
                title: const Text('Default protection time'),
                subtitle: Text(
                  _pref.useCurrentTime
                      ? 'Use current time'
                      : 'Fixed at ${_pref.label}',
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: _edit,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Used as the default when you protect an app. It never changes '
              'apps you have already protected — each keeps its own time.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
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
                'you have to remember and reuse. The default above is offered '
                'first; you can still choose a different time per app.',
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
                Navigator.of(context).pop();
                widget.onOpenExperiences?.call();
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
