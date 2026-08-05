/// UniversalIntentRouter — Implementation Specification IS-R33. Decides
/// WHICH real `ExperienceWorkspaceManager` (R32) method a caller should
/// invoke for one `Intent`, invokes it, and surfaces the real result — the
/// missing decision layer above a workspace whose caller, today, must
/// already know itself whether to call `.openExperience()` or
/// `.continueExperience()` (confirmed by reading `ExperienceWorkspaceManager`
/// in full: neither method decides this for the caller).
///
/// ZERO NEW REASONING: routing is a pure, deterministic, STRUCTURAL
/// decision — never semantic interpretation of `Intent.expression`'s raw
/// text (that would be a second reasoning boundary, forbidden by this
/// specification's own "AI BOUNDARY: Still exactly ONE"). The only inputs
/// are (a) the real, already-computed workspace state
/// (`ExperienceWorkspaceManager.openSessionIds`/`.activeSessionId`/
/// `.sessionForExperience()`, all real, unmodified, R32) and (b) an
/// explicit, caller-supplied [RouteTarget] — never inferred from intent
/// text. `Intent` itself (`lib/core/contracts/intent.dart`) has no field
/// that could honestly indicate "this refers to an existing session" — a
/// caller (a real UI) is the only one that knows which button/session the
/// user actually touched.
///
/// ACTION VOCABULARY, investigated and collapsed honestly: `Experience
/// WorkspaceManager` exposes exactly ONE real method for "act on an
/// already-open session" — `continueExperience(sessionId, intent)`. R33's
/// own "Continue Existing Session," "Modify Existing Experience," and
/// "Resume Background Session" are NOT three different real calls — they
/// are the SAME real call, reached via three different real STRUCTURAL
/// paths (which sessionId gets resolved, and whether a real
/// `switchActiveExperience()` runs first). Named distinctly in
/// [RoutingAction] because the PATH that reached the call is real,
/// observable, and worth reporting — never because three different
/// executions occur. "Clarification Required"/"Provider Required"/"No
/// Action" are not routing decisions this class makes — they are real,
/// already-typed outcomes (`CreationClarification`/`CreationProviderRequired`
/// on `CreationResult`; `LifecycleOutcome.noChangeDetected`/
/// `.noActionableTarget` on `LifecycleResult`) that `ExperienceWorkspaceManager`'s
/// own real calls already produce — this router faithfully SURFACES them
/// in [RoutingResult], never re-derives or reinterprets them.
library;

import '../core/contracts/intent.dart';
import 'creation_coordinator.dart';
import 'engineering_lifecycle_coordinator.dart';
import 'experience_workspace_manager.dart';

/// The real, structural path a route decision took — never a claim about
/// which underlying method ran (both `continueSession`-shaped actions call
/// the exact same `ExperienceWorkspaceManager.continueExperience()`).
enum RoutingAction {
  /// Either no target was supplied and no session is open in the
  /// workspace, OR `RouteTarget.newExperience()` was explicitly supplied
  /// (the only way to open a second experience while one is already
  /// active) — routed to `ExperienceWorkspaceManager.openExperience()`.
  newExperience,

  /// No target supplied, but a real active session exists — routed to
  /// `continueExperience()` against it.
  continueActiveSession,

  /// A target was supplied and it IS the active session — the same real
  /// call as [continueActiveSession], named distinctly only because the
  /// caller was explicit rather than implicit.
  modifyActiveExperience,

  /// A target was supplied naming a real, OPEN-but-NOT-active session — a
  /// real `switchActiveExperience()` runs first, then `continueExperience()`.
  resumeBackgroundSession,

  /// A target was supplied that names no session this workspace considers
  /// open — a real, honest rejection. Never silently falls back to
  /// [newExperience].
  unknownTarget,
}

/// An explicit, caller-supplied routing target — either a real, open
/// `sessionId`, a real `experienceId` this router resolves to its open
/// session via `ExperienceWorkspaceManager.sessionForExperience()`, or an
/// explicit request to force a brand-new experience regardless of any
/// active session (real, structural — e.g. a "New" button in a UI; a
/// caller with no explicit signal at all should pass `target: null`, the
/// default, which falls back to the workspace's own active-session
/// state). Never inferred from intent text.
class RouteTarget {
  final String? sessionId;
  final String? experienceId;
  final bool forceNew;

  const RouteTarget.session(this.sessionId) : experienceId = null, forceNew = false;
  const RouteTarget.experience(this.experienceId) : sessionId = null, forceNew = false;
  const RouteTarget.newExperience() : sessionId = null, experienceId = null, forceNew = true;
}

/// Real, typed result — every field traceable to the real call this router
/// made; exactly one of [creationResult]/[lifecycleResult] is non-null,
/// matching [action].
class RoutingResult {
  final RoutingAction action;
  final String? sessionId;
  final CreationResult? creationResult;
  final LifecycleResult? lifecycleResult;

  const RoutingResult({required this.action, this.sessionId, this.creationResult, this.lifecycleResult});
}

class UniversalIntentRouter {
  final ExperienceWorkspaceManager _workspace;

  const UniversalIntentRouter({required ExperienceWorkspaceManager workspace}) : _workspace = workspace;

  /// Real, deterministic dispatch. [target] is the caller's explicit,
  /// structural routing hint — never derived from [intent]'s own text.
  Future<RoutingResult> route(Intent intent, {RouteTarget? target}) async {
    // Explicit "start brand-new" request (e.g. a real "New" UI action) —
    // bypasses any active-session fallback entirely; the only real,
    // structural way to open a SECOND experience once one is already
    // active (omitting `target` always means "continue the active one if
    // any," never "open another").
    if (target?.forceNew ?? false) {
      final result = await _workspace.openExperience(intent);
      return RoutingResult(action: RoutingAction.newExperience, sessionId: result.sessionId, creationResult: result.creationResult);
    }

    final resolvedSessionId = _resolveTarget(target);

    if (target != null && resolvedSessionId == null) {
      // A target was named but resolves to nothing this workspace has
      // open — a real, honest rejection, never a silent fallback to
      // "new experience" (that would silently discard the user's real
      // intent to act on a SPECIFIC, named session).
      return const RoutingResult(action: RoutingAction.unknownTarget);
    }

    if (resolvedSessionId == null) {
      final active = _workspace.activeSessionId;
      if (active == null) {
        final result = await _workspace.openExperience(intent);
        return RoutingResult(action: RoutingAction.newExperience, sessionId: result.sessionId, creationResult: result.creationResult);
      }
      final result = await _workspace.continueExperience(active, intent);
      return RoutingResult(action: RoutingAction.continueActiveSession, sessionId: active, lifecycleResult: result.lifecycleResult);
    }

    final action = resolvedSessionId == _workspace.activeSessionId ? RoutingAction.modifyActiveExperience : RoutingAction.resumeBackgroundSession;
    if (action == RoutingAction.resumeBackgroundSession) {
      await _workspace.switchActiveExperience(resolvedSessionId);
    }
    final result = await _workspace.continueExperience(resolvedSessionId, intent);
    return RoutingResult(action: action, sessionId: resolvedSessionId, lifecycleResult: result.lifecycleResult);
  }

  /// Real, structural resolution — `null` when [target] is `null` (no
  /// explicit target) OR names a session/experience this workspace does
  /// not currently have open (the caller of [route] distinguishes these
  /// two `null` cases via `target != null`).
  String? _resolveTarget(RouteTarget? target) {
    if (target == null) return null;
    if (target.sessionId != null) {
      return _workspace.openSessionIds.contains(target.sessionId) ? target.sessionId : null;
    }
    final state = _workspace.sessionForExperience(target.experienceId!);
    return state?.sessionId;
  }
}
