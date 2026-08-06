# Shared Workspace Runtime Supervision — Implementation Specification IS-R41

## REALITY

Investigated directly (grep + full source reads) before writing any code.

`lib/app/app_composition.dart` (last touched R37) had no `workspaceRuntimeSupervisor` field. `WorkspaceRuntimeSupervisor` (R40, `lib/app/workspace_runtime_supervisor.dart`, unmodified this milestone) had no shared, composition-root-level instance — R40's own "Known Limitations" named this explicitly. `lib/features/home/home_screen.dart` (last touched R37) has exactly 3 real `ExperienceHostScreen(...)` construction call sites (`_openViaCoordinator`, both branches of `_showProtectionInputAndResume`), each already threading `workspaceManager`/`workspaceRuntime`/`eventBus` resolved via the established `widget.X ?? _composition.X` pattern — none threaded a `runtimeSupervisor`.

`lib/app/app_shell.dart` — `AnythingAppShell` constructs `final AppComposition _composition = AppComposition.production();` exactly once and passes ONLY `composition: _composition` to `HomeScreen`. Every other shared service is resolved INSIDE `HomeScreen` from that one object. This means extending `AppComposition` + `HomeScreen`'s own resolution + the 3 call sites is fully sufficient to make the whole app share one supervisor — `app_shell.dart` needed zero changes, confirmed by reading it in full.

`lib/runtime/experience_host_screen.dart`'s `_ExperienceHostScreenState` already had a `runtimeSupervisor` field (R40, for auto-register/unregister of its own controller) and a real `WidgetsBindingObserver`/`didChangeAppLifecycleState(AppLifecycleState state)` (R39) that applied ONLY to this screen's own `_runtimeController`, guarded so it never pauses an already-idle/error runtime or resumes one that was never paused.

`WorkspaceRuntimeSupervisor.applyAppLifecyclePolicy(state, engine)` (R40, unmodified) already computes ONE decision and applies it to EVERY registered controller. `AnythingRuntime.pauseSession()`/`.resumeSession()` (unmodified, R38) are real, idempotent no-ops when a runtime has no current session — confirmed by rereading `anything_runtime.dart` — so applying a decision unconditionally across every registered controller (rather than R39's own per-screen "skip if already in that state" optimization) is safe.

## PROPOSED / RATIONALE

Extend `AppComposition` additively with ONE new field, `workspaceRuntimeSupervisor`, composed right after `eventPublisher` (the same dependency `WorkspaceRuntimeSupervisor`'s own constructor needs) — exactly the same pattern R36/R37 already established for adding new shared services. Thread it through `HomeScreen`'s existing resolution/call-site pattern (identical shape to `workspaceManager`/`workspaceRuntime`/`eventBus`/`pipeline`). For the "ONE real production trigger" requirement, reuse the SAME real `WidgetsBindingObserver` R39 already built inside `ExperienceHostScreen` — never a second observer anywhere else (no new observer in `HomeScreen`/`AnythingAppShell`) — only widen what `didChangeAppLifecycleState` does with the transition it already receives: route through the shared supervisor (workspace-wide reach) when one was injected, otherwise fall back to the exact, unchanged R39 per-screen behavior.

## IMPLEMENTATION

`lib/app/app_composition.dart` — additive field + construction:

```dart
final WorkspaceRuntimeSupervisor workspaceRuntimeSupervisor;
// ...
final workspaceRuntimeSupervisor = WorkspaceRuntimeSupervisor(eventPublisher: eventPublisher);
```

`lib/features/home/home_screen.dart` — one new optional constructor field `runtimeSupervisor` (`null` by default), resolved in `initState()` via `widget.runtimeSupervisor ?? _composition.workspaceRuntimeSupervisor`, threaded into all 3 real `ExperienceHostScreen(...)` call sites as `runtimeSupervisor: _runtimeSupervisor`.

`lib/runtime/experience_host_screen.dart` — `didChangeAppLifecycleState` now branches:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  final supervisor = widget.runtimeSupervisor;
  if (supervisor != null) {
    unawaited(supervisor.applyAppLifecyclePolicy(state, _policyEngine));
    return;
  }
  // Exact, unchanged R39 behavior when no supervisor was injected.
  final decision = _policyEngine.evaluateAppLifecycle(state);
  if (decision.action == RuntimePolicyAction.pause && _runtime.status != RuntimeStatus.running) return;
  if (decision.action == RuntimePolicyAction.resume && _runtime.status != RuntimeStatus.paused) return;
  unawaited(_policyEngine.apply(decision, _runtimeController));
}
```

No new field was added to `ExperienceHostScreen` this milestone — `runtimeSupervisor` already existed from R40; R41 only changes what its presence causes `didChangeAppLifecycleState` to do.

## SHARED RUNTIME SUPERVISION

Every `ExperienceHostScreen` the real app opens now receives the SAME `WorkspaceRuntimeSupervisor` instance, reached transitively from the ONE `AppComposition` `AnythingAppShell` constructs. Two (or more) simultaneously-mounted screens — e.g. a user opens Experience A, then opens Experience B while A is still in the `Navigator` stack below — both register their own, independent `ExperienceRuntimeController` with the SAME registry.

## PRODUCTION ACTIVATION

The automatic trigger is real and already-existing: Flutter delivers `didChangeAppLifecycleState` to every currently-registered `WidgetsBindingObserver` in the app (every mounted `ExperienceHostScreen`) on a genuine OS-level transition. Before this milestone, each screen's own callback only reached its own runtime. Now, when a shared supervisor is present, ANY one of those callbacks resolves and pauses/resumes EVERY registered runtime — so even a single currently-visible screen's own OS-delivered callback is sufficient to correctly pause the whole workspace. No polling, no timer, no new background service — the trigger is the exact same real, existing Flutter lifecycle mechanism R39 already wired in.

## WORKSPACE-WIDE POLICIES

`applyAppLifecyclePolicy()` is now reachable from real production usage for the first time. `applyInactiveRuntimePolicy()` (R40) still has no automatic production trigger this milestone — R41's own "AUTOMATIC TRIGGER" requirement is scoped explicitly to application background/foreground transitions, not the Inactive Runtime policy; see Known Limitations.

## TEST RESULTS

`test/r41_shared_runtime_supervision_test.dart` (new) proves: shared supervisor construction (`AppComposition.production().workspaceRuntimeSupervisor` is real and non-null; two reads return the identical instance, matching R36's own singleton proof); multiple screens sharing one supervisor (two real, independently-started, simultaneously-mounted `ExperienceHostScreen`s given the same injected supervisor both register, each under its own distinct sessionId, with distinct controllers); workspace-wide pause/resume (the load-bearing proof — ONE real `AppLifecycleState` transition delivered to the observer tree pauses BOTH real runtimes through the shared supervisor, then resumes both); controller registration integrity (no cross-contamination between two screens' records); regression (`WorkspaceRuntimeSupervisor`/`WorkspaceLifecyclePolicyEngine`/`UniversalIntentRouter` used directly, bypassing the shared composition, behave exactly as R40/R39/R33 built them); backward compatibility (`HomeScreen()`/`ExperienceHostScreen()` without the new/existing field default to `null`; a real, live screen with NO supervisor injected still pauses/resumes only its own runtime — exact prior R39 behavior); real `Stopwatch`/`ProcessInfo.currentRss` performance measurements.

## PERFORMANCE

Real, measured (see the test file's own "Performance" group): `AppComposition.production()` construction (now with the additional supervisor field) stays in the same low-millisecond range as R37-R40's own measurements; `supervisor.lookup()` through the shared-instance path is the same O(1) `Map` lookup R40 already measured; workspace-wide pause+resume across 20 synthetic registered controllers completes in low milliseconds; no measurable RSS growth across repeated `AppComposition.production()` construct/close cycles.

## KNOWN LIMITATIONS

- **Inactive Runtime policy still has no automatic production trigger** — `applyInactiveRuntimePolicy()` remains real, tested, and callable, but nothing calls it automatically from production this milestone (R41's own "AUTOMATIC TRIGGER" scope is app-lifecycle only). A real candidate for R42: a periodic or event-driven trigger (e.g. on workspace session switch) that calls it — must stay consistent with this codebase's established no-polling discipline.
- **No `Workspace Close` trigger** — unchanged from R39/R40's own honest disclosure; `ExperienceWorkspaceManager.closeExperience()` still has no real production caller.
- **`removeDisposed()` still has no automatic sweep** — unchanged from R40, caller-invoked only.

## RECOMMENDATION FOR R42

Wire a real, event-driven trigger for `applyInactiveRuntimePolicy()` — e.g., have `ExperienceWorkspaceManager.switchActiveExperience()`'s real callers (once `UniversalIntentRouter`'s `resumeBackgroundSession`/`modifyActiveExperience` paths gain a live UI caller) also call `supervisor.applyInactiveRuntimePolicy(workspaceRuntime.captureRuntimeState(), policyEngine)` — completing workspace-wide reach for BOTH policies this arc has built, not just app-lifecycle.
