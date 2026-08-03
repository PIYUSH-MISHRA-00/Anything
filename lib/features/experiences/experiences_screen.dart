/// My Apps / Experience Library screen — real persistent library.
library;

import 'package:flutter/material.dart';

import '../../app/app_composition.dart';
import '../../app/experience_opening_coordinator.dart';
import '../../core/contracts/protection_provider.dart';
import '../../design_system/components/components.dart';
import '../../design_system/tokens/spacing.dart';
import '../../storage/sqlite_experience_repository.dart';
import '../../storage/activity_repository.dart';
import '../../runtime/experience_host_screen.dart';

/// My Apps screen showing real persisted Experiences.
class ExperiencesScreen extends StatefulWidget {
  final SqliteExperienceRepository? repository;
  final VoidCallback? onCreateRequested;
  final void Function(String experienceId)? onProtectRequested;

  /// Shared composition root (Implementation Milestone R1) — see
  /// `HomeScreen.composition`. Defaults to a fresh
  /// `AppComposition.production()` when not supplied.
  final AppComposition? composition;

  const ExperiencesScreen({
    super.key,
    this.repository,
    this.onCreateRequested,
    this.onProtectRequested,
    this.composition,
  });

  @override
  State<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  late final AppComposition _composition;
  late final SqliteExperienceRepository _repo;
  late final ActivityRepository _activity;
  late final ExperienceOpeningCoordinator _openingCoordinator;
  List<ExperienceMetadataRecord> _experiences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _composition = widget.composition ?? AppComposition.production();
    _repo = widget.repository ?? SqliteExperienceRepository();
    _activity = ActivityRepository();
    _openingCoordinator = ExperienceOpeningCoordinator();
    _loadExperiences();
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

    final result = await _openingCoordinator.openExperience(exp.id);

    if (!mounted) return;

    switch (result) {
      case OpenReady():
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExperienceHostScreen(
              package: result.package,
              experienceName: result.experienceName,
              experienceId: result.experienceId,
              worldModel: _composition.worldModel,
              engineeringMemory: _composition.engineeringMemory,
              capabilityPlatform: _composition.capabilityPlatform,
            ),
          ),
        ).then((_) => _loadExperiences());

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
      final timeSeed = TimeSeed(
        hours: now.hour,
        minutes: now.minute,
        seconds: now.second,
      );
      final openResult = await _openingCoordinator
          .openProtectedExperienceWithSeed(
            experienceId: experienceId,
            timeSeed: timeSeed,
          );
      if (openResult is OpenReady && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExperienceHostScreen(
              package: openResult.package,
              experienceName: openResult.experienceName,
              experienceId: openResult.experienceId,
              worldModel: _composition.worldModel,
              engineeringMemory: _composition.engineeringMemory,
              capabilityPlatform: _composition.capabilityPlatform,
            ),
          ),
        ).then((_) => _loadExperiences());
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

      final openResult = await _openingCoordinator
          .openProtectedExperienceWithSeed(
            experienceId: experienceId,
            timeSeed: timeSeed,
          );
      if (openResult is OpenReady && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExperienceHostScreen(
              package: openResult.package,
              experienceName: openResult.experienceName,
              experienceId: openResult.experienceId,
              worldModel: _composition.worldModel,
              engineeringMemory: _composition.engineeringMemory,
              capabilityPlatform: _composition.capabilityPlatform,
            ),
          ),
        ).then((_) => _loadExperiences());
      } else if (openResult is OpenFailed && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(openResult.message)));
      }
    }
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
      await _repo.delete(exp.id);
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(exp.category),
                  color: colorScheme.primary,
                ),
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
                widget.onProtectRequested?.call(exp.id);
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'tool':
        return Icons.build;
      case 'productivity':
        return Icons.check_circle;
      case 'finance':
        return Icons.account_balance_wallet;
      case 'health':
        return Icons.favorite;
      case 'creative':
        return Icons.palette;
      case 'education':
        return Icons.school;
      case 'utility':
        return Icons.apps;
      default:
        return Icons.auto_awesome;
    }
  }
}
