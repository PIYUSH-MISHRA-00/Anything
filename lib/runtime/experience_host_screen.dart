/// Experience Host Screen — loads and displays a running Experience.
library;

import 'dart:async' show unawaited;
import 'package:flutter/material.dart';

import '../app/experience_modification_coordinator.dart';
import '../capabilities/platform/capability_platform.dart';
import '../creation/experience_package.dart';
import '../storage/activity_repository.dart';
import '../security/protection_service.dart';
import '../world_model/world_model_coordinator.dart';
import 'anything_runtime.dart';
import 'experience_renderer.dart';
import 'experience_router.dart';

/// Hosts a running Experience inside Anything.
class ExperienceHostScreen extends StatefulWidget {
  final ExperiencePackage package;
  final String? experienceName;
  final String? experienceId;
  final ExperienceProtectionService? protectionService;

  /// Optional pre-created runtime for dependency injection.
  /// When provided, the screen will NOT create its own runtime and will use
  /// this one instead. This allows tests to inject a runtime backed by real
  /// SQLite (created outside the testWidgets context where FFI works).
  final AnythingRuntime? runtime;

  /// Shared, canonical World Graph / Capability Platform (Implementation
  /// Milestone R1) — threaded from the composition root
  /// (`AnythingAppShell` -> `AppComposition`) so every Experience shares
  /// the SAME `WorldModelCoordinator`/`CapabilityPlatform` instance rather
  /// than each host screen constructing its own (MIS-1 Part 2's ownership
  /// finding). Both null by default: existing tests/callers that construct
  /// `ExperienceHostScreen` directly are unaffected (`ExperienceModificationCoordinator`
  /// falls back to its own default `WorldModelCoordinator()`, and
  /// `AnythingRuntime` falls back to the stubbed dispatch path, exactly as
  /// before R1).
  final WorldModelCoordinator? worldModel;
  final CapabilityPlatform? capabilityPlatform;

  const ExperienceHostScreen({
    super.key,
    required this.package,
    this.experienceName,
    this.experienceId,
    this.protectionService,
    this.runtime,
    this.worldModel,
    this.capabilityPlatform,
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
  Map<String, dynamic>? _editRecordData;
  String? _editScreenId;
  Map<String, dynamic>? _detailRecordData;
  String? _detailScreenId;

  List<NavigationItem> get _navigationItems =>
      _currentPackage.interface.navigation?.items ?? [];

  @override
  void initState() {
    super.initState();
    _runtime = widget.runtime ?? AnythingRuntime(capabilityPlatform: widget.capabilityPlatform);
    _modificationCoordinator = ExperienceModificationCoordinator(worldModel: widget.worldModel);
    _activity = ActivityRepository();
    _protectionService =
        widget.protectionService ?? ExperienceProtectionService();
    _currentPackage = widget.package;
    _loadExperience();
  }

  Future<void> _loadExperience() async {
    try {
      // Skip opening if the runtime is already running (pre-opened via DI)
      if (_runtime.status != RuntimeStatus.running) {
        await _runtime.openExperience(_currentPackage);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _router = _runtime.router;
        });
        _seedDefaultScreen();
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

  /// Seeds the router with an explicit entry for the default/tab screen.
  ///
  /// The renderer derives the currently-shown screen as
  /// `_router.currentScreenId ?? _getScreenIdForTab(...)` -- the default
  /// screen is shown implicitly, via an EMPTY router history, rather than
  /// being pushed onto it. That leaves the first user-initiated push (e.g.
  /// tapping "Add") at history length 1, and ExperienceRouter._pop()'s
  /// length<=1 "already at root" fallback then keeps that SAME pushed
  /// screen instead of returning to the default one. Explicitly pushing
  /// the default screen once, up front, keeps history length consistent
  /// with the router's pop/popToRoot contract (verified by
  /// ExperienceRouter's own "Pop to root" test, which already assumes the
  /// root screen is an explicit history entry).
  void _seedDefaultScreen() {
    final router = _router;
    if (router == null || router.history.isNotEmpty) return;
    final defaultScreenId = _navigationItems.isNotEmpty
        ? _getScreenIdForTab(0)
        : (_currentPackage.interface.screens.isNotEmpty
              ? _currentPackage.interface.screens.first.id
              : null);
    if (defaultScreenId != null) {
      router.navigate(
        NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: defaultScreenId,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Only close runtime if WE created it (not injected).
    // When runtime is injected via DI, the caller owns its lifecycle.
    if (widget.runtime == null) {
      unawaited(_runtime.closeSession());
    }
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
      await _runtime.closeSession();
      await _runtime.openExperience(_currentPackage);
      if (mounted) {
        setState(() {
          _router = _runtime.router;
        });
        _seedDefaultScreen();
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

  /// Finds the form screen for a create action event.
  ///
  /// When the user taps an "Add" button on a list screen, we should navigate
  /// to the entity's form screen rather than dispatching the action event
  /// (which would try to create with no data).
  String? _findFormScreenForAction(String eventId) {
    // Check if any screen has a form matching the entity from the event
    final screens = _currentPackage.interface.screens;
    for (final screen in screens) {
      // Match form screens: screen ID ends with '_form'
      if (screen.id.endsWith('_form')) {
        final entityId = screen.id.replaceAll('_form', '');
        // Match: action ID contains the entity ID (e.g., 'add_person' → 'person')
        if (eventId.contains(entityId)) {
          return screen.id;
        }
      }
    }
    return null;
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
    // Prefer the router's screen ID (which tracks push/pop navigation).
    // Fall back to tab-based selection when there's no router history.
    final routerScreenId = _router?.currentScreenId;
    final tabScreenId = _navigationItems.isNotEmpty
        ? _getScreenIdForTab(_currentTabIndex)
        : null;
    final screenId =
        routerScreenId ??
        tabScreenId ??
        (screens.isNotEmpty ? screens.first.id : 'main');
    final runtimeContext = _runtime.runtimeContext;

    // If navigating to an edit screen, load the record data for the form
    Map<String, dynamic>? renderData;
    if (screenId.endsWith('_edit') && runtimeContext != null) {
      if (_editScreenId != screenId) {
        _editScreenId = screenId;
        _editRecordData = null;
        final currentEntry = _router?.history.isNotEmpty == true
            ? _router!.history.last
            : null;
        final recordId = currentEntry?.arguments?['recordId'] as String?;
        if (recordId != null) {
          final entityId = screenId.replaceAll('_edit', '');
          runtimeContext.readRecord(entityId, recordId).then((record) {
            if (mounted) {
              setState(() {
                _editRecordData = record;
              });
            }
          });
        }
      }
      renderData = _editRecordData != null
          ? {'_currentRecord': _editRecordData}
          : null;
    } else if (screenId.endsWith('_detail') && runtimeContext != null) {
      // Load record data for detail screens so entity list renders correctly
      if (_detailScreenId != screenId) {
        _detailScreenId = screenId;
        _detailRecordData = null;
        final currentEntry = _router?.history.isNotEmpty == true
            ? _router!.history.last
            : null;
        final recordId = currentEntry?.arguments?['recordId'] as String?;
        if (recordId != null) {
          final entityId = screenId.replaceAll('_detail', '');
          runtimeContext.readRecord(entityId, recordId).then((record) {
            if (mounted) {
              setState(() {
                _detailRecordData = record;
              });
            }
          });
        }
      }
      renderData = _detailRecordData != null
          ? {'_currentRecord': _detailRecordData}
          : null;
    } else {
      _editScreenId = null;
      _editRecordData = null;
      _detailScreenId = null;
      _detailRecordData = null;
    }

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
        onEvent: (eventId, {data}) async {
          // Handle "Add" buttons: navigate to the create form screen
          // instead of dispatching a create event directly.
          final formScreen = _findFormScreenForAction(eventId);
          if (formScreen != null) {
            _router?.navigate(
              NavigationRequest(
                action: NavigationAction.push,
                targetScreenId: formScreen,
              ),
            );
            if (mounted) setState(() {});
            return;
          }

          // Handle submitForm: dispatch then pop back to the list screen
          if (eventId == 'submitForm') {
            await _runtime.dispatchEvent(eventId, data: data);
            if (mounted) {
              // Pop back to the entity list (pop the form screen)
              if (_router?.history.isNotEmpty == true) {
                _router?.navigate(
                  const NavigationRequest(action: NavigationAction.pop),
                );
              }
              setState(() {});
            }
            return;
          }

          // Handle deleteRecord: dispatch then navigate back to the list
          if (eventId == 'deleteRecord') {
            await _runtime.dispatchEvent(eventId, data: data);
            if (mounted) {
              // Navigate back to the parent list after deletion
              if (_router?.history.isNotEmpty == true) {
                _router?.navigate(
                  const NavigationRequest(action: NavigationAction.pop),
                );
              }
              setState(() {});
            }
            return;
          }

          // Handle searchChanged: update search term state
          if (eventId == 'searchChanged') {
            final term = data?['term'] as String? ?? '';
            _runtime.stateEngine.write('searchTerm', term);
            await _runtime.dispatchEvent(eventId, data: data);
            if (mounted) setState(() {});
            return;
          }

          await _runtime.dispatchEvent(eventId, data: data);
          if (mounted) setState(() {});
        },
        runtimeContext: runtimeContext,
        data: renderData,
      ),
      bottomNavigationBar: _navigationItems.isNotEmpty
          ? NavigationBar(
              selectedIndex: _currentTabIndex,
              onDestinationSelected: (index) {
                setState(() => _currentTabIndex = index);
                final targetScreenId = _getScreenIdForTab(index);
                _router?.navigate(
                  NavigationRequest(
                    action: NavigationAction.push,
                    targetScreenId: targetScreenId,
                  ),
                );
                setState(() {});
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
