/// WorkspaceEventPublisher — Implementation Specification IS-R35. Real,
/// pure translation from R30-R34's already-real result types into the
/// real `AnythingEvent` subtypes `lib/core/events/events.dart` now
/// carries — never invoked automatically by any coordinator (all of
/// `ExperienceWorkspaceManager`/`UniversalIntentRouter`/
/// `EngineeringLifecycleCoordinator`/`AutonomousWorkspaceRuntime` remain
/// unmodified). A caller invokes the real coordinator method AND the
/// matching method here, together — e.g.
/// `final result = await workspace.openExperience(intent);
/// publisher.publishSessionCreated(result);`.
library;

import '../app/autonomous_workspace_runtime.dart';
import '../app/creation_coordinator.dart';
import '../app/engineering_lifecycle_coordinator.dart';
import '../app/intent_session_manager.dart';
import '../app/universal_intent_router.dart';
import '../core/events/events.dart';

class WorkspaceEventPublisher {
  final EventBus _bus;
  final String source;
  int _counter = 0;

  WorkspaceEventPublisher({required EventBus bus, this.source = 'workspace'})
    : _bus = bus;

  String _id() =>
      '$source-event-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  void publishIntentRouted(RoutingResult result, {String? correlationId}) {
    _bus.publish(
      IntentRouted(
        id: _id(),
        timestamp: DateTime.now(),
        source: source,
        correlationId: correlationId,
        sessionId: result.sessionId,
        action: result.action.name,
      ),
    );
  }

  void publishSessionCreated(
    SessionStartResult result, {
    String? correlationId,
  }) {
    final experienceId = switch (result.creationResult) {
      CreationCreated(:final experienceId) => experienceId,
      CreationOpened(:final experienceId) => experienceId,
      _ => null,
    };
    _bus.publish(
      SessionCreated(
        id: _id(),
        timestamp: DateTime.now(),
        source: source,
        correlationId: correlationId,
        sessionId: result.sessionId,
        experienceId: experienceId,
      ),
    );
  }

  /// Real, paired publication — a `continueSession()`/`continueExperience()`
  /// call always completes a real `EngineeringLifecycleCoordinator
  /// .evolveExperience()` run (R30), so `SessionContinued` and
  /// `LifecycleCompleted` are always published together for the same
  /// real result, never independently faked.
  void publishSessionContinued(
    SessionContinueResult result, {
    String? correlationId,
  }) {
    final outcome = result.lifecycleResult.outcome;
    _bus.publish(
      SessionContinued(
        id: _id(),
        timestamp: DateTime.now(),
        source: source,
        correlationId: correlationId,
        sessionId: result.sessionId,
        outcome: outcome.name,
      ),
    );
    _bus.publish(
      LifecycleCompleted(
        id: _id(),
        timestamp: DateTime.now(),
        source: source,
        correlationId: correlationId,
        sessionId: result.sessionId,
        outcome: outcome.name,
      ),
    );

    final report = result.lifecycleResult.artifactIntelligenceReport;
    if (report != null) {
      _bus.publish(
        ArtifactUpdated(
          id: _id(),
          timestamp: DateTime.now(),
          source: source,
          correlationId: correlationId,
          sessionId: result.sessionId,
          deploymentReady: report.deploymentReady,
        ),
      );
    }

    switch (outcome) {
      case LifecycleOutcome.deployed:
        _bus.publish(
          DeploymentAllowed(
            id: _id(),
            timestamp: DateTime.now(),
            source: source,
            correlationId: correlationId,
            sessionId: result.sessionId,
          ),
        );
      case LifecycleOutcome.blocked:
        _bus.publish(
          DeploymentBlocked(
            id: _id(),
            timestamp: DateTime.now(),
            source: source,
            correlationId: correlationId,
            sessionId: result.sessionId,
          ),
        );
      case LifecycleOutcome.commitFailed:
        _bus.publish(
          CommitFailed(
            id: _id(),
            timestamp: DateTime.now(),
            source: source,
            correlationId: correlationId,
            sessionId: result.sessionId,
          ),
        );
      case LifecycleOutcome.noChangeDetected:
      case LifecycleOutcome.noActionableTarget:
      case LifecycleOutcome.noEngineeringMemory:
      case LifecycleOutcome.cannotEvolve:
      // Real, honest omission: nothing was attempted, or a real
      // precondition failed before any attempt — never a fabricated
      // deployment/commit event for a run that never reached one.
    }
  }

  void publishSessionSwitched(String sessionId, {String? correlationId}) {
    _bus.publish(
      SessionSwitched(
        id: _id(),
        timestamp: DateTime.now(),
        source: source,
        correlationId: correlationId,
        sessionId: sessionId,
      ),
    );
  }

  void publishWorkspaceUpdated(
    String change,
    String sessionId, {
    String? correlationId,
  }) {
    _bus.publish(
      WorkspaceUpdated(
        id: _id(),
        timestamp: DateTime.now(),
        source: source,
        correlationId: correlationId,
        change: change,
        sessionId: sessionId,
      ),
    );
  }

  /// Real, paired publication — one `RuntimeSnapshotCaptured` event for
  /// the whole real `WorkspaceRuntimeSnapshot`, plus one real
  /// `NotificationGenerated` event per real `WorkspaceNotification`
  /// `AutonomousWorkspaceRuntime.captureRuntimeState()` (R34) already,
  /// honestly, de-duplicated — never re-derived here.
  void publishRuntimeSnapshotCaptured(
    WorkspaceRuntimeSnapshot snapshot, {
    String? correlationId,
  }) {
    _bus.publish(
      RuntimeSnapshotCaptured(
        id: _id(),
        timestamp: DateTime.now(),
        source: source,
        correlationId: correlationId,
        openSessionCount: snapshot.sessions.length,
        notificationCount: snapshot.notifications.length,
      ),
    );
    for (final n in snapshot.notifications) {
      _bus.publish(
        NotificationGenerated(
          id: _id(),
          timestamp: DateTime.now(),
          source: source,
          correlationId: correlationId,
          sessionId: n.sessionId,
          experienceName: n.experienceName,
          outcome: n.outcome.name,
        ),
      );
    }
  }
}
