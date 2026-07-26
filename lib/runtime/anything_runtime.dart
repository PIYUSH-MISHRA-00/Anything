/// AnythingRuntime — the production runtime for executing ExperiencePackages.
///
/// Takes validated ExperiencePackages and creates controlled running sessions.
/// Does NOT execute arbitrary code — interprets trusted declarative structures.
library;

import 'dart:async';

import '../creation/experience_package.dart';
import 'experience_session.dart';
import 'experience_renderer.dart';
import 'behavior_interpreter.dart';
import 'state_engine.dart';
import 'data_runtime.dart';
import 'service_resolver.dart';

/// Runtime status.
enum RuntimeStatus { idle, loading, running, paused, error }

/// The Anything Runtime.
class AnythingRuntime {
  final BehaviorInterpreter _behaviorInterpreter;
  final ExperienceStateEngine _stateEngine;
  final ExperienceDataRuntime _dataRuntime;
  final ExperienceServiceResolver _serviceResolver;

  RuntimeStatus _status = RuntimeStatus.idle;
  ExperienceSession? _currentSession;

  RuntimeStatus get status => _status;
  ExperienceSession? get currentSession => _currentSession;
  ExperienceStateEngine get stateEngine => _stateEngine;

  AnythingRuntime({
    ExperienceRenderer? renderer,
    BehaviorInterpreter? behaviorInterpreter,
    ExperienceStateEngine? stateEngine,
    ExperienceDataRuntime? dataRuntime,
    ExperienceServiceResolver? serviceResolver,
  }) : _behaviorInterpreter = behaviorInterpreter ?? BehaviorInterpreter(),
       _stateEngine = stateEngine ?? ExperienceStateEngine(),
       _dataRuntime = dataRuntime ?? ExperienceDataRuntime(),
       _serviceResolver = serviceResolver ?? ExperienceServiceResolver();

  /// Open an ExperiencePackage and create a running session.
  Future<ExperienceSession> openExperience(ExperiencePackage package) async {
    _status = RuntimeStatus.loading;

    try {
      // Validate package
      final validation = _validatePackage(package);
      if (!validation.isValid) {
        _status = RuntimeStatus.error;
        return ExperienceSession.error(
          experienceId: package.manifest.experienceId,
          error: validation.errors.first,
        );
      }

      // Initialize state
      _stateEngine.initialize(package.state);

      // Initialize data runtime if needed
      if (package.data != null) {
        _dataRuntime.initialize(package.data!);
      }

      // Resolve services
      _serviceResolver.resolve(package.services);

      // Create session
      _currentSession = ExperienceSession(
        id: 'session-${DateTime.now().millisecondsSinceEpoch}',
        experienceId: package.manifest.experienceId,
        package: package,
        status: SessionStatus.running,
        startedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      _status = RuntimeStatus.running;
      return _currentSession!;
    } catch (e) {
      _status = RuntimeStatus.error;
      return ExperienceSession.error(
        experienceId: package.manifest.experienceId,
        error: e.toString(),
      );
    }
  }

  /// Dispatch an event to the behavior interpreter.
  Future<void> dispatchEvent(
    String eventId, {
    Map<String, dynamic>? data,
  }) async {
    if (_currentSession == null) return;

    final context = BehaviorExecutionContext(
      session: _currentSession!,
      stateEngine: _stateEngine,
      dataRuntime: _dataRuntime,
      serviceResolver: _serviceResolver,
    );

    await _behaviorInterpreter.execute(
      _currentSession!.package.behavior,
      eventId,
      context,
    );
  }

  /// Get the current state value.
  dynamic getState(String stateId) {
    return _stateEngine.read(stateId);
  }

  /// Set a state value.
  void setState(String stateId, dynamic value) {
    _stateEngine.write(stateId, value);
  }

  /// Pause the current session.
  void pauseSession() {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(status: SessionStatus.paused);
      _status = RuntimeStatus.paused;
    }
  }

  /// Resume the current session.
  void resumeSession() {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        status: SessionStatus.running,
        lastActiveAt: DateTime.now(),
      );
      _status = RuntimeStatus.running;
    }
  }

  /// Close the current session.
  void closeSession() {
    _currentSession = _currentSession?.copyWith(
      status: SessionStatus.closed,
      lastActiveAt: DateTime.now(),
    );
    _stateEngine.dispose();
    _dataRuntime.dispose();
    _currentSession = null;
    _status = RuntimeStatus.idle;
  }

  /// Validate a package before execution.
  PackageValidation _validatePackage(ExperiencePackage package) {
    final errors = <String>[];

    // Check format version
    if (package.packageVersion > 1) {
      errors.add('Package version ${package.packageVersion} not supported');
    }

    // Check manifest
    if (package.manifest.experienceId.isEmpty) {
      errors.add('Missing experience ID');
    }

    // Check interface
    if (package.interface.screens.isEmpty) {
      errors.add('No screens defined');
    }

    return PackageValidation(isValid: errors.isEmpty, errors: errors);
  }
}

/// Package validation result.
class PackageValidation {
  final bool isValid;
  final List<String> errors;

  const PackageValidation({required this.isValid, this.errors = const []});
}
