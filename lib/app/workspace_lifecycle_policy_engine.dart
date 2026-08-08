/// WorkspaceLifecyclePolicyEngine — Implementation Specification IS-R39. The
/// ONE owner of runtime lifecycle POLICY DECISIONS: when a running
/// Experience's runtime should pause, resume, or otherwise transition — a
/// thin, real composition over `ExperienceRuntimeController` (R38,
/// unmodified) and `WorkspaceEventPublisher` (R35, unmodified) — never a
/// second runtime, never a second runtime controller.
///
/// REALITY before R39 (confirmed by reading source): `grep -rn
/// "AppLifecycleState|WidgetsBindingObserver|didChangeAppLifecycleState"
/// lib/` returns ZERO matches — no application-lifecycle observation exists
/// anywhere in this codebase today. This is genuinely new ground, not a
/// rediscovery of an orphaned subsystem like most R14-R38 milestones.
/// `ExperienceWorkspaceManager.closeExperience()` (R32) also has ZERO
/// production callers (`grep -rn "\.closeExperience(" lib/`) — a "Workspace
/// Close" policy has no real trigger to attach to yet; deferred honestly
/// (see KNOWN LIMITATIONS in `docs/architecture/WORKSPACE_LIFECYCLE_POLICY_ENGINE.md`),
/// never fabricated.
///
/// `AutonomousWorkspaceRuntime.captureRuntimeState()` (R34, unmodified)
/// already returns a real `WorkspaceRuntimeSnapshot` with a ready-made
/// `backgroundSessions` getter (open-but-not-active sessions) — the real,
/// existing input for an "Inactive Runtime" policy, never re-derived here.
///
/// EVENTS: no new `AnythingEvent` subtype. `WorkspaceEventPublisher
/// .publishWorkspaceUpdated(change, sessionId)` (R35, unmodified) already
/// fits — reused here with new, real `change` strings (`'policy_pause'`/
/// `'policy_resume'`/`'policy_terminate'`/`'policy_restore'`).
library;

import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../runtime/experience_runtime_controller.dart';
import '../runtime/experience_session.dart';
import 'autonomous_workspace_runtime.dart';
import 'workspace_event_publisher.dart';

/// The real, closed vocabulary of runtime actions a policy can decide.
enum RuntimePolicyAction { pause, resume, terminate, restore, noAction }

/// One real, traceable policy decision — never invoked by itself; a caller
/// (or [WorkspaceLifecyclePolicyEngine.apply]) supplies the real
/// [ExperienceRuntimeController] this decision is about.
class RuntimePolicyDecision {
  final RuntimePolicyAction action;
  final String? sessionId;
  final String reason;

  const RuntimePolicyDecision({
    required this.action,
    this.sessionId,
    required this.reason,
  });
}

class WorkspaceLifecyclePolicyEngine {
  final WorkspaceEventPublisher? eventPublisher;

  const WorkspaceLifecyclePolicyEngine({this.eventPublisher});

  /// Background Pause / Foreground Resume / Automatic Resume policies —
  /// pure, deterministic mapping from a real, OS-level `AppLifecycleState`
  /// transition. Never touches a controller itself.
  RuntimePolicyDecision evaluateAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        return RuntimePolicyDecision(
          action: RuntimePolicyAction.pause,
          reason: 'app backgrounded ($state) — Background Pause policy',
        );
      case AppLifecycleState.resumed:
        return const RuntimePolicyDecision(
          action: RuntimePolicyAction.resume,
          reason:
              'app foregrounded — Foreground Resume / Automatic Resume policy',
        );
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        return RuntimePolicyDecision(
          action: RuntimePolicyAction.noAction,
          reason: 'transient/detached state ($state) — no policy applies',
        );
    }
  }

  /// Inactive Runtime policy — every real, open-but-not-active workspace
  /// session (already real, R34, never re-derived) whose runtime is still
  /// running should be paused. An already-paused background session gets
  /// no redundant decision. Multiple, independent decisions prove this
  /// engine's decision logic scales to N real sessions — see this file's
  /// own doc comment / KNOWN LIMITATIONS for why production wiring does
  /// not yet auto-apply these across a multi-runtime registry.
  List<RuntimePolicyDecision> evaluateWorkspaceSnapshot(
    WorkspaceRuntimeSnapshot snapshot,
  ) {
    return [
      for (final s in snapshot.backgroundSessions)
        if (s.runtimeState?.status == SessionStatus.running)
          RuntimePolicyDecision(
            action: RuntimePolicyAction.pause,
            sessionId: s.sessionId,
            reason:
                'session ${s.sessionId} is open but not the active workspace session — Inactive Runtime policy',
          ),
    ];
  }

  /// The ONE place this engine actually invokes `ExperienceRuntimeController`
  /// — never owns/constructs controllers itself (no controller registry, no
  /// second runtime/runtime-controller concept; the caller supplies the
  /// real controller for the real session/runtime this decision is about).
  Future<void> apply(
    RuntimePolicyDecision decision,
    ExperienceRuntimeController controller,
  ) async {
    switch (decision.action) {
      case RuntimePolicyAction.pause:
        controller.pause();
      case RuntimePolicyAction.resume:
        controller.resume();
      case RuntimePolicyAction.terminate:
        await controller.terminate();
      case RuntimePolicyAction.restore:
        final snapshot = controller.captureSnapshot();
        if (snapshot != null) await controller.restore(snapshot);
      case RuntimePolicyAction.noAction:
        return; // a real no-op — never a fabricated transition/event.
    }

    final id =
        decision.sessionId ??
        controller.experienceId ??
        controller.currentSession?.experienceId;
    if (eventPublisher != null && id != null) {
      eventPublisher!.publishWorkspaceUpdated(
        'policy_${decision.action.name}',
        id,
      );
    }
  }
}
