/// Developer Mode — Implementation Specification IS-P05 finding 10.
///
/// The Settings tile was `onTap: () {}`. Manual testing reported an inert
/// toggle, which was accurate: nothing was behind it.
///
/// Everything here is READ from the running app. Nothing is a mock, and
/// nothing is a toggle that changes a value no code reads — an empty toggle is
/// worse than no screen, because it implies a capability that does not exist.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_composition.dart';
import '../../app/crash_log.dart';
import '../../creation/experience_package_codec.dart';
import '../../diagnostics/log_entry.dart';
import '../../design_system/tokens/spacing.dart';

class DeveloperScreen extends StatefulWidget {
  final AppComposition? composition;

  const DeveloperScreen({super.key, this.composition});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  late final AppComposition _composition;
  static const CrashLog _crashLog = CrashLog();

  List<String> _crashes = const [];
  List<LogEntry> _aiLog = const [];
  int _experienceCount = 0;
  int _activityCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _composition = widget.composition ?? AppComposition.production();
    _load();
  }

  Future<void> _load() async {
    // So "active provider" reports the resolved answer rather than whatever
    // was known before storage had been read.
    await _composition.providerRegistry.initialize();
    final crashes = await _crashLog.read();
    var experiences = 0;
    var activity = 0;
    try {
      experiences = (await _composition.experienceRepository.listAll()).length;
    } catch (_) {
      // Diagnostics must never be the thing that crashes.
    }
    try {
      activity = (await _composition.activityRepository.list(
        limit: 500,
      )).length;
    } catch (_) {
      // Same.
    }
    if (!mounted) return;
    setState(() {
      _crashes = crashes;
      _aiLog =
          [
            ..._composition.logger.recentOfCategory(LogCategory.aiProvider),
            ..._composition.logger.recentOfCategory(LogCategory.creation),
          ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _experienceCount = experiences;
      _activityCount = activity;
      _loading = false;
    });
  }

  void _copyAll() {
    final report = StringBuffer()
      ..writeln('Anything diagnostics')
      ..writeln(
        'build mode : ${kDebugMode
            ? "debug"
            : kProfileMode
            ? "profile"
            : "release"}',
      )
      ..writeln(
        'platform   : ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      )
      ..writeln('dart       : ${Platform.version}')
      ..writeln('experiences: $_experienceCount')
      ..writeln('activity   : $_activityCount')
      ..writeln('crashes    : ${_crashes.length}')
      ..writeln(
        'package fmt: ${ExperiencePackageFormat.magic} v${ExperiencePackageFormat.version}',
      );
    Clipboard.setData(ClipboardData(text: report.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostics copied')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Mode'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _copyAll,
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy diagnostics',
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh diagnostics',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AnythingPadding.regular),
              children: [
                _Section('ENVIRONMENT'),
                _Kv(
                  'Build mode',
                  kDebugMode
                      ? 'debug'
                      : kProfileMode
                      ? 'profile'
                      : 'release',
                ),
                _Kv('Platform', Platform.operatingSystem),
                _Kv('OS version', Platform.operatingSystemVersion),
                _Kv('Dart', Platform.version.split(' ').first),
                _Kv('Locale', Platform.localeName),

                _Section('RUNTIME'),
                _Kv('Stored Experiences', '$_experienceCount'),
                _Kv('Activity entries', '$_activityCount'),
                _Kv(
                  'Package format',
                  '${ExperiencePackageFormat.magic} v${ExperiencePackageFormat.version}',
                ),
                _Kv('Package extension', ExperiencePackageFormat.extension),

                _Section('AI PROVIDERS'),
                ..._composition.providerRegistry.providers.map(
                  (p) => _Kv(p.providerName, p.providerId),
                ),
                if (_composition.providerRegistry.providers.isEmpty)
                  const _Kv('Registered', 'none'),
                _Kv(
                  'Active',
                  _composition.providerRegistry.activeProvider?.providerName ??
                      'none configured',
                ),

                _Section('CAPABILITIES'),
                ..._composition.capabilityPlatform.all.map(
                  (c) => _Kv(c.id, 'dispatchable + plannable'),
                ),
                // IS-P07: the Kernel refuses an Experience whose capabilities
                // it cannot resolve, so "what the Kernel can plan" is the
                // number that matters when a creation is rejected.
                _Kv(
                  'Kernel can plan',
                  _composition.capabilityRegistry.all
                      .map((d) => d.id)
                      .join(', '),
                ),

                // IS-P07: the AI boundary now reports what it did. Shown here
                // so a failing generation can be diagnosed on the device,
                // without a cable and without `adb logcat`.
                _Section('AI & CREATION ACTIVITY'),
                if (_aiLog.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nothing yet. Provider selection, verification, model '
                      'choice and every model call appear here.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ..._aiLog.reversed.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        e.toString(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: e.severity == LogSeverity.error
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                _Section('CRASH LOG'),
                if (_crashes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No crashes recorded. The last ${CrashLog.maxEntries} '
                      'are kept on this device and are never uploaded.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_crashes.length} recorded — kept on this device, '
                            'never uploaded.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _crashLog.clear();
                            await _load();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  ..._crashes.reversed.map(
                    (c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 120),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
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

class _Kv extends StatelessWidget {
  final String k;
  final String v;
  const _Kv(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
