/// Experience Host Screen — loads and displays a running Experience.
library;

import 'package:flutter/material.dart';

import '../app/experience_modification_coordinator.dart';
import '../creation/experience_package.dart';
import '../storage/activity_repository.dart';
import '../security/protection_service.dart';
import 'anything_runtime.dart';
import 'experience_renderer.dart';
import 'experience_router.dart';

/// Hosts a running Experience inside Anything.
class ExperienceHostScreen extends StatefulWidget {
  final ExperiencePackage package;
  final String? experienceName;
  final String? experienceId;
  final ExperienceProtectionService? protectionService;

  const ExperienceHostScreen({
    super.key,
    required this.package,
    this.experienceName,
    this.experienceId,
    this.protectionService,
  });

  @override
  State<ExperienceHostScreen> createState() => _ExperienceHostScreenState();
}

class _ExperienceHostScreenState extends State<ExperienceHostScreen> {
  late final AnythingRuntime _runtime;
  late final ExperienceModificationCoordinator _modificationCoordinator;
  late final ActivityRepository _activity;
  late final ExperienceProtectionService _protectionService;
  late ExperiencePackage _currentPackage;
  bool _isLoading = true;
  bool _hasError = false;
  ExperienceRouter? _router;
  int _currentTabIndex = 0;

  List<NavigationItem> get _navigationItems =>
      _currentPackage.interface.navigation?.items ?? [];

  @override
  void initState() {
    super.initState();
    _runtime = AnythingRuntime();
    _modificationCoordinator = ExperienceModificationCoordinator();
    _activity = ActivityRepository();
    _protectionService =
        widget.protectionService ?? ExperienceProtectionService();
    _currentPackage = widget.package;
    _loadExperience();
  }

  Future<void> _loadExperience() async {
    try {
      await _runtime.openExperience(_currentPackage);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _router = _runtime.router;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _runtime.closeSession();
    super.dispose();
  }

  void _showModificationIntent() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          32,
          32,
          32,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change this app',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe what you want to change',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Add a percentage button',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submitModification(controller.text),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitModification(String expression) async {
    Navigator.pop(context);
    if (expression.trim().isEmpty || widget.experienceId == null) return;

    final result = await _modificationCoordinator.modifyExperience(
      experienceId: widget.experienceId!,
      modificationExpression: expression.trim(),
    );

    if (!mounted) return;

    if (result is ModificationCoordinatorSucceeded) {
      setState(() {
        _currentPackage = result.newPackage;
      });
      _runtime.closeSession();
      await _runtime.openExperience(_currentPackage);
      if (mounted) {
        setState(() {
          _router = _runtime.router;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('App updated to version ${result.newVersion}'),
          ),
        );
      }
    } else if (result is ModificationCoordinatorFailed) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
  }

  void _showProtectOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Use current time'),
              onTap: () => _protectWithCurrentTime(),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Choose date & time'),
              onTap: () => _protectWithCustomTime(),
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

  Future<void> _protectWithCurrentTime() async {
    Navigator.pop(context);
    if (widget.experienceId == null) return;

    final result = await _protectionService.protectWithCurrentTime(
      package: _currentPackage,
      experienceId: widget.experienceId!,
    );

    if (!mounted) return;

    if (result is ProtectionSucceeded) {
      await _activity.record(
        ActivityEvent(
          id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
          type: 'protected',
          experienceId: widget.experienceId!,
          experienceName: widget.experienceName ?? 'App',
          message: 'Protected ${widget.experienceName ?? "app"}',
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App protected')));
      }
    } else if (result is ProtectionFailed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not protect this app')),
        );
      }
    }
  }

  Future<void> _protectWithCustomTime() async {
    Navigator.pop(context);
    if (widget.experienceId == null) return;

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

    final result = await _protectionService.protectWithCustomTime(
      package: _currentPackage,
      experienceId: widget.experienceId!,
      customTime: customDateTime,
    );

    if (!mounted) return;

    if (result is ProtectionSucceeded) {
      await _activity.record(
        ActivityEvent(
          id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
          type: 'protected',
          experienceId: widget.experienceId!,
          experienceName: widget.experienceName ?? 'App',
          message: 'Protected ${widget.experienceName ?? "app"}',
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'App protected with time ${customDateTime.month}/${customDateTime.day}/${customDateTime.year}',
            ),
          ),
        );
      }
    } else if (result is ProtectionFailed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not protect this app')),
        );
      }
    }
  }

  String _getScreenIdForTab(int index) {
    if (index < _navigationItems.length) {
      return _navigationItems[index].screenId;
    }
    final screens = _currentPackage.interface.screens;
    return screens.isNotEmpty ? screens.first.id : 'main';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.experienceName ?? 'Loading...'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                "Couldn't open this app",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Try again or return to Anything.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final renderer = ExperienceRenderer();
    final screens = _currentPackage.interface.screens;
    final screenId = _router?.currentScreenId ??
        (screens.isNotEmpty ? screens.first.id : 'main');
    final runtimeContext = _runtime.runtimeContext;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.experienceName ?? 'Experience'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'change':
                  _showModificationIntent();
                  break;
                case 'protect':
                  _showProtectOptions();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change',
                child: Text('Change this app'),
              ),
              const PopupMenuItem(value: 'protect', child: Text('Protect')),
            ],
          ),
        ],
      ),
      body: renderer.renderScreen(
        context,
        screenId,
        _currentPackage.interface,
        _runtime.stateEngine,
        onEvent: (eventId, {data}) =>
            _runtime.dispatchEvent(eventId, data: data),
        runtimeContext: runtimeContext,
      ),
      bottomNavigationBar: _navigationItems.isNotEmpty
          ? NavigationBar(
              selectedIndex: _currentTabIndex,
              onDestinationSelected: (index) {
                setState(() => _currentTabIndex = index);
                final targetScreenId = _getScreenIdForTab(index);
                _router?.navigate(NavigationRequest(
                  action: NavigationAction.switchTab,
                  targetScreenId: targetScreenId,
                ));
              },
              destinations: _navigationItems
                  .take(5)
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(_iconFromString(item.icon)),
                      label: item.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }

  IconData _iconFromString(String iconName) {
    switch (iconName) {
      case 'list':
        return Icons.list;
      case 'dashboard':
        return Icons.dashboard;
      case 'add':
        return Icons.add;
      case 'settings':
        return Icons.settings;
      case 'search':
        return Icons.search;
      case 'chart':
        return Icons.bar_chart;
      default:
        return Icons.tab;
    }
  }
}
