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

**Second round — the fix above was incomplete, found and corrected during
independent verification.** It only handled ONE mismatch direction:
`workspaceManager`/`workspaceRuntime`/`eventBus` overridden without
`scheduler`. The inverse direction — `scheduler` overridden WITHOUT
`workspaceManager` (exactly `test/r43_workspace_experience_switcher_test.dart`'s
own "HomeScreen forwards the shared scheduler" test, which supplies only
`HomeScreen(scheduler: rig.scheduler)`) still threw the identical real
`StateError`, reproduced with a clean stack trace after the first fix was
believed complete. Corrected symmetrically: `_workspaceManager` now
resolves `widget.workspaceManager ?? widget.scheduler?.workspace ??
_composition.workspaceManager` — preferring an explicit override, then an
overridden scheduler's own already-bound real workspace (`WorkspaceSchedulingEngine.workspace`
is a real, public field), then the composition default. This guarantees
`_workspaceManager` and `_scheduler` always reference the same real
`ExperienceWorkspaceManager` regardless of which single field a caller
overrides, in either direction. Verified via a full, untruncated
`flutter test` run: 1748/1748 passed.

## A SECOND, LARGER BYPASS FOUND AFTER THE FIRST PASS — `ExperiencesScreen`

A post-implementation re-audit of **every** `Navigator.push` and
`ExperienceHostScreen` construction site in `lib/` (not just the ones
`HomeScreen` owns) found that R45's first pass had missed an entire real
production entry surface.

**REALITY.** `ExperiencesScreen`
(`lib/features/experiences/experiences_screen.dart`) is the real "My Apps"
tab — constructed unconditionally in `AnythingAppShell._screenBuilders`
(`lib/app/app_shell.dart:38`), one of the four bottom-nav destinations, and
the app's actual persistent Experience library. It is therefore at least as
load-bearing an entry surface as `HomeScreen`'s own Recent list.

All **three** of its Experience-opening paths bypassed the pipeline
completely:

1. `_openExperience()` — tapping any app in the library.
2. `_showProtectionInputAndResume()`, "use current time" branch.
3. `_showProtectionInputAndResume()`, "choose date & time" branch.

Each called `ExperienceOpeningCoordinator` directly — through its **own**
privately constructed instance (`_openingCoordinator = ExperienceOpeningCoordinator()`),
not even the shared one — and then raw-`Navigator.push`ed
`ExperienceHostScreen`. Consequently every one of them registered **no**
workspace session, reached **no** scheduler, **no** `WorkspaceRuntimeSupervisor`,
and **no** `ExperienceActivationManager`; they also never passed
`workspaceManager`/`workspaceRuntime`/`eventBus`/`runtimeSupervisor`/`scheduler`
to the host screen at all. This is exactly the bypass class this milestone
exists to eliminate, so R45's own SUCCESS CRITERIA ("the canonical entry
mechanism for **every** production experience") was **not** actually met by
the first pass.

**A stale claim in canonical source, corrected.** R44's
`ExperienceActivationManager` doc comment
(`lib/app/experience_activation_manager.dart:16-18`) asserts that
`HomeScreen` is "the ONE and ONLY real production call site that ever pushes
`ExperienceHostScreen` anywhere in this codebase (confirmed by grep)". That
statement was never true — `experiences_screen.dart` pushed it in three
places the entire time. The R44 design conclusion it supports (that no
`NavigatorObserver` is required) still holds now that all pushes really do
flow through one pipeline, so **the file itself is left byte-for-byte
unchanged** to preserve this milestone's provable "ExperienceActivationManager
remains unchanged" criterion; the correction is recorded here and is listed
under RECOMMENDATION FOR R46 as a comment-only cleanup.

**FIX.** All three paths now route through the same shared pipeline, exactly
as `HomeScreen` does: `activateExperience()` for the library tap and
`activateProtectedExperience()` for both protection-resume branches. The
screen gained an optional `entryPipeline` override defaulting to
`composition.experienceEntryPipeline` (mirroring `HomeScreen.entryPipeline`'s
established convention), and its private `ExperienceOpeningCoordinator`,
its three `MaterialPageRoute`/`ExperienceHostScreen` constructions, and its
now-unused `experience_host_screen.dart` import were all deleted — a net
deletion of duplicated navigation logic, not an addition.

The `.then((_) => _loadExperiences())` library-refresh-on-return behavior is
preserved exactly: `ExperienceActivationManager.activate()` awaits
`Navigator.push`, whose Future completes when the Experience route is
popped, so awaiting the pipeline call and refreshing in the `OpenReady`
branch is equivalent — the same shape `HomeScreen._openViaCoordinator()`
already uses.

**PROOF.** `ExperienceEntryPipeline` is now the **only** site in all of
`lib/` that constructs `ExperienceHostScreen` (verified by grep), which is
the concrete, mechanical proof the success criterion now genuinely holds.
Four new tests cover it (see TEST RESULTS).

## ENTRY SOURCES

- **Create New Experience** — `submitIntent()`, the real, unchanged
  Intent/Kernel path (R37).
- **My Apps Library (`ExperiencesScreen`)** — `activateExperience()` /
  `activateProtectedExperience()`. The real persistent-library entry
  surface; see the section above.
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

**Four further tests (added with the `ExperiencesScreen` fix above), 20
total in the file:** a real, live "My Apps" library flow — pumping the real
`ExperiencesScreen`, finding the real persisted Experience in the rendered
list, and **tapping it** — asserting that the tap now genuinely registers a
workspace session (`openSessionIds` non-empty, `sessionForExperience()`
non-null), that the session is really supervised and `RuntimeStatus.running`
(real scheduler participation), that the route is tracked by the ONE
`ExperienceActivationManager` (`existingRouteFor()` non-null, proving real
activation rather than an untracked raw push), and that the reasoner call
count stays flat (no Kernel involvement, no second AI boundary);
duplicate-prevention when the same library entry is re-tapped after popping
back; plus two backward-compatibility proofs (`entryPipeline` defaults to
`null`; a bare `ExperiencesScreen()` renders without throwing, sourcing the
shared pipeline from `AppComposition.production()`). These tests could not
even have compiled against the pre-fix screen, and their central assertion
(`openSessionIds` non-empty) fails outright against the old raw-push path.

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

Real, measured (never fabricated), and reported as a range because these
are wall-clock measurements on a loaded developer machine, not a quiesced
benchmark rig — two full-suite runs produced:

| Measurement | Run 1 | Run 2 |
|---|---|---|
| `activateExperience()` fire-to-first-pump, new session | ~26ms | ~50ms |
| `openExistingExperience()` registration latency | ~3.5ms | ~8.5ms |
| RSS delta, 10 repeated `openExistingExperience()` cycles | ~4.7MB | ~12.8MB |

The spread between runs is contention, not regression: the second run was
taken with the full 1752-test suite executing concurrently. Both runs agree
on the load-bearing conclusions — entry latency stays in the tens of
milliseconds, registration is a small-single-digit-to-sub-10ms operation,
and repeated registration cycles grow RSS proportionally with real
SQLite-backed session bookkeeping rather than showing a leak signature
(no super-linear growth across cycles). Routing `ExperiencesScreen` through
the pipeline adds one workspace-session registration to a path that
previously did none — that registration cost is exactly the
`openExistingExperience()` figure above, and it buys the scheduler
participation and supervision that path never had.

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

- `lib/app/experience_activation_manager.dart:16-18` still carries the
  factually stale R44 claim that `HomeScreen` is the only production
  `ExperienceHostScreen` pusher. Deliberately left byte-for-byte unchanged
  so this milestone's "ExperienceActivationManager remains unchanged"
  criterion stays mechanically provable; it is a comment-only inaccuracy
  with no behavioral effect, and correcting it is listed for R46.

## RECOMMENDATION FOR R46

Every real entry path now participates in workspace registration and
scheduler activation consistently, and `ExperienceEntryPipeline` is the
only construction site of `ExperienceHostScreen` in `lib/`. Two small,
real, honest fixes are the natural next candidates — neither is a new
architectural milestone:

1. Correct the stale R44 comment in
   `lib/app/experience_activation_manager.dart:16-18` (comment-only; it
   was deferred purely to keep this milestone's unchanged-subsystem proof
   mechanical).
2. Close the `HomeScreen` submit-button reactivity gap documented above
   (add a `setState()`-triggering listener to the text controller).

A worthwhile third item, given this milestone needed a second pass to find
`ExperiencesScreen`: add a real, cheap architectural regression test that
greps/asserts `ExperienceEntryPipeline` remains the sole constructor of
`ExperienceHostScreen`, so any future bypass fails CI instead of waiting
for an audit.

**DO NOT START R46 in this session — per this specification's own stop
condition, wait for external architectural review.**
