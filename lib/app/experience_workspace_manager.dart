/// ExperienceWorkspaceManager — Implementation Specification IS-R32. Owns
/// the user's WORKSPACE — which experiences are currently open in this
/// running app, which one is active, and a workspace-level activity
/// timeline — as a pure COMPOSITION over the real, unmodified
/// `IntentSessionManager` (R31):
///
///   openExperience(intent)              -> IntentSessionManager.startSession()
///   continueExperience(sessionId, intent) -> IntentSessionManager.continueSession()
///
/// `IntentSessionManager` is never modified, never duplicated, never
/// re-implemented — it already owns per-session engineering/runtime state
/// (`SessionState`) and already supports many concurrent sessions
/// (`Map<String, SessionState>`, confirmed by reading its source). This
/// class adds ONLY the genuinely new, workspace-level concepts
/// `IntentSessionManager` has no notion of: which sessions are "open" for
/// display purposes, which one is "active," and workspace-scoped timeline
/// events. It never tracks a second copy of engineering/lifecycle/runtime
/// state — every real per-session read goes through
/// `IntentSessionManager.sessionFor()`.
///
/// REALITY: `ExperiencesScreen` (`lib/features/experiences/experiences_screen.dart`)
/// already exists and solves a DIFFERENT, already-real problem — browsing
/// every PERSISTED Experience via `SqliteExperienceRepository`, independent
/// of whether any of them are currently open in this running app session.
/// "Workspace" here means the latter: experiences with a live, in-memory
/// `SessionState` in the CURRENT process, never a duplicate of the
/// persisted-experience browse list.
///
/// WORLD MODEL: declined, for the same reason R31 declined it for
/// `IntentSessionManager` itself — a workspace has no durable identity
/// independent of the running app process; persisting it would invent a
/// concept with no real reuse case (R10-R12/R14/R15/R24/R28/R29/R31's
/// established precedent).
library;

import '../core/contracts/intent.dart';
import '../runtime/experience_session.dart';
import '../storage/activity_repository.dart';
import 'intent_session_manager.dart';

class ExperienceWorkspaceManager {
  final IntentSessionManager _sessionManager;
  final ActivityRepository _activity;

  /// Real, workspace-level session ordering — never a duplicate of
  /// `IntentSessionManager`'s own internal session map, only the subset of
  /// its keys this workspace currently considers "open."
  final List<String> _openSessionIds = [];
  String? _activeSessionId;

  final List<ActivityEvent> _timeline = [];

  ExperienceWorkspaceManager({
    required IntentSessionManager sessionManager,
    ActivityRepository? activity,
  }) : _sessionManager = sessionManager,
       _activity = activity ?? ActivityRepository();

  /// Real, in-order snapshot of every session this workspace currently
  /// considers open — filters out any id `IntentSessionManager` no longer
  /// recognizes (never fabricated).
  List<SessionState> get openSessions => [
    for (final id in _openSessionIds)
      if (_sessionManager.sessionFor(id) case final s?) s,
  ];

  List<String> get openSessionIds => List.unmodifiable(_openSessionIds);

  String? get activeSessionId => _activeSessionId;

  /// `null` when no session is active, or the active one is no longer
  /// tracked by `IntentSessionManager` — never a stale/fabricated result.
  SessionState? get activeSession => _activeSessionId == null
      ? null
      : _sessionManager.sessionFor(_activeSessionId!);

  List<ActivityEvent> get timeline => List.unmodifiable(_timeline);

  /// Real, first-match lookup by experience id across currently-open
  /// sessions — the bridge a UI caller that only knows an `experienceId`
  /// (e.g. `ExperienceHostScreen`) needs to find its real workspace
  /// session, if one is open. `null` when none is.
  SessionState? sessionForExperience(String experienceId) {
    for (final id in _openSessionIds) {
      final state = _sessionManager.sessionFor(id);
      if (state?.currentExperienceId == experienceId) return state;
    }
    return null;
  }

  /// Opens a new experience: delegates entirely to the real, unmodified
  /// `IntentSessionManager.startSession()`, then tracks the resulting
  /// session as open and — when it's the workspace's first — active.
  Future<SessionStartResult> openExperience(Intent intent) async {
    final result = await _sessionManager.startSession(intent);
    _openSessionIds.add(result.sessionId);
    _activeSessionId ??= result.sessionId;
    await _record(
      type: 'workspace_opened',
      sessionId: result.sessionId,
      message: 'Opened session ${result.sessionId}',
    );
    return result;
  }

  /// Opens an ALREADY-RESOLVED, already-loaded experience by explicit id —
  /// Implementation Specification IS-R45. Mirrors [openExperience]'s exact
  /// real bookkeeping (tracks the session as open, activates it if it's
  /// the workspace's first) but delegates to
  /// `IntentSessionManager.startSessionForExistingExperience()` instead of
  /// `startSession(Intent)` — never touches the Kernel/AI boundary. For
  /// entry paths that already know exactly which Experience to open
  /// (Recent list, birth completion, protection resume) rather than
  /// resolving one from ambiguous intent text.
  Future<SessionStartResult> openExistingExperience({
    required String experienceId,
    required String experienceName,
  }) async {
    final result = await _sessionManager.startSessionForExistingExperience(
      experienceId: experienceId,
      experienceName: experienceName,
    );
    _openSessionIds.add(result.sessionId);
    _activeSessionId ??= result.sessionId;
    await _record(
      type: 'workspace_opened',
      sessionId: result.sessionId,
      message: 'Opened session ${result.sessionId}',
    );
    return result;
  }

  /// Continues an already-open experience: delegates entirely to the real,
  /// unmodified `IntentSessionManager.continueSession()` — never
  /// re-implements evolution/regeneration logic.
  Future<SessionContinueResult> continueExperience(
    String sessionId,
    Intent intent,
  ) async {
    if (!_openSessionIds.contains(sessionId)) {
      throw StateError('Session $sessionId is not open in this workspace.');
    }
    return _sessionManager.continueSession(sessionId, intent);
  }

  /// Real, workspace-level close — never deletes the persisted Experience
  /// itself (that stays `SqliteExperienceRepository.delete()`'s own,
  /// separate, already-real responsibility via `ExperiencesScreen`); this
  /// only stops the workspace from tracking the session as open. If the
  /// closed session was active, a real remaining open session (if any)
  /// becomes active — never a fabricated one.
  Future<void> closeExperience(String sessionId) async {
    if (!_openSessionIds.remove(sessionId)) return;
    if (_activeSessionId == sessionId) {
      _activeSessionId = _openSessionIds.isEmpty ? null : _openSessionIds.last;
    }
    await _record(
      type: 'workspace_closed',
      sessionId: sessionId,
      message: 'Closed session $sessionId',
    );
  }

  /// Real, honest validation: switching to a session the workspace does
  /// not consider open is a real programming error, never a silent no-op.
  Future<void> switchActiveExperience(String sessionId) async {
    if (!_openSessionIds.contains(sessionId)) {
      throw StateError(
        'Cannot switch to session $sessionId — it is not open in this workspace.',
      );
    }
    _activeSessionId = sessionId;
    await _record(
      type: 'workspace_switched',
      sessionId: sessionId,
      message: 'Switched to session $sessionId',
    );
  }

  /// A caller (the real, live `ExperienceHostScreen`, once fully wired)
  /// reports its runtime's own real, current `ExperienceSession` — forwards
  /// unmodified to `IntentSessionManager.updateRuntimeState()`, the SAME
  /// real per-session storage R31 already built; this workspace never
  /// tracks a second, parallel copy of runtime state.
  void updateRuntimeState(String sessionId, ExperienceSession runtimeState) {
    _sessionManager.updateRuntimeState(sessionId, runtimeState);
  }

  /// Real bridge for a caller that only knows an `experienceId` (not a
  /// `sessionId`) — a harmless no-op when no open session matches, never a
  /// fabricated update.
  void reportRuntimeStateForExperience(
    String experienceId,
    ExperienceSession runtimeState,
  ) {
    final session = sessionForExperience(experienceId);
    if (session != null) updateRuntimeState(session.sessionId, runtimeState);
  }

  Future<void> _record({
    required String type,
    required String sessionId,
    required String message,
  }) async {
    final state = _sessionManager.sessionFor(sessionId);
    final event = ActivityEvent(
      id: '$sessionId-workspace-${_timeline.length}',
      type: type,
      experienceId: state?.currentExperienceId,
      experienceName: state?.currentExperienceName ?? '',
      message: message,
      timestamp: DateTime.now(),
    );
    _timeline.insert(0, event);
    await _activity.record(event);
  }
}
