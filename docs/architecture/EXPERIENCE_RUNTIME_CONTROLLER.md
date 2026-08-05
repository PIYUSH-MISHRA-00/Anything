# Experience Runtime Controller — Implementation Specification IS-R38

## REALITY

Investigated directly (grep + full source reads) before writing any code.

`AnythingRuntime` (`lib/runtime/anything_runtime.dart`) already has a real, tested lifecycle API: `openExperience()` (start), `pauseSession()`/`resumeSession()`, `closeSession()` (terminate), `status`/`currentSession`. `AnythingRuntime` is constructed in exactly ONE place in the whole production app — `ExperienceHostScreen.initState()`: `_runtime = widget.runtime ?? AnythingRuntime(capabilityPlatform: widget.capabilityPlatform)`.

Three real, honest gaps, all confirmed by direct source reading:

1. **Dead pause/resume**: `grep -rn "\.pauseSession()\|\.resumeSession()" lib/` returns zero hits outside `anything_runtime.dart` itself. Real, tested, zero production callers — the same "orphaned subsystem" pattern R14/R16/R30/R35 each found and wired in.
2. **Duplicated reload**: `ExperienceHostScreen` repeats the exact `await _runtime.closeSession(); await _runtime.openExperience(_currentPackage);` pair, verbatim, in two places — `_runModification()`'s success branch and `_performRollback()`. Neither call site reported the reload to the workspace or published any event — the reload path has always been invisible to `ExperienceWorkspaceManager`/`EventBus`.
3. **Synthetic runtime-state report**: `ExperienceHostScreen._reportRuntimeStateToWorkspace()` never forwards the runtime's own real `AnythingRuntime.currentSession` — it hand-builds a separate `ExperienceSession` with a fabricated `id: 'runtime-$experienceId'`. `AutonomousWorkspaceRuntime.captureRuntimeState()` (R34) has therefore always read this synthetic stand-in, never the live runtime.

`ExperienceSession` (`lib/runtime/experience_session.dart`) already carries `package`/`status`/`startedAt`/`lastActiveAt`/`error` — everything needed to restore a runtime. `WorkspaceEventPublisher.publishWorkspaceUpdated(change, sessionId)` (R35, unmodified) and the existing `WorkspaceUpdated` event already fit lifecycle transitions — `ExperienceHostScreen` already uses this exact mechanism for `change: 'runtime_loaded'`.

## PROPOSED / RATIONALE

A thin, real composition — `ExperienceRuntimeController` — over `AnythingRuntime` (unmodified), `ExperienceWorkspaceManager` (R32, unmodified), and `WorkspaceEventPublisher` (R35, unmodified). No new snapshot type (`ExperienceSession` is already sufficient — restore means re-opening from its `package`, the same primitive `start()`/`reload()` use). No new event subtype (`WorkspaceUpdated` + `publishWorkspaceUpdated()` reused for every transition). No new runtime.

## IMPLEMENTATION

`lib/runtime/experience_runtime_controller.dart` (new):

```dart
class ExperienceRuntimeController {
  final AnythingRuntime runtime;
  final ExperienceWorkspaceManager? workspace;
  final WorkspaceEventPublisher? eventPublisher;
  final String? experienceId;

  RuntimeStatus get status => runtime.status;
  ExperienceSession? get currentSession => runtime.currentSession;

  Future<ExperienceSession> start(ExperiencePackage package) async { ... }
  void pause() { runtime.pauseSession(); _reportAndPublish('runtime_paused', ...); }
  void resume() { runtime.resumeSession(); _reportAndPublish('runtime_resumed', ...); }
  Future<ExperienceSession> reload({ExperiencePackage? package}) async { ... } // closeSession()+openExperience() pair
  Future<void> terminate() async { ... }
  ExperienceSession? captureSnapshot() => runtime.currentSession;
  Future<ExperienceSession> restore(ExperienceSession snapshot) => start(snapshot.package);
}
```

`reload()` defaults to the runtime's current package but accepts an explicit one — required for the real `ExperienceHostScreen` case, where the newly-evolved package is already assigned to local screen state (`_currentPackage`) before reload is requested, while `runtime.currentSession.package` still holds the OLD one.

`terminate()` captures the closing session BEFORE `closeSession()` nulls it, and marks it `SessionStatus.closed` via `copyWith()` — `AnythingRuntime.closeSession()` builds a closed-status copy internally but only ever exposes it transiently before nulling `currentSession`, so no external caller could otherwise observe the real terminal status. This was found and fixed via this milestone's own test (`terminate()` initially reported the pre-close, still-`running` session — a real bug caught by asserting the workspace's post-terminate report, not a spec-mandated speculative fix).

## RUNTIME LIFECYCLE

```
ExperienceRuntimeController
  .start(package)    -> AnythingRuntime.openExperience(package)                 (unchanged)
  .pause()           -> AnythingRuntime.pauseSession()                          (unchanged, previously dead)
  .resume()          -> AnythingRuntime.resumeSession()                         (unchanged, previously dead)
  .reload(package?)  -> AnythingRuntime.closeSession() + .openExperience(...)   (the exact pair ExperienceHostScreen duplicated)
  .terminate()       -> AnythingRuntime.closeSession()                          (unchanged)
  .captureSnapshot() -> AnythingRuntime.currentSession                          (real, no new type)
  .restore(snapshot) -> .start(snapshot.package)                                (same primitive as start())
```

Every method delegates to the SAME, single, unmodified `AnythingRuntime` instance passed at construction — never a second runtime.

## STATE TRANSITIONS

`RuntimeStatus`: `idle -> loading -> running <-> paused`, `running/paused -> idle` (via `terminate()`/`reload()`, which briefly returns to `idle` internally before `loading -> running` again). `SessionStatus` on `currentSession`: `running <-> paused`, `running -> closed` (terminate). Unchanged — `ExperienceRuntimeController` observes and drives these via the existing, real `AnythingRuntime` API, never a parallel state machine.

## EVENTS

Every transition publishes a real `WorkspaceUpdated` event via `WorkspaceEventPublisher.publishWorkspaceUpdated(change, sessionId)` — `change` values: `runtime_started`, `runtime_paused`, `runtime_resumed`, `runtime_reloaded`, `runtime_terminated`. No new `AnythingEvent` subtype — `WorkspaceUpdated` already exists and `ExperienceHostScreen` already publishes it (`change: 'runtime_loaded'`) for the initial load. `experienceId` is captured explicitly at construction (not derived from `runtime.currentSession`, which is `null` both before `start()` and after `terminate()`) so `terminate()` can still report/publish its own closing transition.

## `ExperienceHostScreen` INTEGRATION

Full (tier-2) integration, judged safe after reading the real code:

- One new optional, additive constructor field `runtimeController` (`null` by default) — matches the established `runtime`/`workspaceManager`/`workspaceRuntime`/`eventBus` DI pattern exactly. `ExperienceHostScreen`'s own public constructor is otherwise unchanged.
- When omitted, `initState()` builds one internally, wrapping the screen's own `_runtime` plus `widget.workspaceManager`/`widget.eventBus`/`widget.experienceId`.
- `_runModification()`'s and `_performRollback()`'s reload sequences now call `_runtimeController.reload(package: _currentPackage)` — the explicit package is REQUIRED here (see Implementation above); each call site's own router re-seeding (`_reseedAfterReload`/`_seedDefaultScreen`) is completely untouched, staying UI-level.
- `dispose()`'s owned-runtime close now calls `_runtimeController.terminate()` — the exact same `widget.runtime == null` ownership guard is preserved unchanged; an injected runtime is never closed by this screen.
- **Deliberately NOT changed**: the INITIAL load in `_loadExperience()` keeps its existing `_reportRuntimeStateToWorkspace()`/`_publishRuntimeLoadedEvent()` calls untouched. Routing the initial load through the controller too would change the published event's `change` string from `'runtime_loaded'` to `'runtime_started'` — `test/r35_workspace_event_bus_test.dart` asserts on the literal `'runtime_loaded'` string, and there is no behavioral gain from changing it (the initial load already reports/publishes correctly; only reload and terminate had the real gap this milestone closes).

**Real, additive behavior change** (not just a refactor): reload and terminate now report the real runtime session to the workspace and publish a real event — neither ever happened before this milestone. Observable UI behavior (snackbars, router state, undo availability) is unchanged, proven by a real widget test exercising the existing "Change this app" flow with no controller injected.

## TEST RESULTS

`test/r38_experience_runtime_controller_test.dart` (new, 15 tests) — real objects throughout, never mocks of `AnythingRuntime`/`ExperienceWorkspaceManager`:

- **Runtime startup**: `start()` reaches `openExperience()`, returns a real running session.
- **Pause/Resume**: previously-dead methods now reachable and correctly transition both `runtime.status` and `currentSession.status`.
- **Reload**: default (current package) and explicit-package cases both proven; a real close+reopen proven via `ExperienceRouter` instance identity change (`openExperience()` always constructs a fresh router) — not a no-op. A `reload()` with nothing to reload throws a real `StateError`.
- **Termination**: `runtime.status` becomes `idle`, `currentSession` becomes `null`.
- **Snapshot/Restore**: a real round-trip — `captureSnapshot()` on one runtime, `restore()` on a completely FRESH runtime/controller, same package/version confirmed on the other side.
- **Workspace/event integration**: every transition (`start`/`pause`/`resume`/`reload`/`terminate`) proven to report the REAL `currentSession` object (`same()` identity, not just equality) via `workspace.reportRuntimeStateForExperience` — including the closed-status fix for `terminate()`; every transition proven to publish the correct `WorkspaceUpdated.change` string to a real `EventBus` subscriber.
- **Regression**: `AnythingRuntime`'s own methods called directly, bypassing the controller, behave exactly as before.
- **Backward compatibility**: `ExperienceHostScreen()` without `runtimeController` still defaults it to `null`; a real widget test proves the existing reload path still works correctly with no controller injected (the default, most common path).
- **Performance**: real `Stopwatch`/`ProcessInfo.currentRss` measurements.

## PERFORMANCE

Real, measured (see the test file's own "Performance" group): full `start`→`pause`→`resume`→`reload`→`terminate` lifecycle well under 1ms; `captureSnapshot()` low-microsecond (a plain field read); no measurable RSS growth across 10 repeated `start`/`terminate` cycles.

## KNOWN LIMITATIONS

- The initial load in `ExperienceHostScreen._loadExperience()` is NOT routed through the controller (see rationale above) — its existing report/publish calls remain separate, untouched code, not unified under the controller. A future milestone could rename the initial-load `change` string to align, but that would require updating `test/r35_workspace_event_bus_test.dart`'s own assertion, out of this milestone's honest scope.
- `pause()`/`resume()` still have no live UI caller — proven correct and reachable (this milestone's own tests), matching the "decide never invoke, tests are the caller" precedent this project has used since R29/R33 for unwired paths.
- `restore()` reconstructs a running session from a snapshot's `package` — it does NOT restore in-flight `stateEngine`/`dataRuntime` values (Flutter widget-tree state, in-progress form input, etc.), the same honest scope R7 already documented for `ExperienceHostScreen`'s own reload-based Undo feature.

## RECOMMENDATION FOR R39

Give `pause()`/`resume()` a real live UI caller — e.g., pausing a background workspace session's runtime when the user navigates away from `ExperienceHostScreen` without closing it, and resuming when they return — the natural next step now that both methods are proven correct and composed correctly with workspace/event reporting.
