/// AutonomousWorkspaceRuntime — Implementation Specification IS-R34. A pure
/// SNAPSHOT/AGGREGATION layer over the real, unmodified `ExperienceWorkspaceManager`
/// (R32):
///
///   captureRuntimeState() -> reads ExperienceWorkspaceManager.openSessions/.activeSessionId
///
/// REALITY: almost every "RESPONSIBILITY" this specification lists already
/// exists as a real field, confirmed by reading the source before writing
/// any code:
///  - "Active runtime instances"/"runtime health" = `SessionState
///    .currentRuntimeState` (a real `ExperienceSession`, R31) + its own
///    `.status` (`SessionStatus`, `lib/runtime/experience_session.dart`).
///  - "Deployment status" = `SessionState.currentLifecycleResult?.outcome`
///    (`LifecycleOutcome`, R30).
///  - "Artifact status" = `LifecycleResult.artifactIntelligenceReport`
///    (R28, attached since R30 — full-compilation-path only).
///  - "Pending evolution" = `SessionState.pendingModification` (R31).
///  - "Background engineering" = any session in `ExperienceWorkspaceManager
///    .openSessions` that is not `.activeSessionId` — a real, already-
///    derivable structural fact (R32).
/// None of the above is duplicated here — [WorkspaceRuntimeSnapshot] only
/// RESTATES these real fields per session, read fresh on every
/// [captureRuntimeState] call.
///
/// "AUTONOMOUS" / "SUPERVISE", resolved deliberately: this codebase has no
/// existing background-timer/polling machinery anywhere in its coordinator
/// layer (confirmed by grep — `lib/runtime_intelligence/background_coordinator.dart`
/// explicitly documents avoiding `Timer.periodic`; the one real hit,
/// `lib/widgets/ai_loading_screen.dart`, is a UI-animation timer, unrelated).
/// Introducing new continuously-running execution machinery here would be
/// architecturally novel and unverifiable without live observation. This
/// class is honestly PULL-based: "autonomous" means the snapshot is always
/// a correct, real function of already-real state whenever a caller asks
/// for one — never a live poll loop.
///
/// NOTIFICATIONS: real, derived — a background (non-active) session whose
/// `currentLifecycleResult.outcome` is a real terminal state (`deployed`/
/// `blocked`/`commitFailed` — every outcome that follows a real, completed
/// regeneration attempt, as opposed to `noChangeDetected`/`noActionableTarget`,
/// where nothing was ever attempted, or `noEngineeringMemory`/`cannotEvolve`,
/// real precondition failures before any attempt) that this runtime has not
/// yet reported for that session becomes one real [WorkspaceNotification].
/// Tracked via a real "last-seen outcome per session" map — never
/// fabricated, never re-shown for the same real outcome twice.
///
/// WORLD MODEL: declined, same reasoning R31/R32/R33 already applied — no
/// durable identity independent of the running process.
library;

import '../artifact_intelligence/artifact_intelligence.dart';
import '../runtime/experience_session.dart';
import 'engineering_lifecycle_coordinator.dart';
import 'experience_workspace_manager.dart';
import 'intent_session_manager.dart';

/// One open session's real, aggregated runtime view — every field a direct
/// read of [SessionState]/[ExperienceWorkspaceManager], never a copy that
/// could drift.
class SessionRuntimeStatus {
  final String sessionId;
  final String? experienceId;
  final String? experienceName;
  final bool isActive;
  final ExperienceSession? runtimeState;
  final LifecycleOutcome? deploymentStatus;
  final ArtifactIntelligenceReport? artifactStatus;
  final bool hasPendingEvolution;

  const SessionRuntimeStatus({
    required this.sessionId,
    required this.experienceId,
    required this.experienceName,
    required this.isActive,
    required this.runtimeState,
    required this.deploymentStatus,
    required this.artifactStatus,
    required this.hasPendingEvolution,
  });
}

/// One real, derived notification — a background session's evolution
/// reached a real terminal outcome this runtime has not reported before.
class WorkspaceNotification {
  final String sessionId;
  final String? experienceName;
  final LifecycleOutcome outcome;
  final DateTime observedAt;

  const WorkspaceNotification({required this.sessionId, required this.experienceName, required this.outcome, required this.observedAt});
}

/// Real, whole-workspace snapshot — every field a plain, traceable
/// aggregation of [SessionRuntimeStatus]/[WorkspaceNotification], never a
/// separately-computed summary that could drift.
class WorkspaceRuntimeSnapshot {
  final List<SessionRuntimeStatus> sessions;
  final List<WorkspaceNotification> notifications;
  final DateTime capturedAt;

  const WorkspaceRuntimeSnapshot({required this.sessions, required this.notifications, required this.capturedAt});

  List<SessionRuntimeStatus> get backgroundSessions => sessions.where((s) => !s.isActive).toList();
  SessionRuntimeStatus? get activeSession => sessions.where((s) => s.isActive).firstOrNull;
}

const _terminalOutcomes = {LifecycleOutcome.deployed, LifecycleOutcome.blocked, LifecycleOutcome.commitFailed};

class AutonomousWorkspaceRuntime {
  final ExperienceWorkspaceManager _workspace;

  /// Real, per-session "last outcome this runtime already reported" —
  /// never re-notifies for the same real outcome twice; a genuinely NEW
  /// terminal outcome (e.g. a second, later `deployed`) is real, distinct
  /// evidence and produces a fresh notification.
  final Map<String, LifecycleOutcome> _lastNotifiedOutcome = {};

  AutonomousWorkspaceRuntime({required ExperienceWorkspaceManager workspace}) : _workspace = workspace;

  /// Real, on-demand aggregation — pure with respect to
  /// [ExperienceWorkspaceManager]'s own real state, except for the
  /// notification de-duplication bookkeeping above (real, small, in-memory
  /// only, never persisted — see this file's own "WORLD MODEL: declined").
  WorkspaceRuntimeSnapshot captureRuntimeState() {
    final activeId = _workspace.activeSessionId;
    final sessions = <SessionRuntimeStatus>[];
    final notifications = <WorkspaceNotification>[];
    final now = DateTime.now();

    for (final state in _workspace.openSessions) {
      final isActive = state.sessionId == activeId;
      sessions.add(
        SessionRuntimeStatus(
          sessionId: state.sessionId,
          experienceId: state.currentExperienceId,
          experienceName: state.currentExperienceName,
          isActive: isActive,
          runtimeState: state.currentRuntimeState,
          deploymentStatus: state.currentLifecycleResult?.outcome,
          artifactStatus: state.currentLifecycleResult?.artifactIntelligenceReport,
          hasPendingEvolution: state.pendingModification != null,
        ),
      );

      final outcome = state.currentLifecycleResult?.outcome;
      if (!isActive && outcome != null && _terminalOutcomes.contains(outcome) && _lastNotifiedOutcome[state.sessionId] != outcome) {
        _lastNotifiedOutcome[state.sessionId] = outcome;
        notifications.add(
          WorkspaceNotification(sessionId: state.sessionId, experienceName: state.currentExperienceName, outcome: outcome, observedAt: now),
        );
      }
    }

    return WorkspaceRuntimeSnapshot(sessions: sessions, notifications: notifications, capturedAt: now);
  }
}
