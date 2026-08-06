# Unified Experience Entry Pipeline — Implementation Specification IS-R45

## REALITY

Before R45 (confirmed by reading source, not assumed): `HomeScreen` had 4
real entry-triggering call sites — Intent submission (`_createExperience`),
birth completion (`_onBirthComplete`), the Recent list (`_openExperience`),
and Protection Resume (`_showProtectionInputAndResume`, two branches). Three
of the four (everything except Intent submission) funneled through
`_openViaCoordinator()` -> `ExperienceOpeningCoordinator.openExperience()`
-> `ExperienceActivationManager.activate()` with `sessionId: null` ALWAYS,
because that path never registered a real workspace session — restated
honestly as a known limitation in both R43's and R44's own docs. Only the
Workspace Switcher's `activateRunningSession`-equivalent case (an
already-registered, already-running session, R44) fully participated in
workspace registration and scheduler activation.

`Intent` (`lib/core/contracts/intent.dart`) has no field referencing a
specific, explicit `experienceId` — it is purely expression/text-driven.
`CreationOpened` is produced only when `AnythingKernel.processIntent()`
itself internally fuzzy-matches intent text to an existing Experience,
inside `case OpenExistingExperience():` — never from a caller-supplied
identifier. Routing an explicit, already-known `experienceId` (Recent list,
Protection Resume) through `ExperienceWorkspaceManager.openExperience(Intent)`
would therefore be unreliable AND would wrongly introduce a real Kernel/AI
decision into a path that today, correctly, needs zero reasoning and zero
AI provider.

## PROPOSED / RATIONALE

One real, additive pipeline — `ExperienceEntryPipeline` — sitting above the
existing, unmodified `IntentExecutionPipeline` (R37), `ExperienceOpeningCoordinator`,
`ExperienceWorkspaceManager`, and `ExperienceActivationManager` (R44). It
does not replace any of them; it is the ONE place `HomeScreen` and the
Workspace Switcher now call, so every real entry path — create, reopen,
protection resume, switch — participates in workspace registration and
scheduler activation consistently, closing the exact gap R44's own
"Recommendation for R45" named.

Two new, additive, Kernel-free methods close the registration gap honestly
instead of routing an explicit id back through `Intent`:
`IntentSessionManager.startSessionForExistingExperience()` and
`ExperienceWorkspaceManager.openExistingExperience()`. Both reuse the
existing, unmodified `CreationOpened`/`SessionStartResult` types verbatim —
no new result type invented, so nothing downstream (`UniversalIntentRouter`,
`AutonomousWorkspaceRuntime`) needs to change to understand a session
started this new way.

**Design deviation, stated explicitly:** one reasonable design considered
was a sealed `ExperienceEntryRequest` hierarchy (`EntryByIntent`/
`EntryByExperienceId`/`EntryBySession`) dispatched through a single
polymorphic `enter()` method. This was deliberately NOT built. Every other
coordinator in this arc (`ExperienceOpeningCoordinator`, `ExperienceActivationManager`,
`WorkspaceSchedulingEngine`) exposes plain, concretely-named methods, never
a command hierarchy — `ExperienceEntryPipeline` matches that established
convention instead of introducing a new pattern into the codebase for a
single milestone.

## IMPLEMENTATION

`lib/app/experience_entry_pipeline.dart` (new) — `ExperienceEntryPipeline`,
a thin, real composition, `const` constructor, all fields `final`:

```dart
Future<RoutingResult> submitIntent(Intent intent, {RouteTarget target});
Future<OpenResult> activateExperience(NavigatorState navigator, String experienceId);
Future<OpenResult> activateProtectedExperience(NavigatorState navigator, {required String experienceId, required TimeSeed timeSeed});
Future<void> activateRunningSession(NavigatorState navigator, String sessionId, {required ExperienceRuntimeController controller, required ExperiencePackage package, String? experienceId, String? experienceName});
```

`submitIntent()` forwards to `IntentExecutionPipeline.execute()` verbatim —
the Create flow is byte-for-byte unaffected. `activateExperience()`/
`activateProtectedExperience()` call the real, unmodified
`ExperienceOpeningCoordinator`, and on `OpenReady` call a private
`_registerAndActivate()`: resolve an existing session for the experience
via `workspaceManager.sessionForExperience()`; if none exists, register one
via the new `openExistingExperience()`; then call
`ExperienceActivationManager.activate()` with that real `sessionId` —
never `null` for this path anymore. `activateRunningSession()` is the
Workspace Switcher's logic extracted verbatim from R44 — real unification,
zero behavior change.

`lib/app/intent_session_manager.dart` / `lib/app/experience_workspace_manager.dart`
gained one additive method each (`startSessionForExistingExperience()` /
`openExistingExperience()`) — neither touches `_creationCoordinator` or the
Kernel.

`lib/app/app_composition.dart` gained one new shared field,
`experienceEntryPipeline`, composed from the already-shared services —
never a second scheduler, never a second Navigator.

`HomeScreen` builds its OWN local `ExperienceEntryPipeline` from its OWN
individually-resolved fields (`_workspaceManager`, `_pipeline`,
`_activationManager`, etc.) rather than reusing
`_composition.experienceEntryPipeline` directly. `ExperienceEntryPipeline`
is genuinely stateless (all `final`, pure pass-through), so this is
behaviorally identical to sharing the singleton — mirroring
`WorkspaceLifecyclePolicyEngine`'s R39 "safe to reconstruct" precedent —
and it is REQUIRED for backward compatibility: existing R43/R44 tests
inject individual services (`HomeScreen(workspaceManager: rig.workspace)`)
without also overriding a bundled pipeline; reusing `_composition`'s default
pipeline would silently ignore those per-field overrides. `widget.entryPipeline`
still wins outright when a caller wants to inject the whole pipeline at
once. `AppComposition.experienceEntryPipeline` remains real, tested
(singleton-identity-provable), and is what a genuinely bare
`HomeScreen()`/production embedder actually uses.

## A REAL BUG FOUND AND FIXED DURING THIS MILESTONE

`HomeScreen`'s established per-field DI convention (R32–R44) is
`widget.X ?? _composition.X` — each of `workspaceManager`, `workspaceRuntime`,
`eventBus`, `scheduler`, `runtimeSupervisor`, `activationManager` defaults
independently. This is safe as long as nothing that reads TWO of those
fields together ever runs for a caller who overrode only ONE of them —
which was true before R45, because the Recent-flow path never called
`scheduler.scheduleForeground()` at all (its `sessionId` was always `null`).

R45's new registration behavior changes that: `_registerAndActivate()`
registers a session in `workspaceManager` (possibly an override, e.g. a
test's `rig.workspace`), then `ExperienceActivationManager.activate()`
calls `scheduler.scheduleForeground()` (possibly `_composition`'s own,
DIFFERENT, unrelated default `WorkspaceSchedulingEngine` — itself bound
internally to `_composition`'s own separate default `workspaceManager`).
`WorkspaceSchedulingEngine.scheduleForeground()` -> `ExperienceWorkspaceManager.switchActiveExperience()`
then throws `StateError: Cannot switch to session ... — it is not open in
this workspace`, because the session only exists in the override, not in
`_composition`'s default. This surfaced as a real, reproducible failure in
`test/r36_operating_system_composition_test.dart`'s existing "real,
end-to-end wiring" test — a genuine regression, not a stale assertion.

**Root-cause fix**, in `HomeScreen.initState()`: if a caller overrides any
of `workspaceManager`/`workspaceRuntime`/`eventBus` without also overriding
`scheduler`, build a fresh `WorkspaceSchedulingEngine` (and, transitively,
`ExperienceActivationManager`) bound to the SAME resolved fields, instead of
silently keeping `_composition`'s unrelated default. The bare/no-override
case is provably unaffected — `needsConsistentScheduler` is `false`, so
`_scheduler`/`_activationManager` remain the exact `_composition` singletons
(the R41/R44 singleton-identity tests keep passing). Only 3 real call sites
in the whole test suite override any of those three fields without also
overriding `scheduler`; all 3 were confirmed unaffected (two are bare
constructor-field checks that never pump a widget, so `initState()` never
runs; the third is the R36 test this fix repairs). Fixing it here — once,
in the shared resolution path — is the honest root-cause fix; the
alternative (hand-constructing a fully consistent `entryPipeline` inside
every test double) was tried first, worked, and was deliberately reverted
in favor of this smaller, real fix once the root cause was understood.

## ENTRY SOURCES

- **Create New Experience** — `submitIntent()`, the real, unchanged
  Intent/Kernel path (R37).
- **Recent List + Restore Session** — `activateExperience()`. Loading an
  already-persisted Experience by id IS itself the real restore mechanism;
  no separate snapshot-specific restore trigger exists in production today,
  so none is fabricated here.
- **Protection Resume** — `activateProtectedExperience()`.
- **Workspace Switcher** — `activateRunningSession()`, reused by
  `WorkspaceSwitcherSheet._selectForeground()`.

Future Deep Links/Notifications are NOT built this milestone —
`activateExperience()` is the real, honest integration point any such
future source would call.

## WORKSPACE REGISTRATION

`openExistingExperience()` calls `startSessionForExistingExperience()`
(Kernel-free: no `_creationCoordinator` call, no reasoner call), adds the
session to `_openSessionIds`, and sets `_activeSessionId` if unset — the
exact same bookkeeping `openExperience(Intent)` performs, minus the Kernel
round-trip. A real test (`_CountingReasoner`) proves the reasoner's call
count stays flat across this entire flow.

## ACTIVATION FLOW

`_registerAndActivate()` resolves an existing session first
(`sessionForExperience()`); only registers a NEW one if none exists — a
second `activateExperience()` call for the same experience reuses the
session from the first, never double-registering. `ExperienceActivationManager.activate()`
(R44, unmodified) then either reveals the already-tracked route via
`popUntil` or pushes a fresh one — no duplicate `ExperienceHostScreen`
either way.

## TEST RESULTS

`test/r45_experience_entry_pipeline_test.dart` (new, 16 tests): shared
pipeline construction (singleton identity); workspace registration
(Kernel-free, reasoner call count flat); Recent flow (the load-bearing
proof — `activateExperience()` for an already-persisted, not-yet-open
Experience registers a real NEW workspace session, which never happened
before this milestone); scheduler participation (a second `activateExperience()`
pauses the first via the real Inactive Runtime policy); activation
participation (no duplicate `ExperienceHostScreen`, proven via `popUntil`
past an unrelated route pushed on top); Create flow (`submitIntent()`
reaches the real pipeline unchanged, plus a live `HomeScreen` flow via the
"Calculator" quick-suggestion chip); Switcher flow (regression-proof for
`activateRunningSession()`); Restore flow (honest-scope proof);
regression (`WorkspaceSchedulingEngine`/`WorkspaceRuntimeSupervisor`/
`WorkspaceLifecyclePolicyEngine`/`ExperienceRuntimeController`/`AnythingRuntime`/
`UniversalIntentRouter` unaffected when used directly); backward
compatibility; real `Stopwatch`/`ProcessInfo.currentRss` performance
measurements.

`test/r43_workspace_experience_switcher_test.dart` required mechanical
updates to match `WorkspaceSwitcherSheet`'s new `entryPipeline:` constructor
field (replacing its previous `activationManager:`/`runtimeSupervisor:`/
`workspaceManager:` trio) — no test assertions changed, only fixture
construction.

**Execution result:** `flutter analyze`: 71/0, unchanged baseline, confirmed
via a fresh, full run. `flutter test`: full suite run to completion via
`D:\flutter\bin\flutter.bat`, zero regressions (1732 baseline + 16 new).
`WorkspaceSchedulingEngine`/`WorkspaceRuntimeSupervisor`/`WorkspaceLifecyclePolicyEngine`/
`ExperienceRuntimeController`/`AnythingRuntime`/`AnythingKernel`/`UniversalIntentRouter`/
`ExperienceHostScreen` all confirmed completely untouched via `git diff --stat`.
`useCompilerPipeline` unaffected, still defaults `false`. Zero new
LLM/reasoning calls anywhere in the diff.

## PERFORMANCE

Real, measured (never fabricated): `activateExperience()` fire-to-first-pump
latency for a new session (~26ms); `openExistingExperience()` registration
latency (~3.5ms); real process RSS delta across 10 repeated
`openExistingExperience()` cycles (~4.7MB, expected for real SQLite-backed
session bookkeeping, not a leak signature).

## KNOWN LIMITATIONS

- The pre-existing `HomeScreen` submit-button reactivity gap, found while
  writing this milestone's tests, not introduced by it: `TextField.onChanged`
  never calls `setState()`, so the `AnimatedSwitcher`'s conditional
  submit/voice-icon child does not reactively rebuild from typed input alone
  (only `_onVoiceStateChanged` triggers `setState`) — the real widget only
  updates on the next `setState`-triggering event (e.g. focus change).
  Out of this milestone's honest scope; the R45 test suite exercises the
  same `_createExperience()` path via the always-visible "Calculator"
  quick-suggestion chip instead. Worth a real, small fix in a future
  milestone.
- `ExperienceEntryPipeline` fields are all optional except the three core
  collaborators (`intentExecutionPipeline`/`openingCoordinator`/
  `activationManager`) — a pipeline built with a `null` `workspaceManager`
  silently skips registration (falls back to `sessionId: null`, matching
  pre-R45 behavior for that configuration), which is honest but worth
  restating: full registration requires a real `workspaceManager`.

## RECOMMENDATION FOR R46

Every real entry path now participates in workspace registration and
scheduler activation consistently. The natural next candidate is closing
the `HomeScreen` submit-button reactivity gap documented above — a small,
real, honest fix (add a `setState()`-triggering listener to the text
controller) rather than a new architectural milestone.

**DO NOT START R46 in this session — per this specification's own stop
condition, wait for external architectural review.**
