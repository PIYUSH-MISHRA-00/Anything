/// AnythingRuntime — the production runtime for executing ExperiencePackages.
///
/// Takes validated ExperiencePackages and creates controlled running sessions.
/// Does NOT execute arbitrary code — interprets trusted declarative structures.
library;

import 'dart:async';

import '../capabilities/platform/capability_platform.dart';
import '../creation/experience_package.dart';
import 'experience_session.dart';
import 'experience_renderer.dart';
import 'experience_router.dart';
import 'behavior_interpreter.dart';
import 'state_engine.dart';
import 'data_runtime.dart';
import 'service_resolver.dart';
import 'runtime_context.dart';
import 'query_controller.dart';

/// Runtime status.
enum RuntimeStatus { idle, loading, running, paused, error }

/// The Anything Runtime.
class AnythingRuntime {
  final BehaviorInterpreter _behaviorInterpreter;
  final ExperienceStateEngine _stateEngine;
  final ExperienceDataRuntime _dataRuntime;
  final ExperienceServiceResolver _serviceResolver;
  final ExperienceRenderer _renderer;

  RuntimeStatus _status = RuntimeStatus.idle;
  ExperienceSession? _currentSession;
  ExperienceRouter? _router;
  RuntimeComponentContext? _runtimeContext;
  final Map<String, ExperienceQueryController> _queryControllers = {};

  RuntimeStatus get status => _status;
  ExperienceSession? get currentSession => _currentSession;
  ExperienceStateEngine get stateEngine => _stateEngine;
  ExperienceDataRuntime get dataRuntime => _dataRuntime;
  ExperienceRenderer get renderer => _renderer;
  ExperienceRouter? get router => _router;
  RuntimeComponentContext? get runtimeContext => _runtimeContext;

  /// [capabilityPlatform] (Implementation Milestone R1) is ignored when
  /// [serviceResolver] is explicitly supplied (the caller's resolver wins,
  /// matching every other optional-dependency in this class); otherwise it
  /// is threaded into a freshly-constructed `ExperienceServiceResolver`.
  AnythingRuntime({
    ExperienceRenderer? renderer,
    BehaviorInterpreter? behaviorInterpreter,
    ExperienceStateEngine? stateEngine,
    ExperienceDataRuntime? dataRuntime,
    ExperienceServiceResolver? serviceResolver,
    CapabilityPlatform? capabilityPlatform,
  }) : _behaviorInterpreter = behaviorInterpreter ?? BehaviorInterpreter(),
       _stateEngine = stateEngine ?? ExperienceStateEngine(),
       _dataRuntime = dataRuntime ?? ExperienceDataRuntime(),
       _serviceResolver =
           serviceResolver ??
           ExperienceServiceResolver(capabilityPlatform: capabilityPlatform),
       _renderer = renderer ?? ExperienceRenderer();

  /// Open an ExperiencePackage and create a running session.
  Future<ExperienceSession> openExperience(ExperiencePackage package) async {
    _status = RuntimeStatus.loading;

    try {
      final validation = _validatePackage(package);
      if (!validation.isValid) {
        _status = RuntimeStatus.error;
        return ExperienceSession.error(
          experienceId: package.manifest.experienceId,
          error: validation.errors.first,
        );
      }

      _stateEngine.initialize(package.state);

      if (package.data != null) {
        _dataRuntime.initialize(
          package.data!,
          experienceId: package.manifest.experienceId,
        );
      }

      _serviceResolver.resolve(
        package.services,
        experienceId: package.manifest.experienceId,
        declaredCapabilities: package.capabilityDeclarations
            .map((c) => c.capabilityId)
            .toList(),
      );

      // Build router from interface screens
      final validScreenIds = package.interface.screens.map((s) => s.id).toSet();
      _router?.dispose();
      _router = ExperienceRouter(validScreenIds: validScreenIds);

      // Create runtime context
      _runtimeContext = RuntimeComponentContext(
        stateEngine: _stateEngine,
        dataRuntime: _dataRuntime,
        router: _router!,
        experienceId: package.manifest.experienceId,
        onEvent: dispatchEvent,
        dataSchema: package.data,
      );

      _currentSession = ExperienceSession(
        id: 'session-${DateTime.now().millisecondsSinceEpoch}',
        experienceId: package.manifest.experienceId,
        package: package,
        status: SessionStatus.running,
        startedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Initialize query controllers for entities
      if (package.data != null) {
        for (final entity in package.data!.entities) {
          _queryControllers[entity.id] = ExperienceQueryController(
            entityId: entity.id,
            dataRuntime: _dataRuntime,
          );
        }
      }

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

  /// Get query controller for an entity.
  ExperienceQueryController? getQueryController(String entityId) {
    return _queryControllers[entityId];
  }

  /// Refresh all query controllers.
  Future<void> refreshAll() async {
    for (final controller in _queryControllers.values) {
      await controller.refresh();
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
      context: context,
      data: data,
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
  Future<void> closeSession() async {
    _currentSession = _currentSession?.copyWith(
      status: SessionStatus.closed,
      lastActiveAt: DateTime.now(),
    );
    for (final controller in _queryControllers.values) {
      controller.dispose();
    }
    _queryControllers.clear();
    _router?.dispose();
    _router = null;
    _runtimeContext = null;
    _stateEngine.dispose();
    await _dataRuntime.dispose();
    _currentSession = null;
    _status = RuntimeStatus.idle;
  }

  /// Validate a package before execution.
  PackageValidation _validatePackage(ExperiencePackage package) {
    final errors = <String>[];

    if (package.packageVersion > 1) {
      errors.add('Package version ${package.packageVersion} not supported');
    }

    if (package.manifest.experienceId.isEmpty) {
      errors.add('Missing experience ID');
    }

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
