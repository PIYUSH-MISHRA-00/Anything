/// WorkspaceSchedulingEngine — Implementation Specification IS-R42. The ONE
/// owner of runtime SCHEDULING: which runtime is foreground, which are
/// background, and making the real, registered runtimes in
/// `WorkspaceRuntimeSupervisor` (R40/R41, unmodified) match the workspace's
/// real active/background state — a thin, real coordination layer that
/// never touches `AnythingRuntime` directly and never decides which session
/// is active itself.
///
/// REALITY before R42 (confirmed by reading source): `WorkspaceRuntimeSupervisor
/// .applyInactiveRuntimePolicy()`/`.resume()` (R40) have ZERO callers
/// anywhere in `lib/` (confirmed by grep) — R40's and R41's own doc comments
/// both explicitly, honestly deferred wiring a real trigger for them. This
/// engine is their first real, production-shaped caller — it reimplements
/// NONE of their decision logic.
///
/// "Which session is active" stays `ExperienceWorkspaceManager`'s own,
/// unmodified responsibility (`activeSessionId`/`switchActiveExperience()`,
/// R32) — this engine only reads that real state (via `AutonomousWorkspaceRuntime
/// .captureRuntimeState()`, R34, unmodified) and makes the real, registered
/// runtimes match it through `WorkspaceRuntimeSupervisor`. It never mutates
/// `AnythingRuntime` directly — every real mutation goes through the
/// supervisor, matching this specification's own "Never directly control
/// AnythingRuntime" rule.
///
/// EVENTS: no new `AnythingEvent` subtype. `WorkspaceEventPublisher
/// .publishWorkspaceUpdated(change, sessionId)` (R35, unmodified) already
/// fits — reused here with a new, real `change` string
/// (`'scheduler_active_transition'`).
///
/// "PRELOADED": named in this specification's own architectural-objective
/// prose but NOT listed among its concrete RESPONSIBILITIES, and no real
/// mechanism for a "warm but not fully opened" runtime exists anywhere in
/// `AnythingRuntime`/`ExperienceRuntimeController` (`start()` always fully
/// opens a package). Not implemented — see KNOWN LIMITATIONS in
/// `docs/architecture/WORKSPACE_SCHEDULING_ENGINE.md`, matching R39's own
/// "Future Memory Policies" precedent for spec language that outruns real,
/// buildable capability this milestone.
library;

import 'autonomous_workspace_runtime.dart';
import 'experience_workspace_manager.dart';
import 'workspace_event_publisher.dart';
import 'workspace_lifecycle_policy_engine.dart';
import 'workspace_runtime_supervisor.dart';

class WorkspaceSchedulingEngine {
  final AutonomousWorkspaceRuntime workspaceRuntime;
  final WorkspaceRuntimeSupervisor supervisor;
  final WorkspaceLifecyclePolicyEngine policyEngine;
  final ExperienceWorkspaceManager? workspace;
  final WorkspaceEventPublisher? eventPublisher;

  const WorkspaceSchedulingEngine({
    required this.workspaceRuntime,
    required this.supervisor,
    required this.policyEngine,
    this.workspace,
    this.eventPublisher,
  });

  /// Determine foreground experience — pure read, never mutates anything.
  SessionRuntimeStatus? foregroundExperience() => workspaceRuntime.captureRuntimeState().activeSession;

  /// Determine background experiences — pure read, never mutates anything.
  List<SessionRuntimeStatus> backgroundExperiences() => workspaceRuntime.captureRuntimeState().backgroundSessions;

  /// Coordinate `WorkspaceRuntimeSupervisor` — makes real, registered
  /// runtimes match the workspace's CURRENT real active/background state:
  /// resumes the active session's real runtime (if registered), then pauses
  /// every other real, registered, running background runtime via the
  /// existing, unmodified Inactive Runtime policy. Never decides which
  /// session is active (that stays `ExperienceWorkspaceManager`'s own
  /// responsibility) and never touches `AnythingRuntime` directly.
  Future<void> scheduleActiveTransition() async {
    final snapshot = workspaceRuntime.captureRuntimeState();
    final active = snapshot.activeSession;
    if (active != null) {
      supervisor.resume(active.sessionId);
    }
    await supervisor.applyInactiveRuntimePolicy(snapshot, policyEngine);
    if (eventPublisher != null && active != null) {
      eventPublisher!.publishWorkspaceUpdated('scheduler_active_transition', active.sessionId);
    }
  }

  /// Select next active runtime — makes [sessionId] the workspace's real
  /// active session via the existing, unmodified `ExperienceWorkspaceManager
  /// .switchActiveExperience()` (never reimplemented here), then delegates
  /// to [scheduleActiveTransition] to make runtimes match. Requires
  /// [workspace] to have been supplied.
  Future<void> scheduleForeground(String sessionId) async {
    final ws = workspace;
    if (ws == null) {
      throw StateError('WorkspaceSchedulingEngine.scheduleForeground() requires a workspace — construct with workspace: ... to use it.');
    }
    await ws.switchActiveExperience(sessionId);
    await scheduleActiveTransition();
  }
}
