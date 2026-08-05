# Autonomous Workspace Runtime — Implementation Specification IS-R34

## REALITY

R34's own "RESPONSIBILITIES" list reads as if it names new concepts. It
almost entirely does not — confirmed by reading every real type before
writing any code:

| R34 "Responsibility" | Real, already-existing field |
|---|---|
| Active runtime instances | `SessionState.currentRuntimeState` (`ExperienceSession`, R31), reachable per-session via `ExperienceWorkspaceManager.openSessions` (R32) |
| Runtime health | `ExperienceSession.status` (`SessionStatus`, `lib/runtime/experience_session.dart`) — already carried on `currentRuntimeState` |
| Deployment status | `SessionState.currentLifecycleResult?.outcome` (`LifecycleOutcome`, R30) |
| Artifact status | `LifecycleResult.artifactIntelligenceReport` (R28, attached to `LifecycleResult` since R30 — full-compilation-path only) |
| Pending evolution | `SessionState.pendingModification` (`Intent?`, R31 — non-null only while `continueSession()` is in flight) |
| Background engineering | Any session in `openSessions` that is not `activeSessionId` — a real, already-derivable structural fact (R32) |

Given this, R34's real, honest, additive contribution is narrow: a real
SNAPSHOT/AGGREGATION layer over already-real per-session data, plus one
genuinely new concept — derived notifications.

## "Autonomous" / "Supervise" — resolved deliberately, no new background execution

Confirmed by grep (`Timer.periodic`/`Stream.periodic` across `lib/`): this
codebase has no background-timer/polling machinery anywhere in its
coordinator layer. `lib/runtime_intelligence/background_coordinator.dart`
explicitly documents avoiding it; the one real hit,
`lib/widgets/ai_loading_screen.dart`, is a UI-animation timer, unrelated.
Introducing new continuously-running execution machinery here would be
architecturally novel and unverifiable without live observation.
`AutonomousWorkspaceRuntime` is honestly PULL-based:
`captureRuntimeState()` is a pure, real, always-correct-when-called
function of already-real state — "autonomous" is satisfied by correctness
on every call, never by a live poll loop.

## Workspace runtime

`AutonomousWorkspaceRuntime` (`lib/app/autonomous_workspace_runtime.dart`)
owns exactly ONE real `ExperienceWorkspaceManager` reference and never
duplicates its state:

```
captureRuntimeState() -> reads ExperienceWorkspaceManager.openSessions/.activeSessionId
```

`SessionRuntimeStatus` is a real per-session VIEW — every field a direct
read of `SessionState`/`ExperienceWorkspaceManager`, never a copy that
could drift. `WorkspaceRuntimeSnapshot` aggregates these plus real
notifications, timestamped with the real capture time.

## Background supervision

`WorkspaceRuntimeSnapshot.backgroundSessions`/`.activeSession` are real,
derived getters over the same per-session list — a session's "active" vs
"background" status is read once, at capture time, from
`ExperienceWorkspaceManager.activeSessionId`, never tracked as a second,
separately-mutated flag.

## Runtime state

Every `SessionRuntimeStatus` field (`runtimeState`, `deploymentStatus`,
`artifactStatus`, `hasPendingEvolution`) is a direct property read off the
real `SessionState` for that session — proven in
`test/r34_autonomous_workspace_runtime_test.dart`'s "per-session runtime
state ... aggregated exactly as reported" test, which injects two
genuinely distinct real `ExperienceSession`/`SessionStatus` values (one
`running`, one `paused`) and confirms both are reflected correctly and
independently.

## Notifications

Real, derived — a background (non-active) session whose
`currentLifecycleResult.outcome` is a real TERMINAL state that this
runtime has not yet reported for that session becomes one real
`WorkspaceNotification`. "Terminal" is defined as every outcome that
follows a real, COMPLETED regeneration attempt:

- `deployed` — the candidate was committed.
- `blocked` — the candidate failed its real deployment gate.
- `commitFailed` — the candidate passed its deployment gate but
  `applyEvolutionPlan()`'s own defensive re-validation (R6) rejected it.

`noChangeDetected`/`noActionableTarget` are explicitly excluded — no real
regeneration was ever attempted for these, so there is nothing to notify
about. `noEngineeringMemory`/`cannotEvolve` are real PRECONDITION
failures before any attempt began — also excluded.

**Real finding while writing the end-to-end test**: a session created via
the default (legacy, `useCompilerPipeline: false`) creation path and then
evolved through the real incremental path reaches `commitFailed`, not
`deployed`, in this project's own test fixtures (the legacy-created
"before" package's own re-validation inside `applyEvolutionPlan()`
rejects the incrementally-regenerated candidate). This is a genuine,
observed property of the existing R6/R30 machinery, not a defect
introduced here — `commitFailed` was added to the notifiable-outcome set
specifically because this real scenario proved it is a real, reachable,
worth-surfacing terminal state, not a hypothetical one.

De-duplication is real: a per-session "last-notified outcome" map (real,
small, in-memory only) ensures the SAME real outcome is never re-reported
on a later `captureRuntimeState()` call; a genuinely NEW terminal outcome
for that session (e.g., a later real `deployed` after an earlier
`blocked`) produces a fresh notification.

## World Model

Declined — same reasoning R31/R32/R33 already applied correctly: a
workspace-runtime snapshot has no durable identity independent of the
running app process. Persisting it would invent a concept with no real
reuse case.

## UI integration

`HomeScreen` and `ExperienceHostScreen` each gain ONE new, optional,
nullable, defaulted constructor parameter: `AutonomousWorkspaceRuntime?
workspaceRuntime`. Both default to `null` — every existing construction
path and test is byte-for-byte unaffected (proven directly: real
constructor-level tests for both screens, matching R33's own precedent of
avoiding a fragile full `HomeScreen()` widget pump for the same real
reason — `initState()` reaches real platform channels via
`AppComposition.production()` when no `composition` is supplied).

Unlike R32's `workspaceManager` (which `ExperienceHostScreen` could
safely go one step further with — reporting real runtime state through
`reportRuntimeStateForExperience()` once its runtime loads),
`AutonomousWorkspaceRuntime` exposes NO mutation/report method — it is a
pure, read-only snapshot aggregator. There is no analogous "safe extra
step" to wire this milestone; accept-and-store is the honest, real limit
for both screens.

## Known limitations

- Pull-based only — no live push/stream notification mechanism. A future
  milestone could investigate real event-emission sourced from
  `ExperienceWorkspaceManager`'s own `_record()` calls, but that was not
  built here (no genuine, low-risk case was found that didn't amount to
  inventing new background machinery).
- `AutonomousWorkspaceRuntime` has no UI wiring beyond accept-and-store —
  no screen currently calls `captureRuntimeState()`. Recommended for a
  future milestone once a real display surface (e.g. a workspace/session
  switcher UI) exists to consume it.
- The `commitFailed`-reaches-more-often-than-`deployed` finding above is a
  real property of this project's default (legacy) creation path
  combined with incremental evolution — worth investigating in a future
  milestone focused on compiler-pipeline production readiness, out of
  scope here.

## Recommendation for R35

Wire `AutonomousWorkspaceRuntime.captureRuntimeState()` into a real UI
surface (e.g. a workspace switcher/notification badge on `HomeScreen`)
now that the underlying data is real and aggregated.
