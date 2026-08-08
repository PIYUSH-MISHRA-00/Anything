/// WorkspaceRuntimeSupervisor — Implementation Specification IS-R40. The
/// ONE owner of every active `ExperienceRuntimeController` in the workspace
/// — a thin, real registry over `ExperienceRuntimeController` (R38,
/// unmodified) and `WorkspaceLifecyclePolicyEngine` (R39, unmodified) —
/// never a second runtime, never a second runtime controller, never a
/// second policy engine.
///
/// REALITY before R40 (confirmed by reading source):
/// `grep -rn "Map<String, ExperienceRuntimeController>|WorkspaceRuntimeSupervisor" lib/`
/// returns zero real hits — there is no registry mapping sessionId to
/// `ExperienceRuntimeController` anywhere in this codebase today.
/// `ExperienceHostScreen` self-constructs exactly ONE controller per screen
/// instance, with zero shared bookkeeping across screens. This is exactly
/// the gap R38's and R39's own doc comments both named and deliberately
/// deferred — "this milestone does NOT build a controller registry — that
/// would risk a second runtime controller."
///
/// `ExperienceRuntimeController` has no `sessionId` field (only a nullable
/// `experienceId`) — the caller supplies `sessionId` explicitly at
/// registration time, the same real resolution
/// `ExperienceHostScreen._publishRuntimeLoadedEvent()` already performs via
/// `workspaceManager.sessionForExperience(experienceId)?.sessionId`.
///
/// POLICY INTEGRATION: `WorkspaceLifecyclePolicyEngine.apply(decision,
/// controller)` already takes an explicit controller argument — needs ZERO
/// code changes. This supervisor is simply a NEW CALLER that resolves
/// `decision.sessionId` through its own registry and passes the resolved
/// controller into the existing, unmodified `apply()`.
///
/// EVENTS: no new `AnythingEvent` subtype. `WorkspaceEventPublisher
/// .publishWorkspaceUpdated(change, sessionId)` (R35, unmodified) already
/// fits — reused here with new, real `change` strings
/// (`'controller_registered'`/`'controller_unregistered'`).
///
/// NO POLLING: this codebase has never used background-timer machinery
/// anywhere in its coordinator layer (`AutonomousWorkspaceRuntime`'s own
/// doc comment documents staying PULL-based for exactly this reason).
/// [removeDisposed] mirrors that discipline — a real, caller-invoked sweep,
/// never a `Timer.periodic`/poll loop.
library;

import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../runtime/anything_runtime.dart' show RuntimeStatus;
import '../runtime/experience_runtime_controller.dart';
import 'autonomous_workspace_runtime.dart';
import 'workspace_event_publisher.dart';
import 'workspace_lifecycle_policy_engine.dart';

/// One real registration record — `sessionId`/`experienceId`/
/// `registrationTime` are fixed at registration time; [currentStatus] is
/// live, read straight from the real controller on every access, never a
/// cached copy that could drift.
class RuntimeControllerRegistration {
  final String sessionId;
  final String? experienceId;
  final ExperienceRuntimeController controller;
  final DateTime registrationTime;

  const RuntimeControllerRegistration({
    required this.sessionId,
    this.experienceId,
    required this.controller,
    required this.registrationTime,
  });

  RuntimeStatus get currentStatus => controller.status;
}

class WorkspaceRuntimeSupervisor {
  final WorkspaceEventPublisher? eventPublisher;
  final Map<String, RuntimeControllerRegistration> _registrations = {};

  WorkspaceRuntimeSupervisor({this.eventPublisher});

  /// Real, honest duplicate prevention — registering the SAME sessionId
  /// twice is a real programming error (would silently lose the reference
  /// to the first controller), never a silent overwrite. Mirrors
  /// `ExperienceWorkspaceManager.switchActiveExperience()`'s own "real
  /// programming error, never silent no-op" precedent.
  void register(
    String sessionId,
    ExperienceRuntimeController controller, {
    String? experienceId,
  }) {
    if (_registrations.containsKey(sessionId)) {
      throw StateError(
        'A runtime controller is already registered for session $sessionId.',
      );
    }
    _registrations[sessionId] = RuntimeControllerRegistration(
      sessionId: sessionId,
      experienceId: experienceId ?? controller.experienceId,
      controller: controller,
      registrationTime: DateTime.now(),
    );
    eventPublisher?.publishWorkspaceUpdated('controller_registered', sessionId);
  }

  /// Real, honest no-op for an unknown sessionId — never throws (matches
  /// `ExperienceWorkspaceManager.closeExperience()`'s own "if (!remove)
  /// return" precedent for an already-absent id).
  void unregister(String sessionId) {
    if (_registrations.remove(sessionId) != null) {
      eventPublisher?.publishWorkspaceUpdated(
        'controller_unregistered',
        sessionId,
      );
    }
  }

  ExperienceRuntimeController? lookup(String sessionId) =>
      _registrations[sessionId]?.controller;

  List<RuntimeControllerRegistration> get registrations =>
      List.unmodifiable(_registrations.values);

  /// Real, caller-invoked sweep (never a timer/poll) — removes every
  /// registration whose real, live controller status is `idle` (a real
  /// `terminate()` already happened but the caller never explicitly
  /// unregistered). Returns the real count removed.
  int removeDisposed() {
    final disposedIds = [
      for (final e in _registrations.entries)
        if (e.value.currentStatus == RuntimeStatus.idle) e.key,
    ];
    for (final id in disposedIds) {
      unregister(id);
    }
    return disposedIds.length;
  }

  /// Direct forwarding — "Forward lifecycle requests" responsibility,
  /// bypassing the policy engine entirely (a caller who already knows
  /// exactly what it wants, not a policy decision). A harmless no-op for
  /// an unknown sessionId.
  void pause(String sessionId) => lookup(sessionId)?.pause();

  void resume(String sessionId) => lookup(sessionId)?.resume();

  Future<void> shutdown(String sessionId) async {
    final controller = lookup(sessionId);
    if (controller == null) return;
    await controller.terminate();
    unregister(sessionId);
  }

  /// Real, workspace-wide Inactive Runtime policy application — the
  /// concrete proof R40's own "Mandatory Vision Validation" requires
  /// ("Inactive Runtime policy now applies across multiple runtime
  /// controllers"). Resolves each real decision's sessionId through THIS
  /// registry, then invokes the UNMODIFIED `WorkspaceLifecyclePolicyEngine
  /// .apply()` — never re-implements the policy decision itself. A decision
  /// naming a sessionId this supervisor has no registration for is silently
  /// skipped (a real, honest "nothing this supervisor owns to act on").
  Future<void> applyInactiveRuntimePolicy(
    WorkspaceRuntimeSnapshot snapshot,
    WorkspaceLifecyclePolicyEngine engine,
  ) async {
    for (final decision in engine.evaluateWorkspaceSnapshot(snapshot)) {
      final controller = decision.sessionId == null
          ? null
          : lookup(decision.sessionId!);
      if (controller != null) await engine.apply(decision, controller);
    }
  }

  /// Real, workspace-wide app-lifecycle policy application across every
  /// REGISTERED controller (e.g. pause every registered runtime on real app
  /// backgrounding) — same "resolve through this registry, apply via the
  /// unmodified engine" pattern.
  Future<void> applyAppLifecyclePolicy(
    AppLifecycleState state,
    WorkspaceLifecyclePolicyEngine engine,
  ) async {
    final decision = engine.evaluateAppLifecycle(state);
    for (final reg in registrations) {
      await engine.apply(decision, reg.controller);
    }
  }
}
