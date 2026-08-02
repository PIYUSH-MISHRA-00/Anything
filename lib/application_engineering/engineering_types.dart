/// Application Engineering Engine (AEE) — core typed vocabulary.
///
/// Event graph primitives, the generic state machine, the binding graph,
/// and the base EngineeringDecision record every *Engineering module
/// produces. No Maps, no dynamic, no JSON blobs in this public model.
library;

import '../software_architect/confidence.dart';

// ── Event graph ──────────────────────────────────────────────────────────

/// What causes an event to fire.
enum TriggerKind { userAction, lifecycleHook, dataChange, timer, external }

class Trigger {
  final TriggerKind kind;
  final String sourceId;

  const Trigger({required this.kind, required this.sourceId});
}

/// A precondition gating whether a transition/effect may run.
class Condition {
  final String description;
  final String subjectId;

  const Condition({required this.description, required this.subjectId});
}

/// A side effect an action produces (a data mutation, a navigation, a
/// capability invocation — always expressed in terms the existing
/// BehaviorGraph already executes, never a new runtime primitive).
enum EffectKind { dataMutation, dataQuery, stateWrite, navigation, capabilityInvocation }

class Effect {
  final EffectKind kind;
  final String targetId;
  final String description;

  const Effect({required this.kind, required this.targetId, required this.description});
}

/// A retry policy for a fallible effect.
class RetryPolicy {
  final int maxAttempts;
  final Duration backoff;

  const RetryPolicy({this.maxAttempts = 1, this.backoff = Duration.zero});

  static const none = RetryPolicy();
}

/// Whether/how an in-flight action can be cancelled.
enum CancellationPolicy { notCancellable, cancellableBeforeCommit }

/// A bounded timeout for an effect (mirrors the same
/// bounded-by-default philosophy as RuntimeSecurityLimits).
class Timeout {
  final Duration duration;
  const Timeout(this.duration);

  static const Timeout none = Timeout(Duration.zero);
}

/// One node in the event graph: an action, its trigger, its guarding
/// conditions, its effects (ordered), and its failure-handling policy.
class Action {
  final String id;
  final String name;
  final String entityId;
  final Trigger trigger;
  final List<Condition> conditions;
  final List<Effect> effects;
  final RetryPolicy retryPolicy;
  final CancellationPolicy cancellationPolicy;
  final Timeout timeout;

  const Action({
    required this.id,
    required this.name,
    required this.entityId,
    required this.trigger,
    this.conditions = const [],
    this.effects = const [],
    this.retryPolicy = RetryPolicy.none,
    this.cancellationPolicy = CancellationPolicy.notCancellable,
    this.timeout = Timeout.none,
  });
}

/// An ordering constraint between two actions (A must complete/start
/// before B) — deterministic, no implicit concurrency.
class Ordering {
  final String beforeActionId;
  final String afterActionId;

  const Ordering({required this.beforeActionId, required this.afterActionId});
}

/// A dependency of one action on another entity/action's state.
class Dependency {
  final String actionId;
  final String dependsOnId;

  const Dependency({required this.actionId, required this.dependsOnId});
}

class Event {
  final String id;
  final String name;
  final String actionId;

  const Event({required this.id, required this.name, required this.actionId});
}

/// A transition fired by an event, from one generic state to another.
class Transition {
  final String eventId;
  final GenericState from;
  final GenericState to;

  const Transition({required this.eventId, required this.from, required this.to});
}

/// The complete, typed event graph for one entity.
class EventGraph {
  final String entityId;
  final List<Event> events;
  final List<Action> actions;
  final List<Ordering> orderings;
  final List<Dependency> dependencies;

  const EventGraph({
    required this.entityId,
    this.events = const [],
    this.actions = const [],
    this.orderings = const [],
    this.dependencies = const [],
  });

  Action? actionById(String id) => actions.where((a) => a.id == id).firstOrNull;
  Event? eventById(String id) => events.where((e) => e.id == id).firstOrNull;
}

// ── State machine — generic, never domain-specific ──────────────────────

/// The fixed, generic state vocabulary. No "NotesState"/"CalculatorState"
/// — every generated entity's lifecycle is expressed in these terms.
enum GenericState {
  idle,
  loading,
  editing,
  saving,
  deleting,
  searching,
  filtering,
  sorting,
  refreshing,
  offline,
  synchronizing,
  completed,
  error,
}

class StateMachineDefinition {
  final String entityId;
  final GenericState initial;
  final List<Transition> transitions;

  const StateMachineDefinition({
    required this.entityId,
    this.initial = GenericState.idle,
    this.transitions = const [],
  });

  bool hasTransitionFor(String eventId) => transitions.any((t) => t.eventId == eventId);
}

// ── Binding graph — typed, no string-map lookups ────────────────────────

enum BindingKind { viewToState, stateToData, dataToRuntime, capabilityToRuntime }

/// One typed binding edge. Endpoints are structured identifiers
/// (`entityId.fieldId`-shaped or a bare id), never resolved via a runtime
/// `Map<String, dynamic>` lookup — the identifiers here are exactly the
/// same stable ids ExperienceRenderer/BehaviorInterpreter already use.
class BindingEdge {
  final BindingKind kind;
  final String fromId;
  final String toId;

  const BindingEdge({required this.kind, required this.fromId, required this.toId});
}

class BindingGraph {
  final List<BindingEdge> edges;
  const BindingGraph({this.edges = const []});

  List<BindingEdge> edgesOfKind(BindingKind kind) => edges.where((e) => e.kind == kind).toList();
}

// ── The base decision record every *Engineering module produces ────────

enum EngineeringDecisionCategory {
  behavior,
  data,
  navigation,
  interaction,
  binding,
  validation,
  persistence,
  migration,
  offline,
  synchronization,
  lifecycle,
  performance,
  accessibility,
  security,
}

class EngineeringDecision {
  final String id;
  final EngineeringDecisionCategory category;
  final String subjectId;
  final String decision;
  final String rationale;
  final Confidence confidence;

  const EngineeringDecision({
    required this.id,
    required this.category,
    required this.subjectId,
    required this.decision,
    required this.rationale,
    required this.confidence,
  });
}
