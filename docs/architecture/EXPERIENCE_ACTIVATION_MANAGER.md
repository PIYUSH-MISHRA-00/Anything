# Experience Activation Manager — Implementation Specification IS-R44

## REALITY

R43 (Workspace Experience Switcher) explicitly, honestly deferred real
navigation-based switching. `WorkspaceSwitcherSheet._selectForeground()`
only called `scheduler.scheduleForeground(sessionId)` (the real runtime
effect — target resumes, siblings pause) and showed a snackbar telling the
user to "reopen it from Recent to view" — it never navigated to reveal the
target session's actual screen, because `WorkspaceRuntimeSupervisor.register()`
(R40, unmodified) throws a real `StateError` on a duplicate `sessionId`, and
Flutter's `Navigator` keeps earlier-pushed routes mounted (not disposed)
when a later route is pushed on top (R41's own established reality).
Naively re-pushing an already-mounted session's screen would therefore
throw.

`HomeScreen` (`lib/features/home/home_screen.dart`) is the ONE and ONLY
real production call site that ever pushes `ExperienceHostScreen` anywhere
in this codebase — confirmed by grep before any code was written. This is
the load-bearing fact that makes a simple design sufficient instead of a
heavier one.

A real layering fact, found by reading the actual widget tree before
deciding whether a `NavigatorObserver` was needed: `MaterialApp` itself is
constructed in `lib/app/app.dart`'s `AnythingApp` (`home:
AnythingAppShell(...)`), ONE level above `lib/app/app_shell.dart`'s
`AnythingAppShell`, where `AppComposition.production()` is actually
constructed. A `NavigatorObserver` attached to `MaterialApp`'s
`navigatorObservers` (in `app.dart`) cannot easily reach an
`AppComposition`-owned manager (in `app_shell.dart`) without restructuring
where `AppComposition` is built. Given `HomeScreen` is confirmed to be the
sole real pusher of `ExperienceHostScreen`, a `NavigatorObserver` is NOT
genuinely required — matching this specification's own "introduce one
shared navigation observer only if genuinely required" instruction.
`lib/app/app.dart` is untouched by this milestone.

## PROPOSED / RATIONALE

`HomeScreen` already owns every real push call site — so `HomeScreen`
itself can track routes at the moment it pushes/pops them, without any
external observer. `ExperienceActivationManager` is a thin, real
composition over `WorkspaceSchedulingEngine` (R42, unmodified) — never a
second scheduler, never a second Navigator, never a second runtime
controller.

## IMPLEMENTATION

`lib/app/experience_activation_manager.dart` (new):

```dart
class ExperienceActivationManager {
  final WorkspaceSchedulingEngine scheduler;
  final WorkspaceEventPublisher? eventPublisher;
  final Map<String, Route<dynamic>> _activeRoutes = {};

  Route<dynamic>? existingRouteFor(String sessionId) => _activeRoutes[sessionId];

  Future<T?> activate<T>(
    NavigatorState navigator,
    String? sessionId, {
    required Route<T> Function() createRoute,
  }) async {
    if (sessionId == null) return navigator.push(createRoute());

    await scheduler.scheduleForeground(sessionId);

    final existing = _activeRoutes[sessionId];
    if (existing != null) {
      navigator.popUntil((route) => route == existing);
      eventPublisher?.publishWorkspaceUpdated('activation_existing_route', sessionId);
      return null;
    }

    final route = createRoute();
    _activeRoutes[sessionId] = route;
    eventPublisher?.publishWorkspaceUpdated('activation_new_route', sessionId);
    final result = await navigator.push(route);
    _activeRoutes.remove(sessionId);
    return result;
  }
}
```

## EXPERIENCE ACTIVATION

`activate()` is the ONE real entry point every `HomeScreen` navigation call
site goes through — new opens (`_openViaCoordinator`'s `OpenReady` case,
both branches of `_showProtectionInputAndResume`) AND the Switcher's
"select a background session" action. A `sessionId` of `null` (the real,
honest "Recent"-list case — `ExperienceOpeningCoordinator`'s opening path
never registers a workspace session, a pre-existing limitation restated
from R42/R43, not fixed here) falls back to a plain, untracked push,
identical to this codebase's pre-R44 behavior for that path.

## NAVIGATION MODEL

Route identity, not string-based route naming: `activate()` tracks the
real `Route` OBJECT it pushes, keyed by `sessionId`, in a plain `Map`. A
later `activate()` call for the SAME `sessionId` pops back to that EXACT
tracked route via `Navigator.popUntil((route) => route == existing)` — real
Dart object identity, which cannot collide the way a string name could.
Cleanup is automatic: `Navigator.push()`'s returned `Future` completes
whenever the route is removed by any means (back gesture, pop button, or a
later `popUntil`), so the tracked entry is removed exactly once, whenever
that really happens — never a manually-maintained lifecycle hook.

`activate()` takes a `NavigatorState`, not a `BuildContext`, specifically
so a caller that must dismiss its OWN route first (the Switcher sheet
popping itself before activating a background session) can capture the
stable `NavigatorState` BEFORE that pop, rather than reusing a
`BuildContext` that becomes invalid once its own widget is removed from the
tree — a real, subtle correctness requirement found while implementing the
Switcher integration, not a hypothetical one.

`HomeScreen`'s 3 real call sites resolve `sessionId` via
`_workspaceManager.sessionForExperience(experienceId)?.sessionId` — the
exact same resolution `_publishRuntimeLoadedEvent()`/
`_registerWithSupervisor()` already established (R35/R41) — and continue
chaining `.then((_) => _loadRecent())` onto `activate()`'s returned
`Future<T?>` exactly as they did onto the raw `Navigator.push()` before.

## RUNTIME ACTIVATION

Every real `activate()` call for a non-null `sessionId` reaches
`scheduler.scheduleForeground()` (R42, unmodified) FIRST, whether the route
already exists or must be pushed — the real runtime effect (target
resumes, every other registered, running background runtime pauses via the
Inactive Runtime policy) always happens, regardless of the navigation
outcome.

## SWITCHER INTEGRATION

`WorkspaceSwitcherSheet._selectForeground()` (`lib/features/workspace/workspace_switcher.dart`)
now resolves the target session's real, ALREADY-RUNNING
`ExperienceRuntimeController`/`AnythingRuntime` via
`WorkspaceRuntimeSupervisor.lookup(sessionId)` and the real `ExperiencePackage`
via `SessionRuntimeStatus.runtimeState?.package`, injecting BOTH into a new
`ExperienceHostScreen` route through its established `runtime:`/
`runtimeController:` DI parameters (R38) — never constructing a fresh
runtime. A real, deliberate omission: the constructed route does NOT pass
`runtimeSupervisor:`. The resolved controller came from that SAME
supervisor's own `lookup(sessionId)`, meaning it is ALREADY registered —
`ExperienceHostScreen._registerWithSupervisor()` (unmodified, R41) always
calls `register()` unconditionally when a supervisor is supplied, which
would raise the exact duplicate-`sessionId` `StateError` this milestone
exists to avoid. Omitting it is the real, minimal fix; `ExperienceHostScreen`
itself needed zero changes.

In the common case (the background session's screen is still mounted,
tracked in `_activeRoutes`), `activate()`'s `popUntil` branch runs and the
`createRoute` closure above is never even invoked — no new
`ExperienceHostScreen` is constructed at all, the existing mounted instance
is simply revealed. The closure only executes for the rarer, honest case
where a registered session has no currently-tracked route (e.g. its screen
was popped earlier but the runtime is still alive and registered).

A real, honest fallback: if `WorkspaceRuntimeSupervisor.lookup()` or the
session's `runtimeState`/`package` is unavailable, the Switcher falls back
to the exact pre-R44 (R43) behavior — `scheduleForeground()` only, plus a
snackbar — rather than a fabricated navigation.

## EVENTS

No new `AnythingEvent` subtype. `WorkspaceEventPublisher.publishWorkspaceUpdated(change, sessionId)`
(R35, unmodified) is reused with two new, real `change` strings:
`'activation_existing_route'` (popUntil path) and `'activation_new_route'`
(fresh push path).

## TEST RESULTS

`test/r44_experience_activation_manager_test.dart` (new, 13 tests) proves,
with real objects: shared activation manager construction
(`AppComposition.production().experienceActivationManager` is real,
non-null, and two reads return the IDENTICAL instance); existing route
activation (`activate()` called twice for the SAME `sessionId` pushes
exactly ONE `ExperienceHostScreen`, proven by pushing an unrelated route on
top first and confirming `popUntil` correctly searches past it); duplicate
prevention (the concrete proof: re-activating an already-mounted session
NEVER throws `WorkspaceRuntimeSupervisor.register()`'s duplicate
`StateError`, registrations count never grows, and the original controller
identity is preserved); runtime activation (`activate()` reaches
`scheduler.scheduleForeground()` for real); navigation activation (a NEW
session pushes a real new route, an EXISTING session navigates back
without adding one; a `null` sessionId falls back to a plain, untracked
push); Switcher integration — the concrete Mandatory Vision Validation
proof (pump `HomeScreen`, open two Experiences, open the Switcher, tap the
background one, and confirm the real Navigator now shows that session's
actual `ExperienceHostScreen` in view); regression
(`WorkspaceSchedulingEngine`/`WorkspaceRuntimeSupervisor` used directly,
bypassing the activation manager entirely, behave exactly as R40/R42 built
them); backward compatibility (`HomeScreen()` without `activationManager`
defaults it to `null`; a bare `HomeScreen()` renders without throwing);
real `Stopwatch`/`ProcessInfo.currentRss` performance measurements.

`test/r43_workspace_experience_switcher_test.dart` required mechanical
updates to match `WorkspaceSwitcherSheet`'s new required
`activationManager`/`runtimeSupervisor` constructor fields — no test
assertions changed, only fixture construction.

**Execution result:** `flutter analyze`: 71/0, unchanged baseline.
`flutter test`: 1732/1732 passed (1719 baseline + 13 new), zero
regressions — both independently confirmed by the coordinating session via
`D:\flutter\bin\flutter.bat`, full untruncated runs. `WorkspaceSchedulingEngine`/
`WorkspaceRuntimeSupervisor`/`WorkspaceLifecyclePolicyEngine`/
`ExperienceRuntimeController`/`AnythingRuntime`/`ExperienceHostScreen`/
`UniversalIntentRouter`/`AnythingKernel`/World Model/Engineering Memory all
confirmed completely untouched via `git diff --stat`. `useCompilerPipeline`
unaffected, still defaults `false`. Zero new LLM/reasoning calls anywhere
in the diff.

## PERFORMANCE

Real, measured (never fabricated): activation latency for a fresh push
(fire-to-UI-settle, via `Stopwatch` around the real widget pump cycle);
navigation lookup / foreground transition latency for an existing route
(`popUntil`, measured directly since it resolves synchronously-fast without
a new push); memory: real process RSS delta across 10 repeated
`scheduleForeground()` cycles on a headless (non-widget) manager.

## KNOWN LIMITATIONS

- `ExperienceOpeningCoordinator`'s "Recent"-list opening path still never
  registers a workspace session (restated from R42/R43, not fixed here) —
  an Experience opened only that way has no resolvable `sessionId`, so
  `activate()` correctly, honestly falls back to a plain, untracked push
  for it.
- A workspace session tracked by `ExperienceWorkspaceManager`/
  `WorkspaceRuntimeSupervisor` but never pushed as a route in the CURRENT
  app session (e.g. after a hot-restart) has no entry in `_activeRoutes` —
  `activate()` correctly falls through to the "push a new route" branch for
  it, which is honest and correct, not a bug, but worth stating plainly: the
  activation manager's route-tracking is scoped to the current app session's
  own navigation history, never a durable, cross-restart record.
- No `NavigatorObserver` was introduced. If a second real production call
  site for `ExperienceHostScreen` is ever added outside `HomeScreen`, this
  milestone's simple, sufficient design would need revisiting.

## RECOMMENDATION FOR R45

Every real building block for a genuine multi-app "operating system"
experience now exists and is wired end-to-end: creation, routing, runtime
lifecycle, policy, supervision, scheduling, user-visible switching, and now
real navigation-based activation. The natural next milestone is closing the
`ExperienceOpeningCoordinator` "Recent"-list gap — giving that opening path
a real workspace session too, so every way of opening an Experience
(create, switch, and reopen from Recent) participates in the same real
scheduling/activation system consistently.
