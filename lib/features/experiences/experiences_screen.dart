/// My Apps / Experience Library screen — real persistent library.
library;

import 'package:flutter/material.dart';

import '../../app/app_composition.dart';
import '../../app/experience_commit.dart';
import '../../app/experience_entry_pipeline.dart';
import '../../app/experience_portability.dart';
import '../../capabilities/adapters/file_service_adapter.dart';
import '../../app/experience_opening_coordinator.dart';
import '../../core/contracts/protection_provider.dart';
import '../../design_system/components/components.dart';
import '../../design_system/experience_icon.dart';
import '../../design_system/tokens/spacing.dart';
import '../../security/protection_service.dart';
import '../../storage/sqlite_experience_repository.dart';
import '../../storage/activity_repository.dart';
import '../preferences/protection_preferences.dart';

/// My Apps screen showing real persisted Experiences.
class ExperiencesScreen extends StatefulWidget {
  final SqliteExperienceRepository? repository;
  final VoidCallback? onCreateRequested;
  final void Function(String experienceId)? onProtectRequested;

  /// Shared composition root (Implementation Milestone R1) — see
  /// `HomeScreen.composition`. Defaults to a fresh
  /// `AppComposition.production()` when not supplied.
  final AppComposition? composition;

  /// The shared Unified Experience Entry Pipeline (Implementation
  /// Specification IS-R45). REALITY before this fix: this screen — the real
  /// "My Apps" tab, wired into `AnythingAppShell` (`lib/app/app_shell.dart`)
  /// — was a real production Experience-entry surface that R45 missed
  /// entirely. All three of its opening paths called
  /// `ExperienceOpeningCoordinator` directly and then raw-`Navigator.push`ed
  /// `ExperienceHostScreen`, bypassing workspace registration, the
  /// scheduler, runtime supervision and `ExperienceActivationManager`
  /// completely — the exact bypass R45 exists to eliminate. (R44's own
  /// `ExperienceActivationManager` doc comment asserting `HomeScreen` is
  /// "the ONE and ONLY real production call site that ever pushes
  /// `ExperienceHostScreen`" was, in fact, never true.) Defaults to the ONE
  /// shared pipeline on [composition]; an explicit override exists for
  /// tests, matching `HomeScreen.entryPipeline`'s own established
  /// convention. See `docs/architecture/UNIFIED_EXPERIENCE_ENTRY_PIPELINE.md`.
  final ExperienceEntryPipeline? entryPipeline;

  /// Experience portability (IS-P02 Phase 9) — the wire to the R60 codec and
  /// the R54 installer, both of which had no production caller before P02.
  /// Optional and defaulted, following this screen's established seam.
  final ExperiencePortability? portability;

  const ExperiencesScreen({
    super.key,
    this.repository,
    this.onCreateRequested,
    this.onProtectRequested,
    this.composition,
    this.entryPipeline,
    this.portability,
  });

  @override
  State<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  late final AppComposition _composition;
  late final SqliteExperienceRepository _repo;

  /// IS-R55: found by the Task 1 audit. This screen was calling
  /// `repository.delete` directly — a UI widget was a repository writer, and
  /// it was not on R54's list of four known commit sites. It now asks the ONE
  /// commit owner to remove the Experience.
  late final ExperienceCommitFramework _commits;
  late final ActivityRepository _activity;

  /// Real, resolved Unified Experience Entry Pipeline (Implementation
  /// Specification IS-R45) — the ONE thing every Experience-opening call
  /// site below now goes through; see [ExperiencesScreen.entryPipeline].
  late final ExperienceEntryPipeline _entryPipeline;
  late final ExperiencePortability _portability;
  late final ExperienceProtectionService _protectionService;
  List<ExperienceMetadataRecord> _experiences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _composition = widget.composition ?? AppComposition.production();
    // IS-P09: always the composition's repository — a second
    // `SqliteExperienceRepository()` shares the file but not the
    // invalidation signal, and My Apps stayed empty after create.
    _repo = widget.repository ?? _composition.experienceRepository;
    _commits = _composition.experienceCommit;
    // IS-R57: this screen already holds the composition; it now takes the
    // ONE activity repository from it instead of building a tenth.
    _activity = _composition.activityRepository;
    _entryPipeline =
        widget.entryPipeline ?? _composition.experienceEntryPipeline;
    _portability =
        widget.portability ??
        ExperiencePortability(
          repository: _repo,
          installer: _composition.experienceInstallation,
          files: RealFileService(),
        );
    // IS-P13: My Apps → Protect must invoke Kaalka, not a no-op optional
    // callback. Same service ownership as ExperienceHostScreen.
    _protectionService = ExperienceProtectionService(
      repository: _repo,
      commitFramework: _commits,
    );
    _composition.experienceLibraryRevision.addListener(_onLibraryChanged);
    _loadExperiences();
  }

  void _onLibraryChanged() {
    if (mounted) _loadExperiences();
  }

  @override
  void dispose() {
    _composition.experienceLibraryRevision.removeListener(_onLibraryChanged);
    super.dispose();
  }

  Future<void> _loadExperiences() async {
    final experiences = await _repo.listAll();
    if (mounted) {
      setState(() {
        _experiences = experiences;
        _isLoading = false;
      });
    }
  }

  void _openExperience(ExperienceMetadataRecord exp) async {
    await _repo.touchLastUsed(exp.id);
    if (!mounted) return;

    // Implementation Specification IS-R45: routed through the ONE unified
    // entry pipeline — real workspace-session registration (if none exists
    // yet) plus real runtime + navigation activation, replacing the direct
    // `ExperienceOpeningCoordinator` + raw-`Navigator.push` pair that
    // registered no session and never reached the scheduler. Awaiting this
    // preserves the old `.then((_) => _loadExperiences())` refresh exactly:
    // `ExperienceActivationManager.activate()` awaits `Navigator.push`,
    // whose Future completes when the Experience route is popped.
    final result = await _entryPipeline.activateExperience(
      Navigator.of(context),
      exp.id,
    );

    if (!mounted) return;

    switch (result) {
      case OpenReady():
        _loadExperiences();

      case OpenProtectionInputRequired():
        _showProtectionInputAndResume(
          result.experienceId,
          result.experienceName,
        );

      case OpenNotFound(:final message):
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      case OpenInvalid(:final message):
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      case OpenFailed(:final message):
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
    }
  }

  Future<void> _showProtectionInputAndResume(
    String experienceId,
    String experienceName,
  ) async {
    if (!mounted) return;

    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Use current time'),
              onTap: () => Navigator.pop(context, 'current'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Choose date & time'),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, null),
            ),
          ],
        ),
      ),
    );

    if (option == null || !mounted) return;

    if (option == 'current') {
      final now = DateTime.now();
      OpenResult? openResult;
      for (final offsetMinutes in const [0, -1]) {
        final t = now.add(Duration(minutes: offsetMinutes));
        final timeSeed = TimeSeed(hours: t.hour, minutes: t.minute, seconds: 0);
        openResult = await _entryPipeline.activateProtectedExperience(
          Navigator.of(context),
          experienceId: experienceId,
          timeSeed: timeSeed,
        );
        if (openResult is OpenReady) break;
      }
      if (openResult is OpenReady && mounted) {
        _loadExperiences();
      } else if (openResult is OpenFailed && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(openResult.message)));
      }
    } else if (option == 'custom') {
      final now = DateTime.now();
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: DateTime(now.year + 5),
      );
      if (selectedDate == null || !mounted) return;

      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (selectedTime == null || !mounted) return;

      final customDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      final timeSeed = TimeSeed(
        hours: customDateTime.hour,
        minutes: customDateTime.minute,
        seconds: customDateTime.second,
      );

      // Implementation Specification IS-R45: same real pipeline routing as
      // the "current time" branch above.
      final openResult = await _entryPipeline.activateProtectedExperience(
        Navigator.of(context),
        experienceId: experienceId,
        timeSeed: timeSeed,
      );
      if (openResult is OpenReady && mounted) {
        _loadExperiences();
      } else if (openResult is OpenFailed && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(openResult.message)));
      }
    }
  }

  /// EXPORT (IS-P02 Phase 9) — the first production caller of
  /// `ExperiencePackageWriter`, which had ZERO `lib/` importers before P02.
  Future<void> _exportExperience(ExperienceMetadataRecord exp) async {
    final result = await _portability.export(exp.id);
    if (!mounted) return;

    // The result already carries a sentence fit to show a person, written
    // once in ExperiencePortability so both entry points agree.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.description),
        duration: const Duration(seconds: 8),
      ),
    );
    if (!result.succeeded) return;

    await _activity.record(
      ActivityEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        type: 'exported',
        experienceId: exp.id,
        experienceName: exp.name,
        message: result.path == null
            ? 'Exported ${exp.name}'
            : 'Exported ${exp.name} → ${result.path}',
        timestamp: DateTime.now(),
      ),
    );
  }

  /// IMPORT (IS-P02 Phase 9) — closes gap G-25, open since IS-R53.
  ///
  /// An imported package is UNTRUSTED INPUT. This method does not validate it:
  /// the canonical reader refuses a bad one and the installer refuses an
  /// incompatible one, and this only reports where the sequence stopped.
  Future<void> _importExperience() async {
    final result = await _portability.import();
    if (!mounted) return;

    if (result.failure == PortabilityFailure.cancelled) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.description)));
    if (!result.succeeded) return;

    await _activity.record(
      ActivityEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        type: 'imported',
        experienceId: result.manifest!.experienceId,
        experienceName: result.manifest!.name,
        message: 'Imported ${result.manifest!.name}',
        timestamp: DateTime.now(),
      ),
    );
    _loadExperiences();
  }

  void _deleteExperience(ExperienceMetadataRecord exp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${exp.name}?'),
        content: const Text('This will remove the app and its data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _activity.record(
        ActivityEvent(
          id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
          type: 'deleted',
          experienceId: exp.id,
          experienceName: exp.name,
          message: 'Deleted ${exp.name}',
          timestamp: DateTime.now(),
        ),
      );
      await _commits.remove(exp.id);
      _loadExperiences();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              16,
              AnythingPadding.regular,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Apps',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.01,
                  ),
                ),
                // IMPORT (IS-P02 Phase 9). In the header rather than the
                // per-Experience sheet, because importing is the one action
                // that must work when you have no Experiences at all.
                IconButton(
                  onPressed: _importExperience,
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Import an app',
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_experiences.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AnythingEmptyState(
              icon: Icons.auto_awesome,
              title: 'No apps yet',
              message:
                  'Ask Anything to build something.\nYour app will be saved here for instant access.',
              actionLabel: 'Create your first',
              onAction: () {
                widget.onCreateRequested?.call();
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(AnythingPadding.regular),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final exp = _experiences[index];
                return _buildExperienceCard(exp, colorScheme);
              }, childCount: _experiences.length),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildExperienceCard(
    ExperienceMetadataRecord exp,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openExperience(exp),
        onLongPress: () => _showActions(exp),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // IS-P11: same canonical ExperienceIcon as Home — category
              // switch produced a different (often blank-feeling) identity.
              ExperienceIcon(
                experienceId: exp.id,
                name: exp.name,
                category: exp.category,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exp.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exp.description.isNotEmpty ? exp.description : 'App',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(ExperienceMetadataRecord exp) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                _openExperience(exp);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield),
              title: const Text('Protect'),
              onTap: () {
                Navigator.pop(context);
                if (widget.onProtectRequested != null) {
                  widget.onProtectRequested!(exp.id);
                } else {
                  _showProtectOptions(exp);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Export'),
              subtitle: const Text('Save as a shareable .anything file'),
              onTap: () {
                Navigator.pop(context);
                _exportExperience(exp);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteExperience(exp);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProtectOptions(ExperienceMetadataRecord exp) async {
    // IS-P26: honor the persisted default protection time. When a fixed
    // default is set, it is offered first and protects with that seed.
    final pref = await const ProtectionPreferences().load();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!pref.useCurrentTime)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('Use default protection time (${pref.label})'),
                onTap: () => _protectWithDefaultTime(exp, pref),
              ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Use current time'),
              onTap: () => _protectWithCurrentTime(exp),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Choose date & time'),
              onTap: () => _protectWithCustomTime(exp),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _protectWithDefaultTime(
    ExperienceMetadataRecord exp,
    ProtectionTimePreference pref,
  ) async {
    Navigator.pop(context);
    final package = await _repo.getPackage(exp.id);
    if (!mounted) return;
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not protect this app')),
      );
      return;
    }
    final now = DateTime.now();
    final result = await _protectionService.protectWithCustomTime(
      package: package,
      experienceId: exp.id,
      customTime: DateTime(
        now.year,
        now.month,
        now.day,
        pref.hour,
        pref.minute,
      ),
    );
    if (!mounted) return;
    await _handleProtectResult(result, exp);
  }

  Future<void> _protectWithCurrentTime(ExperienceMetadataRecord exp) async {
    Navigator.pop(context);
    final package = await _repo.getPackage(exp.id);
    if (!mounted) return;
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not protect this app')),
      );
      return;
    }

    final result = await _protectionService.protectWithCurrentTime(
      package: package,
      experienceId: exp.id,
    );
    if (!mounted) return;
    await _handleProtectResult(result, exp);
  }

  Future<void> _protectWithCustomTime(ExperienceMetadataRecord exp) async {
    Navigator.pop(context);
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime == null || !mounted) return;

    final customDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final package = await _repo.getPackage(exp.id);
    if (!mounted) return;
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not protect this app')),
      );
      return;
    }

    final result = await _protectionService.protectWithCustomTime(
      package: package,
      experienceId: exp.id,
      customTime: customDateTime,
    );
    if (!mounted) return;
    await _handleProtectResult(
      result,
      exp,
      successMessage:
          'App protected with time ${customDateTime.month}/${customDateTime.day}/${customDateTime.year}',
    );
  }

  Future<void> _handleProtectResult(
    ProtectionResult result,
    ExperienceMetadataRecord exp, {
    String successMessage = 'App protected',
  }) async {
    if (result is ProtectionSucceeded) {
      await _activity.record(
        ActivityEvent(
          id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
          type: 'protected',
          experienceId: exp.id,
          experienceName: exp.name,
          message: 'Protected ${exp.name}',
          timestamp: DateTime.now(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
        _loadExperiences();
      }
    } else if (result is ProtectionFailed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not protect this app')),
        );
      }
    }
  }
}
