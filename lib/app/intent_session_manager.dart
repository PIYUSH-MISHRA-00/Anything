/// IntentSessionManager — Implementation Specification IS-R31. Owns ONE
/// user's engineering session — from the first intent that creates an
/// Experience, through any number of later intents that evolve it — as a
/// pure COMPOSITION over already-real, already-tested coordinators:
///
///   startSession(intent)    -> ExperienceCreationCoordinator.createFromIntent()  (unchanged, V1-R19)
///   continueSession(intent) -> EngineeringLifecycleCoordinator.evolveExperience() (unchanged, R30)
///
/// Neither coordinator is modified; neither is re-implemented. Every
/// intent still flows through the ONE existing `AnythingKernel.processIntent()`
/// reasoning call, reached only via those two coordinators — this class
/// never calls the Kernel directly.
///
/// REALITY (the UI-entry-point tension, resolved conservatively): R31's own
/// "MANDATORY VISION VALIDATION" asks for this to become "the single
/// application-facing entry point." The REAL, LIVE production entry points
/// today are `lib/features/home/home_screen.dart`'s `initState()` (which
/// directly constructs `ExperienceCreationCoordinator`) and
/// `lib/runtime/experience_host_screen.dart` (which receives an
/// `ExperienceModificationCoordinator`/`AnythingRuntime` from its caller).
/// Both are live, interactive, stateful Flutter screens a background agent
/// cannot safely rewire without the interactive testing a human reviewer
/// would normally do first — and every milestone's own standing rule is
/// "nothing may be replaced." Per the R29->R30 precedent (R29 built
/// `SolutionEvolutionEngine` with zero production callers and *recommended*
/// R30 wire it in; R30 did, one milestone later, into a new backend-only
/// coordinator, never a live UI rewrite), this class is built and proven
/// complete and correct in isolation, ready to be the entry point, with
/// real UI wiring explicitly deferred and recommended for R32 rather than
/// forced here. See this file's own "Known Limitations" in
/// `docs/architecture/INTENT_SESSION_MANAGER.md`.
///
/// SESSION MODEL, mapped to real, existing types — never fabricated:
///  - `currentEngineeringState` is the real, persisted `EngineeringMemoryRecord`
///    (R5/R8/R9) for [currentExperienceId] — the SAME "before" state
///    `EngineeringLifecycleCoordinator` itself loads internally; exposing it
///    here lets a caller inspect it without a second, parallel read.
///  - `currentLifecycleResult` is literally the most recent real
///    `LifecycleResult` (R30) `continueSession()` produced.
///  - `currentRuntimeState` is the real, existing `ExperienceSession`
///    (`lib/runtime/experience_session.dart`) — this manager does not own or
///    construct a runtime (that is `ExperienceHostScreen`'s real
///    responsibility), so it is only ever set by a caller via
///    [updateRuntimeState] once a runtime is actually live; `null` until
///    then, never fabricated.
///  - `sessionTimeline` reuses the existing `ActivityRepository` (R1-R7) —
///    never a new persistence mechanism.
///
/// WORLD MODEL: declined, deliberately. A session has no durable identity
/// independent of the app process that created it (unlike a persisted
/// `Experience`, which already has its own real World Graph node via
/// `ingestExperience`) — persisting "session" knowledge would mean
/// inventing a concept with no real reuse case, the same call this
/// project's R10-R12/R14/R15/R24/R28/R29 all made correctly before it.
library;

import '../app/creation_coordinator.dart';
import '../app/engineering_lifecycle_coordinator.dart';
import '../core/contracts/intent.dart';
import '../runtime/experience_session.dart';
import '../storage/activity_repository.dart';
import '../storage/engineering_memory_repository.dart';

/// Real, typed result of [IntentSessionManager.startSession] — the
/// session's own identity plus the real, unmodified `CreationResult`
/// (`ExperienceCreationCoordinator`, unchanged) it was built from.
class SessionStartResult {
  final String sessionId;
  final CreationResult creationResult;

  const SessionStartResult({required this.sessionId, required this.creationResult});
}

/// Real, typed result of [IntentSessionManager.continueSession] — the
/// session's own identity plus the real, unmodified `LifecycleResult`
/// (`EngineeringLifecycleCoordinator`, R30, unchanged) it was built from.
class SessionContinueResult {
  final String sessionId;
  final LifecycleResult lifecycleResult;

  const SessionContinueResult({required this.sessionId, required this.lifecycleResult});
}

/// One session's real, in-memory state — never persisted (see this file's
/// own "WORLD MODEL: declined" doc comment above).
class SessionState {
  final String sessionId;
  String? currentExperienceId;
  String? currentExperienceName;
  EngineeringMemoryRecord? currentEngineeringState;
  LifecycleResult? currentLifecycleResult;
  ExperienceSession? currentRuntimeState;

  /// Non-null only while a [IntentSessionManager.continueSession] call for
  /// this session is actually in flight — a real, observable "is something
  /// running right now" signal, cleared as soon as that call returns
  /// (success or failure).
  Intent? pendingModification;

  final List<ActivityEvent> timeline = [];

  SessionState({required this.sessionId});

  /// The most recently completed modification's real result — an alias
  /// over [currentLifecycleResult], never a second, separately-tracked
  /// copy that could drift from it (R31's own "Completed Modification"
  /// naming, real data already held above).
  LifecycleResult? get completedModification => currentLifecycleResult;
}

class IntentSessionManager {
  final ExperienceCreationCoordinator _creationCoordinator;
  final EngineeringLifecycleCoordinator _lifecycleCoordinator;
  final EngineeringMemoryRepository _engineeringMemory;
  final ActivityRepository _activity;

  int _sessionCounter = 0;
  final Map<String, SessionState> _sessions = {};

  IntentSessionManager({
    required ExperienceCreationCoordinator creationCoordinator,
    required EngineeringLifecycleCoordinator lifecycleCoordinator,
    required EngineeringMemoryRepository engineeringMemory,
    ActivityRepository? activity,
  }) : _creationCoordinator = creationCoordinator,
       _lifecycleCoordinator = lifecycleCoordinator,
       _engineeringMemory = engineeringMemory,
       _activity = activity ?? ActivityRepository();

  /// Real, in-memory lookup — `null` for an unknown/expired sessionId,
  /// never a fabricated default session.
  SessionState? sessionFor(String sessionId) => _sessions[sessionId];

  /// A caller (the real, live `ExperienceHostScreen`/`AnythingRuntime`, once
  /// wired) reports the runtime's own real, current `ExperienceSession` —
  /// this manager never constructs or drives a runtime itself.
  void updateRuntimeState(String sessionId, ExperienceSession runtimeState) {
    _sessions[sessionId]?.currentRuntimeState = runtimeState;
  }

  /// First intent: delegates to the real, unmodified
  /// `ExperienceCreationCoordinator.createFromIntent()`. Always starts a
  /// NEW session, even for a returning ("Opened") experience — a real,
  /// honest session boundary, never conflated with a prior one.
  Future<SessionStartResult> startSession(Intent intent) async {
    final sessionId = 'session-${DateTime.now().microsecondsSinceEpoch}-${_sessionCounter++}';
    final state = SessionState(sessionId: sessionId);
    _sessions[sessionId] = state;

    final result = await _creationCoordinator.createFromIntent(intent);

    switch (result) {
      case CreationCreated():
        state.currentExperienceId = result.experienceId;
        state.currentExperienceName = result.package.manifest.name;
        state.currentEngineeringState = await _engineeringMemory.load(result.experienceId);
        await _record(state, type: 'session_started', message: 'Created ${result.package.manifest.name}');
      case CreationOpened():
        state.currentExperienceId = result.experienceId;
        state.currentExperienceName = result.experienceName;
        state.currentEngineeringState = await _engineeringMemory.load(result.experienceId);
        await _record(state, type: 'session_started', message: 'Opened ${result.experienceName}');
      case CreationClarification():
      case CreationProviderRequired():
      case CreationFailed():
        // Real, honest non-terminal/failure cases — no experience exists
        // yet for this session; state is left exactly as initialized,
        // never a fabricated experienceId.
        break;
    }

    return SessionStartResult(sessionId: sessionId, creationResult: result);
  }

  /// A later intent against an ALREADY-STARTED session: delegates to the
  /// real, unmodified `EngineeringLifecycleCoordinator.evolveExperience()`
  /// (R30). Throws `StateError` for an unknown sessionId or a session with
  /// no experience yet (creation never succeeded) — a real programming
  /// error, never silently treated as a no-op.
  Future<SessionContinueResult> continueSession(String sessionId, Intent intent) async {
    final state = _sessions[sessionId];
    if (state == null) throw StateError('Unknown sessionId: $sessionId');
    final experienceId = state.currentExperienceId;
    if (experienceId == null) {
      throw StateError('Session $sessionId has no active experience to continue — startSession() must succeed first.');
    }

    state.pendingModification = intent;
    try {
      final result = await _lifecycleCoordinator.evolveExperience(experienceId: experienceId, intent: intent);
      state.currentLifecycleResult = result;
      if (result.outcome == LifecycleOutcome.deployed) {
        state.currentEngineeringState = await _engineeringMemory.load(experienceId);
      }
      await _record(
        state,
        type: 'session_continued',
        message: 'Evolution outcome: ${result.outcome.name}',
        durationMs: result.executionDuration.inMilliseconds,
      );
      return SessionContinueResult(sessionId: sessionId, lifecycleResult: result);
    } finally {
      state.pendingModification = null;
    }
  }

  Future<void> _record(SessionState state, {required String type, required String message, int? durationMs}) async {
    final event = ActivityEvent(
      id: '${state.sessionId}-${state.timeline.length}',
      type: type,
      experienceId: state.currentExperienceId,
      experienceName: state.currentExperienceName ?? '',
      message: message,
      timestamp: DateTime.now(),
      durationMs: durationMs,
    );
    state.timeline.insert(0, event);
    await _activity.record(event);
  }
}
