# Operating System Composition Root — Implementation Specification IS-R36

## REALITY

Before R36, `AppComposition` (`lib/app/app_composition.dart`, R1) held
`experienceRepository`/`worldModel`/`providerRegistry`/`credentialVault`/
`capabilityPlatform`/`knowledgeEngine`/`softwareCognition`/
`runtimeIntelligence`/`kernel`/`engineeringMemory` — never
`ExperienceCreationCoordinator`, `EngineeringLifecycleCoordinator` (R30),
`IntentSessionManager` (R31), `ExperienceWorkspaceManager` (R32),
`UniversalIntentRouter` (R33), `AutonomousWorkspaceRuntime` (R34),
`EventBus`, or `WorkspaceEventPublisher` (R35). Confirmed by reading
`lib/app/app_composition.dart` in full before writing any code.

Sharper finding: `HomeScreen.initState()` (`lib/features/home/home_screen.dart`)
constructed its own, **local, disconnected** `ExperienceCreationCoordinator`:

```dart
_coordinator = ExperienceCreationCoordinator(
  kernel: _composition.kernel,
  worldModel: _composition.worldModel,
  softwareCognition: _composition.softwareCognition,
  engineeringMemory: _composition.engineeringMemory,
);
```

This is the exact "independently constructed, disconnected graph" problem
R1 itself originally fixed for `WorldModelCoordinator` (two separate
instances — one inside `HomeScreen`'s old Kernel construction, one inside
`ExperienceModificationCoordinator`'s default). R36 is that same fix,
applied to `ExperienceCreationCoordinator`.

Every one of R32/R33/R34/R35's optional constructor parameters on
`HomeScreen`/`ExperienceHostScreen` (`workspaceManager`/`intentRouter`/
`workspaceRuntime`/`eventBus`) were, until R36, **always `null`** in the
real, running production app — each milestone's own "accept-and-store"
scope decision, confirmed by grep (no non-test call site ever supplied
them).

## PROPOSED / RATIONALE

Extend `AppComposition` additively with the 8 R31-R35 services, in real
dependency order, reusing the SAME `ExperienceCreationCoordinator` this
milestone moves. Compose `EngineeringLifecycleCoordinator` (newly given a
shared composition-root instance — it never had one before) alongside it
into `IntentSessionManager`, then `ExperienceWorkspaceManager`, then
`UniversalIntentRouter`/`AutonomousWorkspaceRuntime` (independent siblings,
both depending only on the workspace), and independently `EventBus` ->
`WorkspaceEventPublisher`. Move `HomeScreen`'s coordinator construction
into `AppComposition.production()`; wire the existing optional parameters
at `HomeScreen`'s real `ExperienceHostScreen` navigation call sites. No new
composition root, no second Kernel/Workspace/Runtime/EventBus/DI framework
— every one of R32-R35's own coordinators is composed, never modified
(confirmed unchanged via `git diff --stat`).

## SERVICE GRAPH

Real, explicit construction order inside `AppComposition.production()`
(`lib/app/app_composition.dart`):

```
experienceRepository, credentialVault, providerRegistry
  -> worldModel
  -> knowledgeEngine
  -> capabilityPlatform (registers clock/http/ai/knowledge/notification/file)
  -> softwareCognition
  -> kernel (providerRegistry, knowledgeEngine, worldModel, softwareCognition)
  -> engineeringMemory (experienceRepository)
  -> experienceCreationCoordinator (kernel, worldModel, softwareCognition, engineeringMemory)
  -> engineeringLifecycleCoordinator (kernel, engineeringMemory)
  -> intentSessionManager (experienceCreationCoordinator, engineeringLifecycleCoordinator, engineeringMemory)
  -> workspaceManager (intentSessionManager)
       -> intentRouter (workspaceManager)
       -> workspaceRuntime (workspaceManager)
  -> eventBus
  -> eventPublisher (eventBus)
```

`intentRouter`/`workspaceRuntime` are independent siblings (both depend
only on `workspaceManager`, not on each other). `eventBus`/`eventPublisher`
are a fully independent chain — nothing above depends on them, and they
depend on nothing above. This is real dependency order, not a fabricated
diagram: `AppComposition.production()`'s own local-variable sequence
enforces it — Dart itself would fail to compile a reference to a
not-yet-declared `final` local.

`experienceCreationCoordinator` is constructed with the EXACT same 4 named
arguments `HomeScreen.initState()` used to pass locally — the relocation
changes WHERE the call happens, never its shape.

## HomeScreen / ExperienceHostScreen wiring

`HomeScreen`'s own public constructor is byte-for-byte unchanged. Inside
`initState()`:

```dart
_coordinator = _composition.experienceCreationCoordinator;
_workspaceManager = widget.workspaceManager ?? _composition.workspaceManager;
_intentRouter = widget.intentRouter ?? _composition.intentRouter;
_workspaceRuntime = widget.workspaceRuntime ?? _composition.workspaceRuntime;
_eventBus = widget.eventBus ?? _composition.eventBus;
```

A caller-supplied `widget.X` still wins (preserves every existing test's
ability to inject a double); otherwise the real, shared `AppComposition`
instance is used — for the first time, a NON-null, real, shared instance
by default, not always `null` as before R36.

`_workspaceManager`/`_workspaceRuntime`/`_eventBus` are threaded into
`ExperienceHostScreen` at its three real construction call sites inside
`HomeScreen` (`_openViaCoordinator` and both branches of
`_showProtectionInputAndResume`) — every real navigation path, not just
one. `_intentRouter` has no matching `ExperienceHostScreen` parameter
(none exists — R33's own, still-honest "no analogous safe wiring point
beyond accept-and-store" finding, unchanged by R36); it is exposed via a
real `intentRouterInUse` getter on `HomeScreenState` for identity/DI
tests and future callers, since a private field with no reader would be
dead code.

`ExperienceHostScreen`'s own public constructor is unchanged — R32/R34/R35
already gave it `workspaceManager`/`workspaceRuntime`/`eventBus`; R36
changes only WHERE the real values threaded into them come from.

## DEPENDENCY LIFETIMES

Honest analysis of this codebase's REAL lifetime shapes, not aspirational
ones:

| Type | Lifetime | Real evidence |
|---|---|---|
| `AppComposition` and everything inside it (`kernel`, `worldModel`, `workspaceManager`, `intentRouter`, `workspaceRuntime`, `eventBus`, `eventPublisher`, coordinators) | **Application Singleton** | Constructed exactly once by `AnythingAppShell`, held as `final` fields, never reconstructed for the life of the process. |
| `ExperienceWorkspaceManager` ("Workspace Lifetime") | **Same lifetime as Application Singleton** | This codebase has exactly ONE workspace per running process — no multi-workspace concept exists anywhere (confirmed by reading `lib/app/experience_workspace_manager.dart` in full: it is constructed once, holds one `_openSessionIds` list, has no "create a new workspace" factory). "Workspace Lifetime" and "Application Singleton" are, honestly, the SAME lifetime today — stated plainly rather than inventing a distinction the code does not have. |
| `SessionState` (R31) | **Session lifetime** | Created per `IntentSessionManager.startSession()` call, held in `_sessions` (a `Map<String, SessionState>`) for the life of the app process — no explicit `endSession()`/destroy method exists (confirmed by reading `lib/app/intent_session_manager.dart` in full). Stated honestly as a real, current limitation, not papered over: a long-running process accumulates `SessionState` entries with no eviction. |
| `LifecycleResult` / `RoutingResult` / `SessionStartResult` / `SessionContinueResult` / `WorkspaceRuntimeSnapshot` | **Request lifetime** | Each is a fresh, immutable value returned by exactly one real call (`evolveExperience()`, `route()`, `startSession()`, `continueSession()`, `captureRuntimeState()`) — never cached or reused across calls, referenced only by the caller that received it (and, for `LifecycleResult`, retained as `SessionState.currentLifecycleResult`, a real, single most-recent copy, never a history). |
| `Intent` / `RouteTarget` | **Ephemeral** | Constructed by a caller for one call, discarded immediately after — never stored beyond the call that used it (`RouteTarget` is not even held by `RoutingResult`). |

**No new DI framework, service-locator, or scoping abstraction was
introduced** — every lifetime above already existed as a real, observable
property of the existing code; this table documents it, it does not
invent a new mechanism to enforce it. This codebase has never used a DI
framework and R36 does not start now (Principal Architect Mode Rule 2: no
parallel architecture).

## BEHAVIOR PRESERVATION PROOF

`test/r36_operating_system_composition_test.dart`'s "ExperienceCreationCoordinator
relocation" group constructs a coordinator with the exact 4-argument shape
`AppComposition.production()` now uses (shared `worldModel`/
`engineeringMemory`, matching the pre-R36 `HomeScreen`-local shape byte for
byte) and proves a successful creation still ingests into the SAME shared
`worldModel`/`engineeringMemory` instances it was given, and that
engineering-memory persistence (R5) still runs — the relocation changed
WHERE the coordinator is built, never HOW it behaves once built.

## SINGLETON / EVENTBUS SHARING PROOF

`AppComposition.production()` is exercised directly (never faked — see
this file's own "Dependency Injection" note below for why that is safe
without a real AI provider configured): a real `intentRouter.route()` call
opens a session, and the SAME `workspaceManager`/`workspaceRuntime`
observe it through their own real, independent read paths — proving they
share the ONE `ExperienceWorkspaceManager` instance, not private copies.
A real `IntentRouted` event published via `eventPublisher` is received by
a subscriber obtained via `eventBus.on<IntentRouted>()` — two independent
access paths through the SAME composition, the same "genuinely shared
singleton" proof R1 established for `WorldModelCoordinator`.

**Why this is safe without network**: with no AI provider ever
configured/saved in a test's `CredentialVault`,
`AnythingProviderRegistry.activeProvider` is real, honestly `null`.
`AnythingKernel.processIntent()`'s own Step 5 (the ONE mandatory
reasoning call, per this project's AI boundary) detects this locally and
returns `ReasoningProviderRequired` -> `ProviderRequired` before any
network/LLM call — a real, deterministic, offline outcome, not a
fabricated network-free assumption. `ExperienceWorkspaceManager.openExperience()`
still tracks the session as "open" regardless of the coordinator's
outcome (R32's own, unmodified contract) — enough to prove real sharing
without a real provider.

## TEST RESULTS

`test/r36_operating_system_composition_test.dart` — 14 new tests, all
passing:

- Service graph correctness: `AppComposition.production()` constructs the
  full 8-field R31-R35 graph without throwing.
- Singleton lifetime: `workspaceManager`/`intentRouter`/`workspaceRuntime`
  observably share the SAME workspace.
- EventBus sharing: a real event crosses two independent access paths.
- Workspace lifetime: `composition.workspaceManager` is identical across
  reads (Application Singleton, per the table above).
- Dependency injection: an injected fake kernel/reasoner is the one
  actually used end-to-end through `IntentSessionManager` ->
  `ExperienceWorkspaceManager` -> `UniversalIntentRouter`, never silently
  replaced.
- `ExperienceCreationCoordinator` relocation: behavior preservation proof
  (above).
- Regression: `ExperienceWorkspaceManager`/`EngineeringLifecycleCoordinator`
  called directly, bypassing `AppComposition` entirely, behave exactly as
  R32/R30 built them.
- Backward compatibility: `HomeScreen()`/`ExperienceHostScreen()`
  constructed bare still default every optional field to `null`
  (constructors byte-for-byte unchanged); a bare `HomeScreen()` pumped
  with no injected composition renders without throwing, now sourcing its
  coordinator from the extended `AppComposition.production()`; a real,
  end-to-end widget test proves `HomeScreen` forwards its resolved
  `workspaceManager`/`workspaceRuntime`/`eventBus` into a real, pushed
  `ExperienceHostScreen` at its real navigation call site.
- Performance: real `Stopwatch`/`ProcessInfo.currentRss` measurements
  (below).

Full regression suite (`flutter test`) re-run at least twice — see
`Anything_R36_Validation_Report.txt` for the exact counts. `flutter
analyze`: 71/0, unchanged baseline.

## PERFORMANCE

Real, measured (never fabricated):

- `AppComposition.production()` full graph construction (10 services,
  including the new 8): well under 1ms (microsecond range) — every new
  service is a plain, synchronous object construction; no I/O happens
  until a repository method or Kernel reasoning call is actually invoked.
- Memory: no measurable RSS growth across 10 repeated
  `AppComposition.production()` construct/close cycles.

## KNOWN LIMITATIONS

- `intentRouter` has no forwarding point into `ExperienceHostScreen`
  (none exists to forward it to) — exposed via `HomeScreenState
  .intentRouterInUse` for tests/future callers; still real,
  accept-and-store scope for the UI itself, matching R33's own honest
  limitation.
- `SessionState` accumulates for the life of the process with no eviction
  (see the lifetime table above) — a real, pre-existing R31 property,
  unchanged by R36, worth a future milestone's attention if long-running
  sessions become a real concern.
- `HomeScreen`'s own `_repository`/`AppComposition.production()`'s
  `experienceRepository` are never closed on `dispose()` — a real,
  pre-existing property of this widget (unrelated to R36's own change),
  observed while writing this milestone's own widget tests.

## RECOMMENDATION FOR R37

Every "AI Operating System" service (R31-R36) is now real, tested, and
reachable from the ONE shared composition root — with `HomeScreen`'s own
creation flow still calling `_coordinator`/`ExperienceCreationCoordinator`
directly rather than routing through `UniversalIntentRouter`. A natural
next milestone: reroute `HomeScreen._createExperience()`'s real
intent-submission handler through `_intentRouter.route()` instead, now
that the router is a real, shared, always-non-null singleton — the first
milestone that would make `UniversalIntentRouter` (R33) an actual,
live decision point in the running app rather than an available-but-unused
service.
