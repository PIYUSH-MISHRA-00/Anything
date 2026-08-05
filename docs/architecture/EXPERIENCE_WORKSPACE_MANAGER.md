# Experience Workspace Manager — Implementation Specification IS-R32

## REALITY

`IntentSessionManager` (R31, `lib/app/intent_session_manager.dart`) already
manages MANY concurrent sessions internally (`Map<String, SessionState>
_sessions`) — it is not a single-session-only class. Nothing tracked which
of those sessions the workspace considers "open" for display purposes, or
which one is "active." `ExperienceWorkspaceManager`
(`lib/app/experience_workspace_manager.dart`) is that composition — a thin,
additive layer over the real, unmodified `IntentSessionManager`, never a
second session manager.

`ExperiencesScreen` (`lib/features/experiences/experiences_screen.dart`)
already exists and solves a different, already-real problem: browsing every
PERSISTED Experience via `SqliteExperienceRepository`, independent of
whether any of them are currently open in this running app session.
"Workspace" means the opposite — experiences with a live, in-memory
`SessionState` in the CURRENT process. The two are never duplicated or
conflated.

## Workspace model — mapped to real, existing types

| R32's requested field | Real backing |
|---|---|
| `WorkspaceId` | Not modeled — a workspace has no real identity distinct from the `ExperienceWorkspaceManager` instance holding it (same reasoning as `SessionId` not needing a workspace-level counterpart) |
| `Open Experiences` | `ExperienceWorkspaceManager.openSessions`/`.openSessionIds` — real, workspace-tracked subset of `IntentSessionManager`'s own sessions |
| `Active Experience` | `ExperienceWorkspaceManager.activeSessionId`/`.activeSession` |
| `Background Sessions` | Any open session that is not the active one — proven by a dedicated test showing an evolving background session never disturbs the active pointer, and both sessions' `SessionState` stay real and independent |
| `Runtime Instances` | `SessionState.currentRuntimeState` (R31) — `ExperienceWorkspaceManager.updateRuntimeState()`/`.reportRuntimeStateForExperience()` forward, unmodified, to `IntentSessionManager.updateRuntimeState()`; no second, parallel runtime-state store |
| `Engineering Sessions` | `IntentSessionManager`'s own `SessionState`s — read via `sessionFor()`, never copied |
| `Workspace Timeline` | Real `ActivityEvent`s (`open`/`close`/`switch`), reusing the existing `ActivityRepository` (R1-R7/R31) — never a new persistence mechanism |
| `Workspace Notifications` | Not modeled — no real notification-delivery concept exists anywhere upstream to derive workspace-level notifications from (honest, named gap, matching this project's established never-fabricate discipline) |
| `Workspace State` | The plain, in-memory fields above, taken together |

## Flow

```
openExperience(intent)                 -> IntentSessionManager.startSession()      (unchanged)
continueExperience(sessionId, intent)  -> IntentSessionManager.continueSession()    (unchanged)
```

`IntentSessionManager` is never modified. `closeExperience()`/
`switchActiveExperience()` are genuinely new, small, workspace-only
operations — pure in-memory bookkeeping, never touching persisted data.

## UI integration

`HomeScreen` (`lib/features/home/home_screen.dart`) and
`ExperienceHostScreen` (`lib/runtime/experience_host_screen.dart`) each gain
ONE new, optional, nullable, defaulted constructor parameter:
`ExperienceWorkspaceManager? workspaceManager`. Both default to `null` —
every existing construction path and test is byte-for-byte unaffected
(proven directly: `test/r32_experience_workspace_manager_test.dart`'s
"constructed WITHOUT workspaceManager" widget test).

`HomeScreen` accepts and stores the parameter only — its existing
`_createExperience`/`_showBirth`/`_creationReady` state machine is NOT
rerouted through it this milestone. Rewiring that flow is a real,
non-trivial change to live, interactive, stateful UI (voice input,
animations, birth-sequence timing) that a single implementation pass cannot
safely verify without interactive testing — deferred honestly rather than
forced.

`ExperienceHostScreen` goes one step further, safely: once the runtime
finishes loading (`_loadExperience`'s success path), if a real
`workspaceManager` was supplied AND `experienceId` is known, the screen
reports its own real, current `ExperienceSession` via
`workspaceManager.reportRuntimeStateForExperience()` — a real, additive,
low-risk call that never touches the screen's existing
`planEvolution()`/`applyEvolutionPlan()`/`rollback()` flow (that remains
`ExperienceModificationCoordinator`'s own, unmodified responsibility, R30).
Proven directly: the "constructed WITH a real workspaceManager" widget test
confirms the real `ExperienceSession` genuinely reaches
`IntentSessionManager`'s own `SessionState.currentRuntimeState`.

## World Model — declined

Same reasoning R31 already applied to `IntentSessionManager` itself: a
workspace has no durable identity independent of the running app process.
Persisting it would invent a concept with no real reuse case — the same
call this project's R10-R12/R14/R15/R24/R28/R29/R31 all made correctly
before it.

## Test evidence

`test/r32_experience_workspace_manager_test.dart` proves: workspace
creation (a real, identity-checked proof that `openExperience()` genuinely
invokes `IntentSessionManager.startSession()`, never a re-implementation);
multiple open experiences (two real experiences tracked, switching, closing
with real active-session promotion, closing-to-empty leaving
`activeSessionId` honestly `null`); session forwarding (a real,
identity-checked proof `continueExperience()` reaches
`EngineeringLifecycleCoordinator` unmodified, and a real `StateError` for a
session the workspace never opened); background engineering (evolving a
non-active session never disturbs the active pointer, and each session's
state stays real and independent); runtime tracking (both
`updateRuntimeState()` and the experience-id bridge
`reportRuntimeStateForExperience()`, including its honest no-op case);
workspace timeline (real, correctly-ordered events); UI integration
(both screens' backward-compatibility and wired-and-working cases, as real
widget tests); regression (`IntentSessionManager` called directly,
bypassing the workspace entirely, behaves exactly as before); performance
(real `Stopwatch`/`ProcessInfo.currentRss` numbers for startup, switching,
and a 20-session memory delta).

## Known limitations

- **`HomeScreen`'s creation flow is not rerouted through the workspace
  manager this milestone** — it accepts and stores the parameter only. Real
  wiring of `_createExperience()` through `openExperience()` is recommended
  for a future milestone, once interactive verification of the birth-sequence
  UI is possible.
- **`WorkspaceId`/`Workspace Notifications` are honestly unmodeled** — no
  real signal exists anywhere upstream to derive either from without
  fabrication.
- **`ExperienceHostScreen`'s modification flow still goes directly through
  `ExperienceModificationCoordinator`**, not through the workspace/session
  layer — that remains `EngineeringLifecycleCoordinator`'s own real
  responsibility (R30); this milestone's UI wiring is scoped to runtime-state
  reporting only.

## Recommendation for R33

Wire `HomeScreen`'s actual creation flow through
`ExperienceWorkspaceManager.openExperience()` once interactive UI testing
can verify the birth-sequence/voice-input state machine is unaffected —
the same "prove it standalone first, then reroute" discipline this
milestone itself just followed for `ExperienceHostScreen`'s runtime-state
report.
