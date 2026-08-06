# Workspace Scheduling Engine — Implementation Specification IS-R42

## REALITY

Before R42, `WorkspaceRuntimeSupervisor.applyInactiveRuntimePolicy()`/`.resume()` (R40, unmodified) had **zero callers anywhere in `lib/`** (confirmed by grep) — R40's and R41's own doc comments both explicitly, honestly deferred wiring a real trigger for either. "Which session is active" has always been `ExperienceWorkspaceManager`'s own, unmodified responsibility (`activeSessionId`/`switchActiveExperience()`, R32) — nothing coordinated that structural decision with the real, registered runtime controllers in `WorkspaceRuntimeSupervisor`.

`AutonomousWorkspaceRuntime.captureRuntimeState()` (R34, unmodified) already exposes `.activeSession`/`.backgroundSessions` — the ready-made, real data source for "Determine foreground experience"/"Determine background experiences." `WorkspaceLifecyclePolicyEngine.evaluateWorkspaceSnapshot()` (R39, unmodified) already produces the real Inactive Runtime pause decisions. `WorkspaceEventPublisher.publishWorkspaceUpdated()` (R35, unmodified) already fits publishing a scheduler transition.

`ExperienceOpeningCoordinator` (the trusted "Recent"/birth-completion opening flow) never touches `ExperienceWorkspaceManager` at all — an Experience opened this way registers no workspace session, so scheduling cannot reach it. Pre-existing, not this milestone's to fix.

No `RouteObserver`/`RouteAware` machinery exists anywhere in this codebase (confirmed by grep) — introducing one would be new, real app-shell-level surface area beyond this milestone's honest scope.

## PROPOSED / RATIONALE

`WorkspaceSchedulingEngine` composes the three already-real pieces (`AutonomousWorkspaceRuntime`, `WorkspaceRuntimeSupervisor`, `WorkspaceLifecyclePolicyEngine`) into the first real caller of `applyInactiveRuntimePolicy()`/`supervisor.resume()`, without reimplementing any of their decision logic. "Which session is active" stays `ExperienceWorkspaceManager`'s own responsibility — the engine only reads that real state and makes the real, registered runtimes match it. It never touches `AnythingRuntime` directly, matching this specification's own "Never directly control AnythingRuntime" rule.

## IMPLEMENTATION

`lib/app/workspace_scheduling_engine.dart` (new) — `WorkspaceSchedulingEngine`:

- `foregroundExperience()` / `backgroundExperiences()` — pure reads of a fresh `AutonomousWorkspaceRuntime.captureRuntimeState()` snapshot. Never mutate anything.
- `scheduleActiveTransition()` — resumes the real, registered controller for the snapshot's current active session (via `supervisor.resume()`), then calls the unmodified `supervisor.applyInactiveRuntimePolicy(snapshot, policyEngine)` to pause every other real, registered, running background runtime. Publishes one real `scheduler_active_transition` `WorkspaceUpdated` event when an `eventPublisher` is supplied.
- `scheduleForeground(sessionId)` — calls the real, unmodified `ExperienceWorkspaceManager.switchActiveExperience(sessionId)`, then delegates to `scheduleActiveTransition()`. Throws a real `StateError` if constructed without a `workspace`.

No new event type, no new snapshot type, no controller registry duplication — every real mutation goes through `WorkspaceRuntimeSupervisor`.

## WORKSPACE SCHEDULING / FOREGROUND MODEL / BACKGROUND MODEL

Foreground = `WorkspaceRuntimeSnapshot.activeSession` (R34, unmodified). Background = `WorkspaceRuntimeSnapshot.backgroundSessions` (every open-but-not-active session). Both read fresh on every call — never cached, never re-derived independently of `ExperienceWorkspaceManager`'s own real state.

**"Preloaded"**: named in this specification's own architectural-objective prose but not listed among its concrete RESPONSIBILITIES, and no real mechanism for a "warm but not fully opened" runtime exists anywhere in `AnythingRuntime`/`ExperienceRuntimeController` (`start()` always fully opens a package — there is no partial/warm-start primitive). Not implemented this milestone — see KNOWN LIMITATIONS, matching R39's own "Future Memory Policies" precedent for spec language that outruns real, buildable capability.

## `ExperienceHostScreen` INTEGRATION

One new, optional, additive constructor field `scheduler` (`null` by default — zero behavior change when omitted, matching every prior R32-R41 optional field). When supplied, `_loadExperience()` calls `widget.scheduler?.scheduleActiveTransition()` once the runtime has genuinely started, alongside the screen's existing `_reportRuntimeStateToWorkspace()`/`_publishRuntimeLoadedEvent()`/`_registerWithSupervisor()` calls.

This is scoped honestly to "this screen just finished loading" — a real, honest proxy for "gained focus," **not** a full route-aware "regained focus after a `Navigator` pop returned to it." No `RouteObserver` was introduced.

## TEST RESULTS

`test/r42_workspace_scheduling_engine_test.dart` — 15 tests, all real objects (never mocks of the subsystem under test):

- **Foreground selection**: `foregroundExperience()` returns the real active session; `null` when nothing is open.
- **Background selection**: `backgroundExperiences()` returns exactly the real, open-but-not-active sessions.
- **Runtime switching**: `scheduleForeground(sessionId)` reaches the real `switchActiveExperience()`, resumes the new active runtime, pauses the other real, registered, running background runtime.
- **Workspace scheduling**: `scheduleActiveTransition()` reflects the workspace's CURRENT real active session, including correctly after a real `closeExperience()` fallback; a real `scheduler_active_transition` event is published; `scheduleForeground()` without a `workspace` throws a real `StateError`.
- **Regression**: `WorkspaceRuntimeSupervisor.applyInactiveRuntimePolicy()`/`ExperienceWorkspaceManager.switchActiveExperience()` called directly, bypassing the scheduler entirely, behave exactly as R40/R32 built them.
- **Backward compatibility**: `ExperienceHostScreen` constructed without `scheduler` defaults it to `null`, real widget test proves load/dispose unaffected; a second real widget test proves a real, injected scheduler genuinely pauses a real sibling background runtime once the active screen loads.
- **Performance**: real `Stopwatch`/`ProcessInfo.currentRss` measurements (below).

`flutter analyze`: 71/0, unchanged baseline. `flutter test`: full suite passes, zero regressions (see `Anything_R42_Validation_Report.txt` for the exact counts).

## BUG FOUND AND FIXED DURING IMPLEMENTATION

Three real, self-caught bugs, fixed before the final commits:

1. The new test file's `_Rig.create()` used `SqliteExperienceRepository`/`EngineeringMemoryRepository`/`ActivityRepository` without importing their defining libraries — a real compile error. First surfaced as fluctuating, higher-than-baseline `flutter analyze` issue counts (75/77 instead of the established 71) across two runs; root-caused by grepping the analyzer output for the new file names directly rather than assuming environmental drift. Fixed with the three missing imports; `flutter analyze` returned to a stable 71/0 immediately after.
2. The initial `_Rig.openAndRegister()` constructed `ExperienceRuntimeController(runtime: AnythingRuntime())` without `workspace:`/`experienceId:` — so it never reported the real runtime session into `SessionState.currentRuntimeState`, the field `WorkspaceLifecyclePolicyEngine.evaluateWorkspaceSnapshot()` actually reads. Every background session in the fixture therefore looked "not running" to the policy engine, and no pause decisions were ever produced — 4 real test failures. Fixed by passing `workspace`/`experienceId` through, matching how `ExperienceHostScreen`'s own real controller construction already does it.
3. A widget test's initial open order had the "background" experience opened first — but `ExperienceWorkspaceManager.openExperience()`'s real `_activeSessionId ??= result.sessionId` makes the FIRST-opened session active, not the second, so the fixture's own "active" and "background" sessions were swapped. Fixed by reordering the two `openExperience()` calls to match the real semantics.

## PERFORMANCE

Real, measured (see the test file's own "Performance" group): `foregroundExperience()`+`backgroundExperiences()` complete in the low hundreds of microseconds; `scheduleForeground()` (a real workspace switch plus a full Inactive Runtime policy pass) completes in under a millisecond; `scheduleActiveTransition()` across 10 real sessions completes in well under a millisecond; no measurable RSS growth across 10 repeated `scheduleForeground()` cycles.

## KNOWN LIMITATIONS

- **"Preloaded" runtime state** — named in the spec's prose, not implemented; no real warm-start mechanism exists in `AnythingRuntime` to build it honestly this milestone.
- **`ExperienceOpeningCoordinator`'s opening path still never registers a workspace session** — scheduling cannot reach an Experience opened via "Recent"/birth-completion. Pre-existing, not this milestone's to fix.
- **"Notify scheduler of focus changes" is scoped to "screen finished loading," not full route-aware focus-regain** — no `RouteObserver` exists in this codebase; introducing one is real, new app-shell surface area beyond this milestone's safe reach.
- **No shared, composition-root-level `WorkspaceSchedulingEngine` instance** — `AppComposition` is untouched this milestone. Unlike R41 (which had an explicit "construct ONE shared supervisor inside `AppComposition`" primary objective), R42's own spec does not mandate composition-root wiring. Doing so safely would also require giving `WorkspaceLifecyclePolicyEngine` its own first shared composition-root instance — today every `ExperienceHostScreen` still self-constructs its own `_policyEngine` per screen — a second, adjacent decision (how per-screen-local and shared policy-engine instances should coexist) better made deliberately in a dedicated follow-up rather than folded silently into this milestone.
- **`scheduleForeground()`/`scheduleActiveTransition()` are not automatically triggered from any real UI action** (e.g. tapping a background session in a future "open apps" switcher) — they are real, tested, callable, but nothing calls `scheduleForeground()` from production yet. `_loadExperience()`'s own `scheduleActiveTransition()` call is the one real, automatic trigger this milestone wires in.

## RECOMMENDATION FOR R43

Give `WorkspaceLifecyclePolicyEngine` a first shared, composition-root instance and add a shared `WorkspaceSchedulingEngine` to `AppComposition`, threaded through `HomeScreen`'s real navigation call sites the same way R41 did for `workspaceRuntimeSupervisor` — then wire a real UI entry point (e.g. a background-sessions list/switcher) that calls `scheduleForeground(sessionId)` when the user picks a different open Experience, giving this milestone's scheduling decisions their first real, user-driven trigger beyond "the currently-loading screen."
