/// Experience State Engine — manages typed state for running Experiences.
library;

import 'dart:async';

import '../creation/experience_package.dart';

/// State engine for Experience sessions.
class ExperienceStateEngine {
  final Map<String, dynamic> _state = {};
  final Map<String, String> _types = {};
  final Map<String, String> _persistence = {};
  final _controllers = <String, StreamController<dynamic>>{};

  /// Initialize state from a StateSchema.
  void initialize(StateSchema schema) {
    _state.clear();
    _types.clear();
    _persistence.clear();

    for (final variable in schema.variables) {
      _types[variable.id] = variable.type;
      _persistence[variable.id] = variable.persistence;
      _state[variable.id] = variable.defaultValue;
    }
  }

  /// Read a state value.
  dynamic read(String stateId) {
    return _state[stateId];
  }

  /// Write a state value with type validation.
  void write(String stateId, dynamic value) {
    final expectedType = _types[stateId];
    if (expectedType == null) return; // Unknown state variable

    // Validate type
    if (!_isValidType(value, expectedType)) {
      return; // Invalid type — reject silently
    }

    _state[stateId] = value;

    // Notify listeners
    _controllers[stateId]?.add(value);
  }

  /// Subscribe to state changes.
  Stream<dynamic> watch(String stateId) {
    _controllers[stateId] ??= StreamController<dynamic>.broadcast();
    return _controllers[stateId]!.stream;
  }

  /// Get all state as a map.
  Map<String, dynamic> toMap() => Map.from(_state);

  /// Check if a state variable is persistent.
  bool isPersistent(String stateId) {
    return _persistence[stateId] == 'persistent';
  }

  /// Get all persistent state variables.
  Map<String, dynamic> getPersistentState() {
    final persistent = <String, dynamic>{};
    for (final entry in _state.entries) {
      if (isPersistent(entry.key)) {
        persistent[entry.key] = entry.value;
      }
    }
    return persistent;
  }

  /// Dispose controllers.
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  bool _isValidType(dynamic value, String expectedType) {
    switch (expectedType) {
      case 'string':
        return value is String;
      case 'integer':
        return value is int;
      case 'decimal':
        return value is double || value is int;
      case 'boolean':
        return value is bool;
      case 'list':
        return value is List;
      case 'map':
        return value is Map;
      default:
        return true;
    }
  }
}
