/// ExperienceRuntimeController — Implementation Specification IS-R38. The
/// ONE owner of runtime lifecycle for a running Experience: a thin, real
/// composition over `AnythingRuntime` (unmodified), `ExperienceWorkspaceManager`
/// (R32, unmodified), and `WorkspaceEventPublisher` (R35, unmodified) —
/// never a second runtime, never a new decision layer.
///
/// REALITY before R38 (confirmed by reading source): `AnythingRuntime`
/// already has a real, tested lifecycle API — `openExperience()`,
/// `pauseSession()`/`resumeSession()`, `closeSession()` — but
/// `pauseSession()`/`resumeSession()` have ZERO callers anywhere in `lib/`
/// (confirmed by grep), the exact "orphaned subsystem" pattern R14/R16/R30/
/// R35 each found and wired in. `ExperienceHostScreen` duplicates the real
/// `closeSession()` + `openExperience()` "reload" pair inline, verbatim, in
/// two places (`_runModification`'s success branch, `_performRollback`).
/// And `ExperienceHostScreen._reportRuntimeStateToWorkspace()` has never
/// reported the runtime's own REAL `AnythingRuntime.currentSession` to the
/// workspace — it hand-builds a SEPARATE, synthetic `ExperienceSession` with
/// a fabricated id, so `AutonomousWorkspaceRuntime.captureRuntimeState()`
/// (R34) has always read a stand-in, never the live runtime state. This
/// class fixes all three: gives pause/resume a real caller, factors the
/// duplicated reload pair into one tested method, and reports the REAL
/// `AnythingRuntime.currentSession` on every transition.
///
/// SNAPSHOT/RESTORE: no new type. `ExperienceSession` (already real,
/// already carries `package`/`status`) IS a sufficient, restorable
/// snapshot — restoring means re-opening the runtime from the snapshot's
/// own `package`, the same real primitive `start()`/`reload()` already use.
///
/// EVENTS: no new `AnythingEvent` subtype. `WorkspaceEventPublisher
/// .publishWorkspaceUpdated(change, sessionId)` (R35, unmodified) and the
/// existing `WorkspaceUpdated` event already fit — `ExperienceHostScreen`
/// already uses this exact mechanism for `change: 'runtime_loaded'`. This
/// milestone reuses it for `'runtime_started'`/`'runtime_paused'`/
/// `'runtime_resumed'`/`'runtime_reloaded'`/`'runtime_terminated'`.
library;

import '../app/experience_workspace_manager.dart';
import '../app/workspace_event_publisher.dart';
import '../creation/experience_package.dart';
import 'anything_runtime.dart';
import 'experience_session.dart';

class ExperienceRuntimeController {
  final AnythingRuntime runtime;
  final ExperienceWorkspaceManager? workspace;
  final WorkspaceEventPublisher? eventPublisher;

  /// The real experience id this controller reports/publishes under —
  /// independent of `runtime.currentSession`, which is `null` both before
  /// [start] and after [terminate]. Without this, [terminate] could never
  /// report/publish its own closing transition (the session is already
  /// gone by the time [AnythingRuntime.closeSession] returns).
  final String? experienceId;

  ExperienceRuntimeController({
    required this.runtime,
    this.workspace,
    this.eventPublisher,
    this.experienceId,
  });

  RuntimeStatus get status => runtime.status;
  ExperienceSession? get currentSession => runtime.currentSession;

  /// Start — opens [package] in the composed runtime.
  Future<ExperienceSession> start(ExperiencePackage package) async {
    final session = await runtime.openExperience(package);
    _reportAndPublish('runtime_started', session);
    return session;
  }

  /// Pause — the real, previously-dead `AnythingRuntime.pauseSession()`,
  /// now with a real, tested, reachable caller.
  void pause() {
    runtime.pauseSession();
    _reportAndPublish('runtime_paused', runtime.currentSession);
  }

  /// Resume — the real, previously-dead `AnythingRuntime.resumeSession()`.
  void resume() {
    runtime.resumeSession();
    _reportAndPublish('runtime_resumed', runtime.currentSession);
  }

  /// Reload — the exact real `closeSession()` + `openExperience()` pair
  /// `ExperienceHostScreen` currently duplicates inline twice, factored
  /// into ONE reusable, tested method. Defaults to reloading the CURRENT
  /// package; accepts an explicit [package] for the real "reload with a
  /// newly-evolved package" case (the one every real caller today needs —
  /// the evolved package is not yet reflected in `runtime.currentSession`
  /// at the moment reload is requested).
  Future<ExperienceSession> reload({ExperiencePackage? package}) async {
    final target = package ?? runtime.currentSession?.package;
    if (target == null) {
      throw StateError(
        'ExperienceRuntimeController.reload() has no package to reload — start() must succeed first, or pass one explicitly.',
      );
    }
    await runtime.closeSession();
    final session = await runtime.openExperience(target);
    _reportAndPublish('runtime_reloaded', session);
    return session;
  }

  /// Terminate — closes the runtime. Reports/publishes using the session
  /// captured BEFORE close (`runtime.currentSession` is `null` afterward),
  /// marked `closed` — `AnythingRuntime.closeSession()` itself builds a
  /// closed-status copy internally but only ever exposes it transiently
  /// before nulling `currentSession`, so no external caller could otherwise
  /// observe the real terminal status.
  Future<void> terminate() async {
    final closingSession = runtime.currentSession?.copyWith(
      status: SessionStatus.closed,
    );
    await runtime.closeSession();
    _reportAndPublish('runtime_terminated', closingSession);
  }

  /// Real, honest snapshot: the runtime's own current `ExperienceSession`
  /// — already sufficient to [restore] from. No new snapshot type.
  ExperienceSession? captureSnapshot() => runtime.currentSession;

  /// Restore = re-open from a captured session's real `package` — the
  /// exact same real primitive [start] uses.
  Future<ExperienceSession> restore(ExperienceSession snapshot) =>
      start(snapshot.package);

  void _reportAndPublish(String change, ExperienceSession? session) {
    final id = experienceId ?? session?.experienceId;
    if (id == null) return;
    if (workspace != null && session != null) {
      workspace!.reportRuntimeStateForExperience(id, session);
    }
    if (eventPublisher != null) {
      final sessionId = workspace?.sessionForExperience(id)?.sessionId ?? id;
      eventPublisher!.publishWorkspaceUpdated(change, sessionId);
    }
  }
}
