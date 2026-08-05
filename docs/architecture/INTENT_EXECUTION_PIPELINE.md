# Intent Execution Pipeline — Implementation Specification IS-R37

## REALITY

R37's own brief describes a gap: "the remaining architectural gap is production intent execution." Investigated directly (grep + full source reads) before writing any code.

`AppComposition` (R1, extended R36) already composes the complete R31-R36 "AI Operating System" service graph — `ExperienceCreationCoordinator` → `EngineeringLifecycleCoordinator` → `IntentSessionManager` → `ExperienceWorkspaceManager` → `UniversalIntentRouter`/`AutonomousWorkspaceRuntime`; `EventBus` → `WorkspaceEventPublisher` — all real, all tested, all reachable from one composition root.

But the ONE real, live production intent-entry point in the whole app, `HomeScreen._createExperience()` (`lib/features/home/home_screen.dart`), still bypassed `UniversalIntentRouter` entirely:

```dart
final result = await _coordinator.createFromIntent(intent);
```

where `_coordinator` was `_composition.experienceCreationCoordinator` (R36). This meant the real production creation flow never registered its session in `ExperienceWorkspaceManager` — despite R32-R36 wiring `workspaceManager`/`intentRouter`/`workspaceRuntime`/`eventBus` as optional `HomeScreen` fields, none of them were actually invoked by the real creation call; every one was accept-and-store-only since R32. This was R36's own final, explicit recommendation for R37.

`lib/runtime/experience_host_screen.dart` has its own, separate, pre-existing `ExperienceModificationCoordinator` (predates R30 — a different real class from `EngineeringLifecycleCoordinator`) handling in-runtime modification once already inside an open Experience. Investigated and deliberately left alone — see "Out of scope" below.

## PROPOSED / RATIONALE

Give `HomeScreen` ONE thing to call instead of the coordinator directly: a thin, real composition over the two already-real services that make up "intent execution" — `UniversalIntentRouter` (R33, decides which workspace method to invoke) and `WorkspaceEventPublisher` (R35, translates the result into a real event). No new decision layer, no new result type — `RoutingResult` (already real, already typed, already returned by `UniversalIntentRouter.route()`) IS the typed execution result this specification asks for.

## IMPLEMENTATION

`lib/app/intent_execution_pipeline.dart` (new):

```dart
class IntentExecutionPipeline {
  final UniversalIntentRouter _router;
  final WorkspaceEventPublisher _eventPublisher;

  const IntentExecutionPipeline({required UniversalIntentRouter router, required WorkspaceEventPublisher eventPublisher})
    : _router = router, _eventPublisher = eventPublisher;

  Future<RoutingResult> execute(Intent intent, {RouteTarget? target, String? correlationId}) async {
    final result = await _router.route(intent, target: target);
    _eventPublisher.publishIntentRouted(result, correlationId: correlationId);
    return result;
  }
}
```

`lib/app/app_composition.dart` — extended additively with one new field, `intentExecutionPipeline`, constructed after `intentRouter`/`eventPublisher` (the two it depends on) in `AppComposition.production()`'s real dependency order.

## INTENT EXECUTION PIPELINE

```
User Intent
  -> IntentExecutionPipeline.execute(intent, target)
       -> UniversalIntentRouter.route(intent, target)      (R33, unchanged)
            -> ExperienceWorkspaceManager.openExperience()/continueExperience()  (R32, unchanged)
                 -> IntentSessionManager.startSession()/continueSession()        (R31, unchanged)
                      -> ExperienceCreationCoordinator.createFromIntent()        (unchanged)
                         or EngineeringLifecycleCoordinator.evolveExperience()   (R30, unchanged)
                           -> AnythingKernel.processIntent()                     (the ONE reasoning call)
       -> WorkspaceEventPublisher.publishIntentRouted(result)  (R35, unchanged)
  -> RoutingResult (real, typed, unmodified) returned to the caller
```

Every step below `IntentExecutionPipeline` is byte-for-byte the same real chain R31-R36 already built and tested — this milestone adds nothing to it except the ONE canonical entry point above it.

## PRODUCTION FLOW

`lib/features/home/home_screen.dart`:

Before:
```dart
_coordinator = _composition.experienceCreationCoordinator;
...
final result = await _coordinator.createFromIntent(intent);
```

After:
```dart
_pipeline = widget.pipeline ?? _composition.intentExecutionPipeline;
...
final routingResult = await _pipeline.execute(intent, target: const RouteTarget.newExperience());
final result = routingResult.creationResult!;
```

The rest of `_createExperience()`'s switch on `result` (`CreationCreated`/`CreationOpened`/`CreationFailed`/`CreationProviderRequired`) is unchanged — only the one line producing `result` changed. The now-dead `ExperienceCreationCoordinator _coordinator` field was removed entirely (confirmed, by grep, to have had no other reference in the file).

**Why `RouteTarget.newExperience()`, not `target: null`:** passing `null` would let `route()` fall back to "continue the active session if one exists" once a session becomes active from an earlier submission — this would silently change `HomeScreen`'s existing UX contract (every text submission on Home today independently creates a new experience and shows the birth sequence; there is no existing UI affordance on Home for "continue"). `RouteTarget.newExperience()` preserves that exact contract explicitly and structurally — a real, honest UI-level signal, never inferred from intent text, matching `UniversalIntentRouter`'s own documented "never semantic interpretation" rule. Because `route()`'s `forceNew` branch unconditionally calls `ExperienceWorkspaceManager.openExperience(intent)` → `IntentSessionManager.startSession(intent)` → `ExperienceCreationCoordinator.createFromIntent(intent)` — the exact same real call `HomeScreen` made before — `routingResult.creationResult` is guaranteed non-null on this path and is literally the same `CreationResult` the existing switch-statement already handles. This is a behavior-preserving change for every existing test and the real UI, with one genuine new side effect: the session is, for the first time in production, registered in `ExperienceWorkspaceManager`.

## UI DECOUPLING

`HomeScreen` no longer imports/constructs `ExperienceCreationCoordinator` for its real creation flow — the ONE thing it now calls to get engineering work done is `_pipeline.execute()`. (It still imports `creation_coordinator.dart` for the `CreationResult`/`CreationCreated`/`CreationOpened`/`CreationFailed`/`CreationProviderRequired` result TYPES its birth-sequence UI switches on — that is response handling, not engineering execution ownership.) `UniversalIntentRouter` is now genuinely the live production decision point: every real intent submitted from Home reaches it, not just tests. `AnythingKernel` remains the only reasoning boundary — zero new LLM/reasoning calls anywhere in this milestone's diff.

`HomeScreen`'s own public constructor gained one new optional, additive, defaulted-`null` field (`pipeline`) — byte-for-byte unchanged otherwise, matching R32-R36's established pattern exactly.

## OUT OF SCOPE (investigated, documented honestly)

`lib/runtime/experience_host_screen.dart`'s `ExperienceModificationCoordinator`-based in-runtime modification flow (`_showModificationIntent()` and related call sites) was deliberately left untouched. It is a distinct, canonical, pre-R30 subsystem for modifying an Experience once its runtime is already live — not a duplicate of anything this milestone builds, and not the "production intent entry point bypassing the router" this specification's own investigation section asks to find and fix (that gap was `HomeScreen._createExperience()` alone). Rerouting it would be exactly the kind of live UI rewrite a background agent cannot safely make without interactive testing — the same reasoning `IntentSessionManager`'s (R31) own doc comment already gave for deferring `HomeScreen`/`ExperienceHostScreen` rewiring in the first place.

## TEST RESULTS

`test/r37_intent_execution_pipeline_test.dart` (new) proves, with real objects (never mocks of the subsystems under test):

- **Creation routing**: `pipeline.execute(intent, target: RouteTarget.newExperience())` reaches `ExperienceCreationCoordinator.createFromIntent()` (via an injected fake reasoner producing `CreationCreated`) and registers the session in the real `ExperienceWorkspaceManager` — the real regression fix over the pre-R37 bypass.
- **Modification routing**: `RouteTarget.session(...)` against the already-active session reaches `EngineeringLifecycleCoordinator.evolveExperience()` via `modifyActiveExperience`.
- **Continuation routing**: `RouteTarget.experience(...)` naming a real, open-but-not-active session (after a real, explicit `switchActiveExperience()` — see the note below) reaches `EngineeringLifecycleCoordinator` via `resumeBackgroundSession`.
- **Pipeline execution**: a real `IntentRouted` event is published to the real `EventBus` for every `execute()` call, `correlationId` forwarded unmodified.
- **UI decoupling**: a widget test drives `HomeScreen`'s real, live `_createExperience()` flow (via the existing "Calculator" quick-action chip) with an injected pipeline/workspace and proves the resulting session lands in `workspaceManager.openSessionIds` — the live-widget-path proof, not just the pipeline in isolation.
- **Regression**: `UniversalIntentRouter`/`ExperienceWorkspaceManager`/`EngineeringLifecycleCoordinator` called directly, bypassing the pipeline entirely, behave exactly as R33/R32/R30 built them.
- **Backward compatibility**: `HomeScreen()` constructed with none of its now-6 optional fields still defaults every one to `null` and never throws; a bare, un-injected `HomeScreen()` pumped still resolves its pipeline from `AppComposition.production()` and renders without throwing.
- **Performance**: real `Stopwatch` measurements for `execute()` latency and `AppComposition.production()` construction with the new field.

**Real, honest finding surfaced while writing these tests**: `ExperienceWorkspaceManager.openExperience()` uses `_activeSessionId ??= result.sessionId` (real, unmodified R32 code) — opening a second experience never steals active focus from the first. The Continuation-routing test therefore performs a real, explicit `switchActiveExperience()` before targeting the now-background first session, mirroring `test/r33_universal_intent_router_test.dart`'s own "Resume background session" group exactly (this is pre-existing R32/R33 behavior, unaffected by R37 — not a new finding about this milestone's own code).

## PERFORMANCE

Real `Stopwatch` measurements — see `test/r37_intent_execution_pipeline_test.dart`'s own "Performance" group for `pipeline.execute()` routing/pipeline latency and `AppComposition.production()` construction latency with the new field. `IntentExecutionPipeline.execute()` adds one synchronous event-publish call on top of the router's own already-measured (R33) latency — no new I/O, no new reasoning call.

## KNOWN LIMITATIONS

- `ExperienceHostScreen`'s own in-runtime modification flow (`ExperienceModificationCoordinator`) is not routed through this pipeline — see "Out of scope" above.
- `HomeScreen` always passes `RouteTarget.newExperience()` — the router's `continueActiveSession`/`modifyActiveExperience`/`resumeBackgroundSession` vocabulary is proven correct and reachable (via this milestone's own tests) but has no live UI caller yet, matching the "decide never invoke, tests are the caller" precedent this project has used since R29/R33 for unwired paths.
- No correlation across a full user action (route → continue → lifecycle-complete → deployment-decision) is wired from `HomeScreen` today — `correlationId` is a real, honored parameter on `execute()`, unused by the one real production call site.

## RECOMMENDATION FOR R38

`HomeScreen`'s "Recent" list currently reopens an existing Experience via the separate, trusted `ExperienceOpeningCoordinator` — unrelated to intent execution, out of this milestone's scope. A natural next step: give `ExperienceHostScreen`'s in-runtime modification flow a real, explicit `RouteTarget` (session-scoped) so it, too, can reach `EngineeringLifecycleCoordinator` through the same canonical `IntentExecutionPipeline` rather than its separate, pre-existing `ExperienceModificationCoordinator` path — evaluated carefully, since `ExperienceModificationCoordinator` and `EngineeringLifecycleCoordinator` are not proven behaviorally identical and any such change would need the same interactive-testing caution R31 already documented for live UI rewrites.
