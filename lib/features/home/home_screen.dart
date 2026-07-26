/// Home screen — the Universal Intent Surface.
///
/// Stage 9: Production Home with IntentComposer, BirthSequence, and voice.
library;

import 'package:flutter/material.dart';

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_opening_coordinator.dart';
import 'package:anything/design_system/components/birth_sequence.dart';
import 'package:anything/design_system/components/anything_chip.dart';
import 'package:anything/design_system/components/anything_empty_state.dart';
import 'package:anything/design_system/components/anything_section_header.dart';
import 'package:anything/design_system/tokens/spacing.dart';
import 'package:anything/features/home/intent_composer.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/services/provider_registry.dart';
import 'package:anything/services/voice_service.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/intent_repository.dart';
import 'package:anything/core/contracts/intent.dart' as core;
import 'package:anything/core/contracts/protection_provider.dart';
import 'package:anything/runtime/experience_host_screen.dart';

/// Home screen with production creation pipeline.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late final ExperienceCreationCoordinator _coordinator;
  late final ExperienceOpeningCoordinator _openingCoordinator;
  late final SqliteExperienceRepository _repository;
  late final IntentRepository _intentRepository;
  late final IntentComposer _composer;
  late final VoiceInputService _voiceService;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<ExperienceMetadataRecord> _recentExperiences = [];

  /// The Experience ID created by the current creation flow.
  /// Used by birth completion to open the exact Experience.
  String? _createdExperienceId;
  String? _createdExperienceName;

  /// Focus the intent input field for external navigation.
  void focusIntentField() {
    _focusNode.requestFocus();
  }

  bool _isListening = false;
  bool _showBirth = false;
  String _birthName = '';
  final ValueNotifier<bool> _creationReady = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    final providerRegistry = AnythingProviderRegistry();
    final kernel = AnythingKernel(providerRegistry: providerRegistry);
    _coordinator = ExperienceCreationCoordinator(kernel: kernel);
    _openingCoordinator = ExperienceOpeningCoordinator();
    _repository = SqliteExperienceRepository();
    _intentRepository = IntentRepository();
    _composer = IntentComposer(kernel);
    _voiceService = VoiceInputService();
    _voiceService.addListener(_onVoiceStateChanged);
    _loadRecent();
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceStateChanged);
    _voiceService.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _creationReady.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _onVoiceStateChanged() {
    if (mounted) {
      setState(() {
        _isListening = _voiceService.isListening;
        if (_voiceService.currentText.isNotEmpty) {
          _textController.text = _voiceService.currentText;
          _composer.setExpression(_voiceService.currentText);
        }
      });
    }
  }

  Future<void> _loadRecent() async {
    final experiences = await _repository.listAll(limit: 5);
    if (mounted) setState(() => _recentExperiences = experiences);
  }

  void _handleSubmit(String text) {
    if (text.trim().isEmpty) return;
    _createExperience(text.trim());
  }

  Future<void> _createExperience(String expression) async {
    _composer.setExpression(expression);
    final intent = _composer.createIntent();

    await _intentRepository.save(IntentRecord.fromIntent(intent));
    await _intentRepository.updateStatus(
      intent.id,
      core.IntentStatus.submitted,
    );

    setState(() {
      _showBirth = true;
      _birthName = expression;
      _creationReady.value = false;
      _createdExperienceId = null;
      _createdExperienceName = null;
    });

    final result = await _coordinator.createFromIntent(intent);

    if (!mounted) return;

    if (result is CreationCreated) {
      await _intentRepository.updateStatus(
        intent.id,
        core.IntentStatus.accepted,
      );
      // Store the EXACT created Experience ID for birth completion.
      setState(() {
        _createdExperienceId = result.experienceId;
        _createdExperienceName = result.package.manifest.name;
        _creationReady.value = true;
      });
    } else if (result is CreationOpened) {
      await _intentRepository.updateStatus(
        intent.id,
        core.IntentStatus.accepted,
      );
      setState(() => _showBirth = false);
      // Use the trusted opening coordinator for CreationOpened.
      await _openViaCoordinator(result.experienceId, result.experienceName);
    } else if (result is CreationFailed) {
      await _intentRepository.updateStatus(intent.id, core.IntentStatus.failed);
      setState(() => _showBirth = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } else if (result is CreationProviderRequired) {
      await _intentRepository.updateStatus(intent.id, core.IntentStatus.failed);
      setState(() => _showBirth = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
  }

  void _onBirthComplete() {
    setState(() => _showBirth = false);

    // Open the EXACT Experience created by the current creation flow.
    // Do not infer from _recentExperiences.first.
    final createdId = _createdExperienceId;
    final createdName = _createdExperienceName;

    if (createdId != null && mounted) {
      _openViaCoordinator(createdId, createdName ?? _birthName);
    }

    _loadRecent();
  }

  /// Open an Experience through the trusted opening coordinator.
  Future<void> _openViaCoordinator(
    String experienceId,
    String experienceName,
  ) async {
    if (!mounted) return;

    final result = await _openingCoordinator.openExperience(experienceId);

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
            ),
          ),
        ).then((_) => _loadRecent());

      case OpenProtectionInputRequired():
        // Show time input flow, then resume through coordinator.
        await _showProtectionInputAndResume(
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

  /// Show the protection time input flow and resume opening through coordinator.
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
            ),
          ),
        ).then((_) => _loadRecent());
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
            ),
          ),
        ).then((_) => _loadRecent());
      } else if (openResult is OpenFailed && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(openResult.message)));
      }
    }
  }

  /// Open an Experience from the recent list via the trusted coordinator.
  void _openExperience(ExperienceMetadataRecord exp) async {
    await _openViaCoordinator(exp.id, exp.name);
  }

  Future<void> _handleVoiceTap() async {
    if (_isListening) {
      await _voiceService.stopListening();
    } else {
      await _voiceService.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_showBirth) {
      return BirthSequence(
        experienceName: _birthName,
        icon: Icons.auto_awesome,
        creationReady: _creationReady,
        onComplete: _onBirthComplete,
        reducedMotion: MediaQuery.of(context).disableAnimations,
      );
    }

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
                  'Anything',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.01,
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              24,
              AnythingPadding.regular,
              0,
            ),
            child: _buildIntentField(context),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              24,
              AnythingPadding.regular,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try asking for',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.08,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AnythingChip(
                      label: 'Calculator',
                      icon: Icons.calculate,
                      onTap: () => _createExperience('Make me a calculator'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AnythingPadding.regular,
              32,
              AnythingPadding.regular,
              0,
            ),
            child: AnythingSectionHeader(title: 'Recent'),
          ),
        ),

        if (_recentExperiences.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AnythingPadding.regular,
                16,
                AnythingPadding.regular,
                0,
              ),
              child: AnythingEmptyState(
                icon: Icons.auto_awesome,
                title: 'No apps yet',
                message: 'Apps you create will appear here.',
                actionLabel: 'Create your first',
                onAction: () => _focusNode.requestFocus(),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AnythingPadding.regular,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final exp = _recentExperiences[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(exp.name),
                  subtitle: Text(
                    exp.description.isNotEmpty ? exp.description : 'App',
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _openExperience(exp),
                );
              }, childCount: _recentExperiences.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildIntentField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(isDark ? 8 : 24),
        border: Border.all(
          color: _focusNode.hasFocus
              ? colorScheme.primary.withAlpha(128)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              onChanged: (text) => _composer.setExpression(text),
              onSubmitted: _handleSubmit,
              textInputAction: TextInputAction.send,
              maxLines: null,
              minLines: 1,
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'What do you want?',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withAlpha(128),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _textController.text.isNotEmpty
                ? IconButton(
                    key: const ValueKey('submit'),
                    onPressed: _showBirth
                        ? null
                        : () => _handleSubmit(_textController.text),
                    icon: Icon(
                      Icons.arrow_upward,
                      color: colorScheme.onPrimary,
                      size: 22,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: 'Submit',
                  )
                : IconButton(
                    key: const ValueKey('voice'),
                    onPressed: _handleVoiceTap,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    tooltip: 'Voice input',
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
