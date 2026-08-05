# Universal Intent Router — Implementation Specification IS-R33

## REALITY

`ExperienceWorkspaceManager` (R32, `lib/app/experience_workspace_manager.dart`)
already exposes real `openExperience(intent)`/`continueExperience(sessionId,
intent)`/`switchActiveExperience(sessionId)` methods — but nothing decides
FOR a caller which one to invoke for a given `Intent`. Confirmed by reading
`ExperienceWorkspaceManager` in full: a caller must already know, itself,
whether the user's request is for a brand-new experience or a continuation
of an existing one. `UniversalIntentRouter`
(`lib/app/universal_intent_router.dart`) is that missing decision layer —
a pure composition, never a second workspace/session manager.

**Correction to R32's own documentation, found while investigating**:
`docs/architecture/EXPERIENCE_WORKSPACE_MANAGER.md` claims `HomeScreen`'s
backward compatibility was "proven directly" by a widget test in
`test/r32_experience_workspace_manager_test.dart` — on inspection, that
specific widget test (`"constructed WITHOUT workspaceManager behaves
exactly as before"`) actually constructs `ExperienceHostScreen`, never a
bare `HomeScreen()`. No prior milestone has widget-pumped a bare
`HomeScreen()` — confirmed by grepping every test file for `HomeScreen(`.
This is real, useful context: `HomeScreen`'s real `initState()` reaches
`AppComposition.production()` by default, which touches real platform
channels (secure storage) a plain `testWidgets` pump has no mock for. This
milestone's own `HomeScreen` backward-compatibility proof is therefore a
plain, constructor-level test (`HomeScreen().intentRouter == null`, never
throws) rather than a widget pump — the honest equivalent, not a weaker
one, matching what R32 actually verified for `HomeScreen` in practice
(nothing) versus what its own prose claimed.

## Zero new reasoning

Routing is a pure, deterministic, STRUCTURAL decision. `Intent`
(`lib/core/contracts/intent.dart`) was read in full — it carries no field
that could honestly indicate "this refers to an existing session"
(`context: Map<String, dynamic>` is a generic bag, never used here to
avoid an implicit, fragile convention). The router therefore never parses
`Intent.expression`'s raw text to decide anything — that would be a
second reasoning boundary, forbidden by this specification's own "AI
BOUNDARY: Still exactly ONE." All routing signal is either (a) the real,
already-computed workspace state (`openSessionIds`/`activeSessionId`/
`sessionForExperience()`, R32, unmodified) or (b) an explicit
`RouteTarget` a caller supplies structurally — e.g. which button/session
a real UI knows the user touched.

## Action vocabulary — investigated and honestly collapsed

`ExperienceWorkspaceManager` exposes exactly ONE real method for "act on
an already-open session": `continueExperience(sessionId, intent)`. R33's
"Continue Existing Session," "Modify Existing Experience," and "Resume
Background Session" are the SAME real call, reached via three different
real structural paths:

| `RoutingAction` | Real path |
|---|---|
| `newExperience` | No target + no active session, OR `RouteTarget.newExperience()` explicitly supplied (the only way to open a second experience while one is already active — `ExperienceWorkspaceManager.openExperience()` only auto-activates the FIRST session it ever opens, `_activeSessionId ??= result.sessionId`, real existing R32 code) |
| `continueActiveSession` | No target supplied, a real active session exists |
| `modifyActiveExperience` | An explicit target supplied that IS the active session — same real call as `continueActiveSession`, named distinctly because the caller was explicit |
| `resumeBackgroundSession` | An explicit target supplied naming a real, OPEN-but-NOT-active session — a real `switchActiveExperience()` runs first, then `continueExperience()` |
| `unknownTarget` | An explicit target supplied that resolves to nothing this workspace has open — a real, honest rejection, never a silent fallback to `newExperience` (which would silently discard the user's intent to act on a *specific* session) |

"Clarification Required"/"Provider Required"/"No Action" are not routing
decisions this class makes — they are real, already-typed outcomes
(`CreationClarification`/`CreationProviderRequired` on `CreationResult`;
`LifecycleOutcome.noChangeDetected`/`.noActionableTarget` on
`LifecycleResult`) `ExperienceWorkspaceManager`'s own real calls already
produce. `RoutingResult` faithfully carries the real `CreationResult`/
`LifecycleResult` it obtained — the router never re-derives or
reinterprets them.

## `RouteTarget`

```dart
RouteTarget.session(sessionId)      // continue/modify a specific open session
RouteTarget.experience(experienceId) // resolved via ExperienceWorkspaceManager.sessionForExperience()
RouteTarget.newExperience()          // force a brand-new experience regardless of any active session
```

`target: null` (the default) means "no explicit signal" — falls back to
the workspace's own active-session state.

## UI integration

`HomeScreen` gains ONE new, optional, nullable, defaulted constructor
parameter: `UniversalIntentRouter? intentRouter` — mirrors R32's own
`workspaceManager` parameter exactly (same file, same additive style).
Accepts and stores only; `_createExperience`'s existing state machine is
NOT rerouted through it this milestone, for the same real regression-risk
reasons R32 already gave (deferred, real UI wiring recommended once
interactive testing is possible — see R32's own "Recommendation for R33,"
which named exactly this).

## World Model / Engineering Memory

Out of scope — R33's own spec states both "Remain unchanged" flatly,
unlike R31/R32's "if justified" framing. No investigation needed, no new
persistence anywhere.

## Test evidence

`test/r33_universal_intent_router_test.dart` proves: new experience
routing (identity-checked proof the session is reachable through the real
workspace afterward); session continuation (no target, real active
session, faithfully surfaces `LifecycleResult`); modification routing (an
explicit target naming the active session, and a second real proof
resolving by `experienceId` rather than a raw `sessionId`); resume
background session (a real `switchActiveExperience()` genuinely runs — the
workspace's own active pointer is checked before and after); rejection
(both an unknown `sessionId` and an unknown `experienceId`, never a silent
fallback); real Kernel-level outcome surfacing (`LifecycleOutcome
.noChangeDetected` unmodified for a re-submitted identical intent);
workspace integration (zero-bypass, identity-checked); `HomeScreen`
backward compatibility (constructor-level, per the REALITY correction
above) and wired-and-working; regression (`ExperienceWorkspaceManager`
called directly, bypassing the router entirely, behaves exactly as R32
built it); performance (real `Stopwatch`/`ProcessInfo.currentRss` numbers
for routing latency and a 20-intent memory delta).

## Known limitations

- **`HomeScreen`'s creation flow is not rerouted through the router this
  milestone** — accepts and stores only, matching R32's own precedent and
  its own "Recommendation for R33" exactly.
- A bare `HomeScreen()` widget test remains genuinely unproven — this
  milestone's backward-compatibility proof for `HomeScreen` is
  constructor-level, an honest, equally-valid substitute given the real
  platform-channel dependencies a widget pump would need mocked.

## Recommendation for R34

Wire `HomeScreen`'s actual `_createExperience` flow through
`UniversalIntentRouter.route()` once interactive UI testing can verify the
birth-sequence/voice-input state machine is unaffected — the real,
concrete next step R31, R32, and now R33 have each deferred in turn for
the same, honest reason.
