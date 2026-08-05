# Workspace Runtime Supervisor — Implementation Specification IS-R40

## REALITY

Investigated directly (grep + full source reads) before writing any code.

`grep -rn "Map<String, ExperienceRuntimeController>|WorkspaceRuntimeSupervisor|_controllers" lib/` returned zero real hits — the only `_controllers` match is an unrelated `Map<String, StreamController>` inside `lib/runtime/state_engine.dart`. There is no registry mapping sessionId/experienceId to `ExperienceRuntimeController` anywhere in this codebase today. `ExperienceHostScreen._ExperienceHostScreenState.initState()` self-constructs exactly ONE `ExperienceRuntimeController` per screen instance, with zero shared bookkeeping across screens — exactly the gap R38's and R39's own doc comments both named and deliberately deferred ("this milestone does NOT build a controller registry — that would risk a second runtime controller").

`ExperienceRuntimeController` (R38, unmodified) has no `sessionId` field — only a nullable `experienceId`, plus `runtime`/`workspace`/`eventPublisher`. The supervisor's own registration record therefore carries `sessionId` explicitly, supplied by the caller. `ExperienceHostScreen._publishRuntimeLoadedEvent()` already resolves a real `sessionId` for its `experienceId` via `widget.workspaceManager?.sessionForExperience(experienceId)?.sessionId` — this milestone reuses that exact resolution, never inventing a new one.

`WorkspaceLifecyclePolicyEngine.apply(decision, controller)` (R39, unmodified) already takes an EXPLICIT controller argument. "Resolve the controller through Workspace Runtime Supervisor" is therefore achieved entirely by a NEW CALLER — the supervisor — that looks up `decision.sessionId` in its own registry and passes the resolved controller into the existing, unmodified `apply()`. `WorkspaceLifecyclePolicyEngine` needed zero code changes.

`WorkspaceEventPublisher.publishWorkspaceUpdated(change, sessionId)` (R35, unmodified) is directly reusable for controller-registration/removal events — reused with new `change` strings (`controller_registered`/`controller_unregistered`). No new `AnythingEvent` subtype.

This codebase has never used background-timer/polling machinery anywhere in its coordinator layer (`AutonomousWorkspaceRuntime`'s own doc comment documents staying PULL-based for exactly this reason). This milestone mirrors that discipline.

## PROPOSED / RATIONALE

A thin, real registry — `WorkspaceRuntimeSupervisor` — mapping `sessionId` to a `RuntimeControllerRegistration` (the controller plus real metadata: `experienceId`, `registrationTime`, a live `currentStatus` read straight from the controller). It never constructs, owns the lifecycle logic of, or duplicates `ExperienceRuntimeController`/`WorkspaceLifecyclePolicyEngine` — it composes both, resolving controllers for the policy engine's already-real decisions and forwarding direct lifecycle requests.

## IMPLEMENTATION

`lib/app/workspace_runtime_supervisor.dart` (new):

```dart
class RuntimeControllerRegistration {
  final String sessionId;
  final String? experienceId;
  final ExperienceRuntimeController controller;
  final DateTime registrationTime;
  RuntimeStatus get currentStatus => controller.status; // live, never cached
}

class WorkspaceRuntimeSupervisor {
  final WorkspaceEventPublisher? eventPublisher;

  void register(String sessionId, ExperienceRuntimeController controller, {String? experienceId}); // throws StateError on duplicate
  void unregister(String sessionId); // harmless no-op if absent
  ExperienceRuntimeController? lookup(String sessionId);
  List<RuntimeControllerRegistration> get registrations;
  int removeDisposed(); // caller-invoked sweep of idle registrations, never a timer

  void pause(String sessionId);   // direct forwarding, bypasses the policy engine
  void resume(String sessionId);
  Future<void> shutdown(String sessionId); // terminate() + unregister()

  Future<void> applyInactiveRuntimePolicy(WorkspaceRuntimeSnapshot snapshot, WorkspaceLifecyclePolicyEngine engine);
  Future<void> applyAppLifecyclePolicy(AppLifecycleState state, WorkspaceLifecyclePolicyEngine engine);
}
```

`ExperienceHostScreen` gained one new optional, additive constructor field `runtimeSupervisor` (`null` by default — the 6th such optional DI field this screen has added, one per R32/R33(accept-and-store)/R34/R35/R38/R40). When supplied and a real `sessionId` resolves for `experienceId`, the screen registers its own, already-real `_runtimeController` in `_loadExperience()` (alongside the existing `_reportRuntimeStateToWorkspace()`/`_publishRuntimeLoadedEvent()` calls) and unregisters in `dispose()` — independent of the runtime-ownership check that guards whether the screen also terminates the underlying runtime, since the registration is always this screen's own action to undo regardless of who owns the runtime itself.

## REGISTRATION MODEL

Registering the same `sessionId` twice throws a real `StateError` — a real programming error (it would silently lose the reference to the first controller), never a silent overwrite, mirroring `ExperienceWorkspaceManager.switchActiveExperience()`'s own "real error, never silent no-op" precedent. Unregistering an unknown `sessionId` is a harmless no-op, mirroring `ExperienceWorkspaceManager.closeExperience()`'s own "if (!remove) return" precedent.

`removeDisposed()` sweeps every registration whose live `currentStatus` reads `RuntimeStatus.idle` — i.e., a real `terminate()` already happened but the caller never explicitly unregistered. Edge case considered: a controller registered but never `start()`-ed would also read `idle`. In the real `ExperienceHostScreen` integration this is unreachable — registration happens in `_loadExperience()` only AFTER the runtime has already been opened (either freshly via `openExperience()` or pre-opened via DI), so by the time `register()` runs, `status` is never `idle`. A caller registering a not-yet-started controller directly (bypassing the screen) could hit this edge case — documented here rather than guarded against, since guarding would require the supervisor to assume something about a controller's intended future use it cannot honestly know.

## LOOKUP MODEL

`lookup(sessionId)` returns the controller directly (`ExperienceRuntimeController?`), never a wrapped/copied value — `null` for an unknown id, never throws. `registrations` returns an unmodifiable snapshot list of every current registration, for real workspace-wide enumeration (100-controller performance measured directly, see below).

## POLICY INTEGRATION

`applyInactiveRuntimePolicy(snapshot, engine)` calls the unmodified `engine.evaluateWorkspaceSnapshot(snapshot)`, then for each real decision resolves `decision.sessionId` through this supervisor's own registry and invokes the unmodified `engine.apply(decision, controller)`. A decision naming a session this supervisor has no registration for is silently skipped — a real, honest "nothing this supervisor owns to act on," never a throw.

`applyAppLifecyclePolicy(state, engine)` calls the unmodified `engine.evaluateAppLifecycle(state)` once, then applies the SAME decision to every currently-registered controller — the concrete mechanism for a future "pause every open Experience when the app backgrounds" caller, once more than one screen registers with the same shared supervisor instance.

Neither method is called automatically from anywhere in production this milestone (see Known Limitations) — both are real, tested, callable orchestration methods, following this project's own "build it, prove it standalone" staging discipline (R29→R30, R31→R32, R38→R39 all did the same).

`AppComposition` is NOT touched this milestone — no shared, composition-root-level `WorkspaceRuntimeSupervisor` instance was added. Each `ExperienceHostScreen` that wants supervision must be given the SAME shared supervisor instance by its caller today; there is no automatic, app-wide wiring yet. Deferred explicitly (see Recommendation for R41) rather than forced into this same milestone.

## EVENTS

`register()`/`unregister()` publish real `WorkspaceUpdated` events via the existing `WorkspaceEventPublisher.publishWorkspaceUpdated(change, sessionId)` — `change` values: `controller_registered`, `controller_unregistered`. `pause()`/`resume()`/`shutdown()`/`applyInactiveRuntimePolicy()`/`applyAppLifecyclePolicy()` do not publish their own additional events beyond whatever `ExperienceRuntimeController`/`WorkspaceLifecyclePolicyEngine` already publish for the underlying transition — no duplicate event layer.

## TEST RESULTS

`test/r40_workspace_runtime_supervisor_test.dart` (new, 17 tests):

- **Controller registration**: `register()` then `lookup()` returns the identical controller; `registrations` carries the correct record; a real `controller_registered` event is published.
- **Duplicate prevention**: registering the same `sessionId` twice throws `StateError`; the first registration is unaffected.
- **Controller removal**: `unregister()` removes it; unregistering an unknown id never throws.
- **Session lookup**: unknown id returns `null`.
- **Workspace-wide pause / resume**: 3 real, independently-started `ExperienceRuntimeController`s registered under 3 sessionIds; `applyAppLifecyclePolicy(paused, engine)` pauses ALL of them; `.resumed` resumes all of them.
- **Inactive Runtime policy application across multiple runtime controllers**: 3 real controllers (one "active", two "background/running") registered under sessionIds matching a real multi-session `WorkspaceRuntimeSnapshot`; `applyInactiveRuntimePolicy()` pauses only the two background controllers, leaves the active one running — the concrete proof R40's own Mandatory Vision Validation requires. A second test proves a decision naming an unregistered session is silently skipped, never throws.
- **Disposed controller cleanup**: a terminated (idle) registration is swept by `removeDisposed()`; a still-running one is left alone; the returned count is correct.
- **Regression**: `ExperienceRuntimeController`/`ExperienceWorkspaceManager` used directly, bypassing the supervisor entirely, behave exactly as R38/R32 built them.
- **Backward compatibility**: `ExperienceHostScreen` constructed without `runtimeSupervisor` defaults it to `null`; a real widget test proves load/dispose unaffected; a second real widget test proves a real, injected supervisor genuinely receives a registration once the screen loads and an unregistration on dispose.
- **Performance**: real `Stopwatch`/`ProcessInfo.currentRss` measurements (below).

## PERFORMANCE

Real, measured (see the test file's own "Performance" group): single `register()`+`lookup()` completes in the low microseconds; 100 real controllers registered and looked up (the spec's own explicit "100-controller lookup" requirement) completes in well under a millisecond total (`Map` lookup is O(1)); `applyAppLifecyclePolicy()` across 20 registered controllers completes in a few milliseconds (dominated by the real `AnythingRuntime.pauseSession()`/underlying work per controller, not the registry itself); no measurable RSS growth across 10 repeated register/unregister cycles.

## BUGS FOUND AND FIXED DURING IMPLEMENTATION

Three real, self-caught bugs, fixed before the final commits — not left
undiscovered:

1. `workspace_runtime_supervisor.dart` referenced the `RuntimeStatus` type
   by name (a return-type annotation and a `RuntimeStatus.idle` static
   member access) without importing `anything_runtime.dart`, its defining
   library — transitively importing `ExperienceRuntimeController`'s own
   library is not sufficient for Dart to resolve an explicitly-named type.
   A first-pass `flutter analyze`/`flutter test` run piped through a
   truncating `tail -N` before inspection hid this real compile error;
   re-running a single failing test file directly, without truncation,
   surfaced the real Kernel-compiler error immediately. Fixed with one
   added import.
2. A real, info-level `unintended_html_in_doc_comment` lint — a
   `Map<String, ...>` type signature inside a doc comment, with its
   Markdown code-span backticks accidentally split across two `///` lines
   (dartdoc/Markdown code spans do not reliably protect content split
   across separate comment lines). Fixed by keeping the whole backtick span
   on one line.
3. A real, deterministic test hang: the widget-level backward-compatibility
   test initially called `_Rig.create()`/`openRealSession()` (real
   SQLite/Kernel I/O) directly inside a `testWidgets` callback body, without
   `tester.runAsync()`. `testWidgets` callbacks run in a FakeAsync zone,
   which never completes real, native async I/O on its own — this hung
   deterministically for the full 10-minute test timeout, reproduced twice
   (once inside a full-suite run, once again in isolation) before being
   correctly diagnosed as a genuine bug rather than assumed to be transient
   flakiness. No prior test file in this codebase ever calls `_Rig.create()`
   from inside `testWidgets` for exactly this reason. Fixed by wrapping the
   real I/O in `tester.runAsync()`, matching every other test file's
   established pattern — the isolated file then passed cleanly in about one
   second.

## KNOWN LIMITATIONS

- **No automatic sweep** — `removeDisposed()` is caller-invoked only, matching this codebase's established PULL-based discipline; nothing calls it automatically.
- **Not automatically wired into production policy application** — `applyAppLifecyclePolicy()`/`applyInactiveRuntimePolicy()` are real, tested, callable, but nothing in `ExperienceHostScreen`/`AppComposition` calls them automatically this milestone. Each screen still evaluates/applies its OWN app-lifecycle policy independently via its own `_policyEngine` (R39, unchanged) — the supervisor adds workspace-wide VISIBILITY and a workspace-wide APPLICATION MECHANISM, but nothing yet triggers "apply across every registered controller" automatically from a real app-level event.
- **No shared, composition-root-level supervisor instance** — `AppComposition` is untouched; every caller wanting shared supervision across multiple screens must be given the same `WorkspaceRuntimeSupervisor` instance explicitly today.
- **`removeDisposed()`'s "registered but never started" edge case** is real but unreachable via the actual `ExperienceHostScreen` integration (registration always happens after the runtime is already running) — documented, not guarded against.

## RECOMMENDATION FOR R41

Add a shared `WorkspaceRuntimeSupervisor` instance to `AppComposition` (matching R36's own precedent for adding new shared services), thread it into `ExperienceHostScreen` alongside the composition root's other shared services, and wire ONE real, automatic trigger (e.g. `AnythingAppShell`'s own top-level `WidgetsBindingObserver`, or `AppComposition` itself) that calls `supervisor.applyAppLifecyclePolicy()` across every registered controller on a real app-level background/foreground transition — completing the "workspace-wide, not just per-screen" pause/resume this milestone's registry now makes possible but does not yet automatically trigger.
