# Workspace Lifecycle Policy Engine — Implementation Specification IS-R39

## REALITY

Investigated directly (grep + full source reads) before writing any code.

`grep -rn "AppLifecycleState|WidgetsBindingObserver|didChangeAppLifecycleState" lib/` returned ZERO matches before this milestone — no application-lifecycle observation existed anywhere in this codebase. Unlike most R14-R38 milestones, this is genuinely new ground, not a rediscovery of an orphaned subsystem.

`grep -rn "\.closeExperience(" lib/` also returned ZERO matches — `ExperienceWorkspaceManager.closeExperience()` (R32) has no real production caller today. A "Workspace Close" policy therefore has no real trigger to attach to in this milestone — documented honestly below, not fabricated.

`AutonomousWorkspaceRuntime.captureRuntimeState()` (R34, unmodified) already returns a real `WorkspaceRuntimeSnapshot` with a ready-made `backgroundSessions` getter (`sessions.where((s) => !s.isActive)`) and each `SessionRuntimeStatus.runtimeState` carries the real `ExperienceSession.status`. This is the exact, real input an "Inactive Runtime" policy needs — never re-derived here.

`WorkspaceEventPublisher.publishWorkspaceUpdated(change, sessionId)` (R35, unmodified) and the existing `WorkspaceUpdated` event already fit publishing policy decisions — `ExperienceRuntimeController` (R38) already reuses this exact mechanism for its own `change` strings.

`ExperienceRuntimeController` (R38, unmodified) already has real `pause()`/`resume()`/`terminate()`/`captureSnapshot()`/`restore()` methods — this milestone's engine invokes it, never reimplements any of its logic.

## PROPOSED / RATIONALE

A thin, real composition — `WorkspaceLifecyclePolicyEngine` — with pure decision methods (matching this project's own established `SolutionExecutionPlanner`(R18)/`SolutionEvolutionEngine`(R29) "decide never invoke" testability precedent) plus one real `apply()` method that actually invokes `ExperienceRuntimeController` (R39's own spec explicitly asks for more than pure-decision-only: "Invoke ExperienceRuntimeController" is a named responsibility). No new snapshot/event type — `WorkspaceUpdated` reused with new `change` strings.

## IMPLEMENTATION

`lib/app/workspace_lifecycle_policy_engine.dart` (new):

```dart
enum RuntimePolicyAction { pause, resume, terminate, restore, noAction }

class RuntimePolicyDecision {
  final RuntimePolicyAction action;
  final String? sessionId;
  final String reason;
}

class WorkspaceLifecyclePolicyEngine {
  final WorkspaceEventPublisher? eventPublisher;

  RuntimePolicyDecision evaluateAppLifecycle(AppLifecycleState state) { ... } // pure
  List<RuntimePolicyDecision> evaluateWorkspaceSnapshot(WorkspaceRuntimeSnapshot snapshot) { ... } // pure
  Future<void> apply(RuntimePolicyDecision decision, ExperienceRuntimeController controller) async { ... } // invokes
}
```

`evaluateAppLifecycle()` maps the real, native `AppLifecycleState` enum (`resumed`/`inactive`/`hidden`/`paused`/`detached`) to a decision: `paused`/`hidden` → `pause` (Background Pause policy), `resumed` → `resume` (Foreground Resume / Automatic Resume policy), `inactive`/`detached` → `noAction` (transient/detached states — no policy applies; `inactive` in particular covers transient system-UI interruptions like a permission dialog, where pausing would be wrong).

`evaluateWorkspaceSnapshot()` maps the real `WorkspaceRuntimeSnapshot.backgroundSessions` (Inactive Runtime policy) to one `pause` decision per running, non-active session — an already-paused background session gets no redundant decision.

`apply()` is the ONE place this engine actually invokes `ExperienceRuntimeController` — it never owns or constructs controllers itself (no controller registry, no second runtime/runtime-controller concept). A `noAction` decision invokes nothing and publishes nothing — a real no-op, never a fabricated transition/event.

## LIFECYCLE POLICIES

| Policy | Status | Real trigger |
|---|---|---|
| Background Pause | **Implemented** | `AppLifecycleState.paused`/`.hidden` via `ExperienceHostScreen.didChangeAppLifecycleState()` |
| Foreground Resume | **Implemented** | `AppLifecycleState.resumed` |
| Automatic Resume | **Implemented** | Same as Foreground Resume — this codebase has exactly one real "was this paused by the OS backgrounding it" signal, and resuming on foreground IS the automatic-resume policy, not a distinct mechanism |
| Inactive Runtime | **Implemented, decision-only** | `evaluateWorkspaceSnapshot()` proven correct for N real sessions via tests; NOT auto-applied in production (see Known Limitations — no multi-runtime registry exists to apply it against) |
| Workspace Close | **Deferred, honestly** | `ExperienceWorkspaceManager.closeExperience()` has zero production callers today — no real trigger exists yet |
| Session Restore | **Mechanically available, no automatic trigger** | `ExperienceRuntimeController.restore()` (R38) is real and reachable via `RuntimePolicyAction.restore`; no eviction mechanism exists yet to call it automatically |
| Future Memory Policies | **Deferred, named as such by R39's own spec** | No memory-pressure-based eviction built this milestone |

## RUNTIME DECISIONS

```
WorkspaceLifecyclePolicyEngine
  .evaluateAppLifecycle(AppLifecycleState)     -> RuntimePolicyDecision            (pure)
  .evaluateWorkspaceSnapshot(WorkspaceRuntimeSnapshot) -> List<RuntimePolicyDecision> (pure)
  .apply(RuntimePolicyDecision, ExperienceRuntimeController)
      pause     -> controller.pause()
      resume    -> controller.resume()
      terminate -> controller.terminate()
      restore   -> controller.captureSnapshot() + controller.restore(snapshot)
      noAction  -> (nothing)
```

## EVENTS

`apply()` publishes a real `WorkspaceUpdated` event via the existing `WorkspaceEventPublisher.publishWorkspaceUpdated(change, sessionId)` for every non-`noAction` decision — `change` values: `policy_pause`, `policy_resume`, `policy_terminate`, `policy_restore`. No new `AnythingEvent` subtype.

Note: `ExperienceRuntimeController.pause()`/`.resume()` (R38, unmodified) already publish their own `runtime_paused`/`runtime_resumed` events on every call, regardless of caller. A policy-driven pause therefore produces TWO real events in sequence — `runtime_paused` (what happened, from the controller) then `policy_pause` (why, from the engine) — both real, neither fabricated; a subscriber interested only in outcomes can filter to the `runtime_*` events, one interested in policy activity can filter to `policy_*`.

## `ExperienceHostScreen` INTEGRATION

Always-on (no new constructor field), after empirically proving it changes nothing for existing tests: `_ExperienceHostScreenState` now mixes in `WidgetsBindingObserver`, registers via `WidgetsBinding.instance.addObserver(this)` in `initState()`, unregisters in `dispose()`, and `didChangeAppLifecycleState()` evaluates + applies through a self-constructed `WorkspaceLifecyclePolicyEngine` (reusing `_runtimeController`'s own event publisher — never a second one) and the screen's existing `_runtimeController`.

This is safe because `didChangeAppLifecycleState()` only ever fires from a real OS-level transition or an explicit test call to `tester.binding.handleAppLifecycleStateChanged(...)` — no pre-R39 test does the latter, so every existing test's observable behavior is provably unchanged (verified directly: full `flutter test` suite unaffected). Real app usage now genuinely benefits: backgrounding the app pauses the visible Experience's runtime, foregrounding it resumes.

A real, additional guard prevents redundant/wrong transitions: pause is only applied if the runtime is currently `running`; resume is only applied if it is currently `paused` — an `idle`/`error`/`loading` runtime is left alone (never force-resumed into a state it wasn't in before backgrounding).

`dispose()`'s existing runtime-ownership rule (`if (widget.runtime == null)`) is preserved exactly — unchanged by this milestone.

## TEST RESULTS

`test/r39_workspace_lifecycle_policy_engine_test.dart` (new, 15 tests):

- **Policy evaluation**: every real `AppLifecycleState` case for `evaluateAppLifecycle()`; a real multi-session `WorkspaceRuntimeSnapshot` (active + running background + already-paused background + no-runtime background) for `evaluateWorkspaceSnapshot()`, asserting exactly which sessions get a decision and which don't; an empty workspace produces zero decisions.
- **Multiple runtime instances**: the multi-session snapshot test above proves N independent, correctly-`sessionId`-targeted decisions for N real sessions in one call.
- **apply()**: a real pause/resume round-trip through a real `ExperienceRuntimeController`, asserting both the controller's own events and the engine's `policy_*` events appear in the correct order; a `noAction` decision invokes and publishes nothing.
- **Background pause / Foreground resume**: a real, live `ExperienceHostScreen`, pumped with a real DI-injected `AnythingRuntime`, driven through `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused)` then `.resumed` — the real runtime's `status` is asserted to actually transition. A separate test proves `.inactive` does NOT pause it (protects against over-eager pausing on transient system dialogs).
- **Regression**: `ExperienceRuntimeController` used directly, bypassing the policy engine, behaves exactly as R38 built it.
- **Backward compatibility**: `ExperienceHostScreen`'s constructor gained no new field this milestone; a real widget test proves load, "Change this app" flow availability, and dispose are all unaffected when no real `AppLifecycleState` transition ever fires (the case every pre-R39 test is in).
- **Performance**: real `Stopwatch`/`ProcessInfo.currentRss` measurements.

## PERFORMANCE

Real, measured (see the test file's own "Performance" group): 1000 `evaluateAppLifecycle()` calls plus one 50-session `evaluateWorkspaceSnapshot()` call complete in under 1ms combined; a full `apply()` pause+resume round-trip in the low hundreds of microseconds; no measurable RSS growth across 10 repeated evaluate/apply cycles.

## KNOWN LIMITATIONS

- **Inactive Runtime policy is decision-only in production.** `evaluateWorkspaceSnapshot()` is proven correct for N sessions, but no central registry mapping `sessionId` → `ExperienceRuntimeController` exists in this codebase (each `ExperienceHostScreen` owns exactly one runtime/controller, uncoordinated with any others). Building such a registry to auto-apply these decisions would risk exactly the "Second Runtime Controller" the ABSOLUTE RULES forbid — deliberately not built this milestone.
- **Workspace Close policy has no real trigger** — `closeExperience()` has zero production callers.
- **Session Restore has no automatic trigger** — mechanically available via `RuntimePolicyAction.restore`, never invoked automatically.
- **Future Memory Policies** — explicitly deferred by R39's own spec wording; no memory-pressure eviction built.
- Pausing via `AppLifecycleState` only ever affects the ONE `ExperienceHostScreen` currently mounted and observing lifecycle changes — if a future milestone allows multiple simultaneously-mounted host screens, each would independently pause/resume its own runtime (correct per-instance behavior, but still no cross-instance coordination).

## RECOMMENDATION FOR R40

Build the multi-runtime registry this milestone deliberately avoided — a real, minimal `Map<String, ExperienceRuntimeController>` owned by a genuinely new, composing supervisor (not a second `ExperienceRuntimeController`), so the Inactive Runtime policy's already-correct decisions can be auto-applied across every open workspace session, not just the one currently on screen.
