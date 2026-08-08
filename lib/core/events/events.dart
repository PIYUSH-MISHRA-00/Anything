/// Typed event system for Anything v2.
///
/// All communication within Anything occurs through events.
/// This provides a minimal, typed event abstraction for
/// the local event bus.
///
/// REALITY (Implementation Specification IS-R35): this file — `EventBus`,
/// `AnythingEvent`, and its 11 original subtypes — already existed, fully
/// real and tested (`test/contracts/events_test.dart`), but had ZERO
/// production callers anywhere in `lib/` (confirmed by grep before this
/// milestone). This is the SAME "real, tested, orphaned subsystem" pattern
/// R14/R16/R30 each found and wired in — R35 is that wiring for this file,
/// never a second event/notification system.
library;

import 'dart:async';

/// Real, closed vocabulary matching R35's own "EVENT MODEL: Category" —
/// `general` covers every pre-R35 event (backward compatible default).
enum EventCategory {
  general,
  intent,
  session,
  workspace,
  runtime,
  lifecycle,
  artifact,
  deployment,
  notification,
}

/// Real, closed vocabulary matching R35's own "EVENT MODEL: Severity."
enum EventSeverity { info, warning, error }

/// Base class for all Anything events.
///
/// Events are immutable value objects that represent something
/// that happened within the system.
sealed class AnythingEvent {
  /// Unique identifier for this event.
  final String id;

  /// Timestamp when this event occurred.
  final DateTime timestamp;

  /// The source component that emitted this event.
  final String source;

  /// Real, additive (R35) — `general`/`info`/`null` for every pre-R35
  /// event, since none of the 11 original subtypes forward these; new R35
  /// subtypes set them explicitly. [correlationId] links events from ONE
  /// real user action (e.g. route -> continue -> lifecycle-complete ->
  /// deployment-decision) without a new tracking mechanism. [payload] is a
  /// real, optional, freeform bag for anything a subtype's own typed
  /// fields don't already carry — every R35 subtype below already carries
  /// its real data as typed fields, so `payload` stays unused/`null` today,
  /// kept only as a real, named extension point for a future subtype.
  ///
  /// Named `eventCategory` (not `category`) — the pre-existing
  /// `IntentAnalyzed.category` (a `String`, its own real intent-
  /// classification concept, R-era, unrelated) already used that exact
  /// name; a same-named override here would have silently broken it
  /// (confirmed by `flutter analyze`, which caught this as a real
  /// `invalid_override` before this file was even finished — never
  /// touched `IntentAnalyzed` itself).
  final EventCategory eventCategory;
  final EventSeverity severity;
  final String? correlationId;
  final Map<String, dynamic>? payload;

  const AnythingEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    this.eventCategory = EventCategory.general,
    this.severity = EventSeverity.info,
    this.correlationId,
    this.payload,
  });
}

// --- Intent Events ---

/// User submitted a new intent.
class IntentSubmitted extends AnythingEvent {
  final String rawInput;

  const IntentSubmitted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.rawInput,
  });
}

/// Intent analysis completed.
class IntentAnalyzed extends AnythingEvent {
  final String intentId;
  final String category;
  final double confidence;

  const IntentAnalyzed({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.intentId,
    required this.category,
    required this.confidence,
  });
}

// --- Experience Events ---

/// A new experience was created.
class ExperienceCreated extends AnythingEvent {
  final String experienceId;
  final String title;

  const ExperienceCreated({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
    required this.title,
  });
}

/// An experience was opened.
class ExperienceOpenedEvent extends AnythingEvent {
  final String experienceId;

  const ExperienceOpenedEvent({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
  });
}

/// An experience was updated.
class ExperienceUpdated extends AnythingEvent {
  final String experienceId;

  const ExperienceUpdated({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
  });
}

/// An experience was deleted.
class ExperienceDeleted extends AnythingEvent {
  final String experienceId;

  const ExperienceDeleted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
  });
}

// --- Execution Events ---

/// Execution of a plan started.
class ExecutionStarted extends AnythingEvent {
  final String planId;

  const ExecutionStarted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.planId,
  });
}

/// Execution of a plan completed.
class ExecutionCompleted extends AnythingEvent {
  final String planId;

  const ExecutionCompleted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.planId,
  });
}

/// Execution of a plan failed.
class ExecutionFailed extends AnythingEvent {
  final String planId;
  final String error;

  const ExecutionFailed({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.planId,
    required this.error,
  });
}

// --- Knowledge Events ---

/// Knowledge was retrieved.
class KnowledgeRetrieved extends AnythingEvent {
  final String query;
  final int resultCount;

  const KnowledgeRetrieved({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.query,
    required this.resultCount,
  });
}

// --- Protection Events ---

/// Protection was applied to data.
class ProtectionApplied extends AnythingEvent {
  final String targetId;

  const ProtectionApplied({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.targetId,
  });
}

// --- Workspace Events (Implementation Specification IS-R35) ---
//
// Each subtype carries REAL data read directly from the real result type
// its name matches (`RoutingResult`/R33, `LifecycleResult`/R30,
// `WorkspaceRuntimeSnapshot`/`WorkspaceNotification`/R34,
// `SessionStartResult`/`SessionContinueResult`/R31) — never fabricated.
// None of these are published by the coordinators themselves (all of
// `ExperienceWorkspaceManager`/`UniversalIntentRouter`/
// `EngineeringLifecycleCoordinator`/`AutonomousWorkspaceRuntime` remain
// completely unmodified, confirmed by `git diff --stat`) — a caller
// invokes both the real coordinator method AND the matching real
// `lib/app/workspace_event_publisher.dart` translation function together.

class IntentRouted extends AnythingEvent {
  final String? sessionId;

  /// The real `RoutingAction` name (`newExperience`/`continueActiveSession`/
  /// `modifyActiveExperience`/`resumeBackgroundSession`/`unknownTarget`,
  /// R33) — kept as a plain `String` here so this file never depends on
  /// `lib/app/`, matching this codebase's established "`lib/core/` never
  /// imports application-layer types" layering.
  final String action;

  const IntentRouted({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    this.sessionId,
    required this.action,
  }) : super(eventCategory: EventCategory.intent);
}

class SessionCreated extends AnythingEvent {
  final String sessionId;
  final String? experienceId;

  const SessionCreated({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
    this.experienceId,
  }) : super(eventCategory: EventCategory.session);
}

class SessionContinued extends AnythingEvent {
  final String sessionId;

  /// The real `LifecycleOutcome` name (R30) — plain `String`, same
  /// layering reason as [IntentRouted.action].
  final String outcome;

  const SessionContinued({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
    required this.outcome,
  }) : super(eventCategory: EventCategory.session);
}

class SessionSwitched extends AnythingEvent {
  final String sessionId;

  const SessionSwitched({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
  }) : super(eventCategory: EventCategory.session);
}

class WorkspaceUpdated extends AnythingEvent {
  /// Real, plain description of what changed (`'opened'`/`'closed'`) —
  /// never a re-derivation of `ExperienceWorkspaceManager`'s own state.
  final String change;
  final String sessionId;

  const WorkspaceUpdated({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.change,
    required this.sessionId,
  }) : super(eventCategory: EventCategory.workspace);
}

class RuntimeSnapshotCaptured extends AnythingEvent {
  final int openSessionCount;
  final int notificationCount;

  const RuntimeSnapshotCaptured({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.openSessionCount,
    required this.notificationCount,
  }) : super(eventCategory: EventCategory.runtime);
}

class LifecycleCompleted extends AnythingEvent {
  final String sessionId;
  final String outcome;

  const LifecycleCompleted({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
    required this.outcome,
  }) : super(eventCategory: EventCategory.lifecycle);
}

class ArtifactUpdated extends AnythingEvent {
  final String sessionId;
  final bool deploymentReady;

  const ArtifactUpdated({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
    required this.deploymentReady,
  }) : super(eventCategory: EventCategory.artifact);
}

class DeploymentAllowed extends AnythingEvent {
  final String sessionId;

  const DeploymentAllowed({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
  }) : super(eventCategory: EventCategory.deployment);
}

class DeploymentBlocked extends AnythingEvent {
  final String sessionId;

  const DeploymentBlocked({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
  }) : super(
         eventCategory: EventCategory.deployment,
         severity: EventSeverity.warning,
       );
}

class CommitFailed extends AnythingEvent {
  final String sessionId;

  const CommitFailed({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
  }) : super(
         eventCategory: EventCategory.deployment,
         severity: EventSeverity.error,
       );
}

class NotificationGenerated extends AnythingEvent {
  final String sessionId;
  final String? experienceName;
  final String outcome;

  const NotificationGenerated({
    required super.id,
    required super.timestamp,
    required super.source,
    super.correlationId,
    required this.sessionId,
    this.experienceName,
    required this.outcome,
  }) : super(eventCategory: EventCategory.notification);
}

/// A simple local event bus for Anything.
///
/// Events are published and subscribed to within the same process.
/// This is not a distributed event system.
///
/// FIX (Implementation Specification IS-R35): the original implementation
/// stored one `StreamController` PER SUBSCRIBED TYPE in a `Map<Type, ...>`
/// — every call to `on<T>()` OVERWROTE the previous controller for that
/// same `T`, so a SECOND subscriber to the same event type silently
/// disconnected the FIRST (`publish()` only ever reached whichever
/// controller was registered last). This broke the exact multi-consumer
/// case R35 requires ("Workspace Runtime, Notifications, Future UI...
/// subscribe without direct coupling"). Real, minimal fix: ONE shared
/// broadcast stream; `on<T>()` returns a real, independent filtered VIEW
/// of it per call — any number of subscribers, of any mix of types, each
/// receive every event meant for them, correctly.
class EventBus {
  final _controller = StreamController<AnythingEvent>.broadcast();
  bool _disposed = false;

  /// Subscribe to events of a specific type — `on<AnythingEvent>()`
  /// receives everything (every real event `is AnythingEvent`), matching
  /// the original, unmodified, already-tested contract.
  Stream<T> on<T extends AnythingEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  /// Publish an event — a real, silent no-op after [dispose] (matches the
  /// original, already-tested "publish after dispose never throws"
  /// contract), never a fabricated success.
  void publish(AnythingEvent event) {
    if (_disposed) return;
    _controller.add(event);
  }

  /// Dispose the shared stream.
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
