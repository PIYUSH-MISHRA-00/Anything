/// Experience Router — manages navigation inside a generated Experience.
///
/// Supports push, pop, replace, modal, bottom sheet, tab switching.
/// Navigation destinations reference trusted view IDs.
/// Unknown destinations are rejected.
library;

import 'dart:async';
import 'package:uuid/uuid.dart';

/// Navigation action types.
enum NavigationAction {
  push,
  pop,
  replace,
  pushReplacement,
  popToRoot,
  showModal,
  dismissModal,
  showBottomSheet,
  dismissBottomSheet,
  switchTab,
}

/// A navigation request.
class NavigationRequest {
  final NavigationAction action;
  final String? targetScreenId;
  final Map<String, dynamic>? arguments;
  final bool? rootNavigator;

  const NavigationRequest({
    required this.action,
    this.targetScreenId,
    this.arguments,
    this.rootNavigator,
  });
}

/// Navigation event for the UI to handle.
class NavigationEvent {
  final NavigationAction action;
  final String? screenId;
  final Map<String, dynamic>? arguments;
  final String routeId;
  final DateTime timestamp;

  const NavigationEvent({
    required this.action,
    this.screenId,
    this.arguments,
    required this.routeId,
    required this.timestamp,
  });
}

/// Navigation history entry.
class NavigationEntry {
  final String screenId;
  final Map<String, dynamic>? arguments;
  final DateTime timestamp;

  const NavigationEntry({
    required this.screenId,
    this.arguments,
    required this.timestamp,
  });
}

/// Experience Router — manages in-experience navigation.
class ExperienceRouter {
  final Set<String> _validScreenIds;
  final List<NavigationEntry> _history = [];
  final StreamController<NavigationEvent> _eventController =
      StreamController<NavigationEvent>.broadcast();

  /// Current tab index for bottom navigation.
  int _currentTabIndex = 0;

  /// Stream of navigation events.
  Stream<NavigationEvent> get events => _eventController.stream;

  /// Current navigation history (copy).
  List<NavigationEntry> get history => List.unmodifiable(_history);

  /// Current tab index.
  int get currentTabIndex => _currentTabIndex;

  /// Current screen ID.
  String? get currentScreenId =>
      _history.isNotEmpty ? _history.last.screenId : null;

  ExperienceRouter({required Set<String> validScreenIds})
    : _validScreenIds = validScreenIds;

  /// Navigate according to the request.
  NavigationEvent navigate(NavigationRequest request) {
    // Validate target screen exists. Actions like pop/popToRoot don't
    // require a target screen; treat a null OR empty targetScreenId as
    // "no target" so callers that pass '' instead of omitting the
    // parameter don't have the request silently rejected.
    final target = request.targetScreenId;
    if (target != null &&
        target.isNotEmpty &&
        !_validScreenIds.contains(target)) {
      return _emitEvent(
        NavigationEvent(
          action: NavigationAction.pop,
          routeId: _generateId(),
          timestamp: DateTime.now(),
        ),
      );
    }

    switch (request.action) {
      case NavigationAction.push:
        return _push(request);
      case NavigationAction.pop:
        return _pop();
      case NavigationAction.replace:
        return _replace(request);
      case NavigationAction.pushReplacement:
        return _pushReplacement(request);
      case NavigationAction.popToRoot:
        return _popToRoot();
      case NavigationAction.showModal:
        return _push(request);
      case NavigationAction.dismissModal:
        return _pop();
      case NavigationAction.showBottomSheet:
        return _push(request);
      case NavigationAction.dismissBottomSheet:
        return _pop();
      case NavigationAction.switchTab:
        return _switchTab(request);
    }
  }

  NavigationEvent _push(NavigationRequest request) {
    final entry = NavigationEntry(
      screenId: request.targetScreenId ?? currentScreenId ?? '',
      arguments: request.arguments,
      timestamp: DateTime.now(),
    );
    _history.add(entry);
    return _emitEvent(
      NavigationEvent(
        action: NavigationAction.push,
        screenId: entry.screenId,
        arguments: entry.arguments,
        routeId: _generateId(),
        timestamp: DateTime.now(),
      ),
    );
  }

  NavigationEvent _pop() {
    if (_history.length <= 1) return _popToRoot();
    _history.removeLast();
    return _emitEvent(
      NavigationEvent(
        action: NavigationAction.pop,
        screenId: currentScreenId,
        routeId: _generateId(),
        timestamp: DateTime.now(),
      ),
    );
  }

  NavigationEvent _replace(NavigationRequest request) {
    if (_history.isNotEmpty) _history.removeLast();
    return _push(request);
  }

  NavigationEvent _pushReplacement(NavigationRequest request) {
    if (_history.isNotEmpty) _history.removeLast();
    return _push(request);
  }

  NavigationEvent _popToRoot() {
    if (_history.isNotEmpty) {
      final root = _history.first;
      _history.clear();
      _history.add(root);
    }
    return _emitEvent(
      NavigationEvent(
        action: NavigationAction.popToRoot,
        screenId: currentScreenId,
        routeId: _generateId(),
        timestamp: DateTime.now(),
      ),
    );
  }

  NavigationEvent _switchTab(NavigationRequest request) {
    if (request.targetScreenId != null) {
      // Find the index of the target screen in valid screens
      final screenList = _validScreenIds.toList();
      final idx = screenList.indexOf(request.targetScreenId!);
      if (idx >= 0) {
        _currentTabIndex = idx;
      }
    }
    return _emitEvent(
      NavigationEvent(
        action: NavigationAction.switchTab,
        screenId: request.targetScreenId,
        arguments: request.arguments,
        routeId: _generateId(),
        timestamp: DateTime.now(),
      ),
    );
  }

  NavigationEvent _emitEvent(NavigationEvent event) {
    _eventController.add(event);
    return event;
  }

  String _generateId() => const Uuid().v4();

  /// Check if a screen ID is valid.
  bool isValidScreen(String screenId) => _validScreenIds.contains(screenId);

  /// Dispose resources.
  void dispose() {
    _eventController.close();
  }
}
