# Workspace Event Bus — Implementation Specification IS-R35

## REALITY

R35's own brief reads as if "Workspace Event Bus" is a new concept. It is
not — confirmed by reading `lib/core/events/events.dart` before writing
any code. A complete, real, typed pub/sub `EventBus`/`AnythingEvent`
system (11 subtypes, `test/contracts/events_test.dart`, 3 passing tests)
already existed, dating to a "Stage 9.4"-era commit (`6e24e9d`, found via
`git log --follow`). It had **zero production callers** anywhere in
`lib/` — confirmed by `grep -rln "EventBus("` and `grep -rln
"events.dart"` (excluding the file itself), both empty. This is the same
"real, tested, orphaned subsystem" pattern R14 (`SoftwareCognitionCoordinator`),
R16 (`SemanticApp.knowledgeNeeds`), and R30 (`SolutionEvolutionEngine`)
each found and wired in. R35 is that wiring for this file — never a
second event/notification system.

## A real, load-bearing bug found and fixed

The original `EventBus.on<T>()` stored one `StreamController` PER
SUBSCRIBED TYPE in a `Map<Type, StreamController<AnythingEvent>>`. Every
call to `on<T>()` for the SAME `T` overwrote the previous controller for
that type, so a second subscriber to the same event type silently
disconnected the first — `publish()` only ever reached whichever
controller was registered last. This broke exactly the multi-consumer
case R35 requires ("Workspace Runtime, Notifications, Future UI...
subscribe without direct coupling").

Fix: one shared `StreamController<AnythingEvent>.broadcast()`; `on<T>()`
returns a real, independent filtered view of it (`.where((e) => e is
T).cast<T>()`) per call. Any number of subscribers, of any mix of types,
now each receive every event meant for them, correctly. Proven directly
in `test/r35_workspace_event_bus_test.dart` ("two independent subscribers
to the same type both receive the same event") and confirmed the
pre-existing 3 tests in `test/contracts/events_test.dart` still pass
unmodified — full backward compatibility.

## "Remain unchanged. Publish N events." — resolved the same way as R31-R34

Every prior milestone that needed a new coordinator to observe an
"unchanged" subsystem solved it with a new, small, composing/translating
class rather than modifying the protected type. R35 does the same:
`WorkspaceEventPublisher` (`lib/app/workspace_event_publisher.dart`) is
pure translation from already-real R30-R34 result types
(`RoutingResult`, `SessionStartResult`, `SessionContinueResult`,
`WorkspaceRuntimeSnapshot`) into the new `AnythingEvent` subtypes below.
It is never invoked automatically by any coordinator — a caller invokes
the real coordinator method AND the matching publisher method together,
e.g. `final result = await workspace.openExperience(intent);
publisher.publishSessionCreated(result);`.

Confirmed via `git diff --stat` on `experience_workspace_manager.dart`,
`universal_intent_router.dart`, `intent_session_manager.dart`,
`engineering_lifecycle_coordinator.dart`, `autonomous_workspace_runtime.dart`,
`anything_runtime.dart`, World Model, and Engineering Memory — all
completely untouched.

## Event model

`AnythingEvent`'s base fields gained four real, additive, DEFAULTED
fields, so all 11 pre-existing subtype constructors needed zero changes:

```dart
final EventCategory eventCategory; // defaults EventCategory.general
final EventSeverity severity;      // defaults EventSeverity.info
final String? correlationId;
final Map<String, dynamic>? payload;
```

Named `eventCategory`, not `category` — `IntentAnalyzed.category` (a
pre-existing `String`, its own intent-classification concept) already
used that name; `flutter analyze` caught the collision as an
`invalid_override` before this file was finished.

`correlationId` links every event from one real user action (route ->
session-continue -> lifecycle-complete -> deployment-decision) — proven
in the "route -> continue chain shares correlationId" test.
`payload` is a real, named, currently-unused extension point (every R35
subtype already carries its data as typed fields).

## The 12 events

| Event | Source data | Category |
|---|---|---|
| `IntentRouted` | `RoutingResult` (R33) | intent |
| `SessionCreated` | `SessionStartResult` (R31) | session |
| `SessionContinued` | `SessionContinueResult` (R31) | session |
| `SessionSwitched` | caller-supplied session id | session |
| `WorkspaceUpdated` | caller-supplied change description | workspace |
| `RuntimeSnapshotCaptured` | `WorkspaceRuntimeSnapshot` (R34) | runtime |
| `LifecycleCompleted` | `LifecycleResult.outcome` (R30) | lifecycle |
| `ArtifactUpdated` | `LifecycleResult.artifactIntelligenceReport` (R28) | artifact |
| `DeploymentAllowed` | `LifecycleOutcome.deployed` | deployment (warning: no) |
| `DeploymentBlocked` | `LifecycleOutcome.blocked` | deployment, **severity: warning** |
| `CommitFailed` | `LifecycleOutcome.commitFailed` | deployment, **severity: error** |
| `NotificationGenerated` | `WorkspaceNotification` (R34) | notification |

`RoutingAction`/`LifecycleOutcome` enum names are carried as plain
`String` (`.name`), not the real enum types — `lib/core/events/` never
imports `lib/app/`, matching this codebase's established layering.

`publishSessionContinued()` publishes `DeploymentAllowed`/
`DeploymentBlocked`/`CommitFailed` only for their own matching terminal
`LifecycleOutcome` — `noChangeDetected`/`noActionableTarget`/
`noEngineeringMemory`/`cannotEvolve` publish neither, matching R34's own
"honest terminal-outcome-only" notification rule. Proven in the
"terminal-outcome-only" test.

## UI integration

`HomeScreen` and `ExperienceHostScreen` each gain one new, optional,
nullable, defaulted constructor parameter: `EventBus? eventBus`. Both
default to `null` — every existing construction path and test is
byte-for-byte unaffected.

`ExperienceHostScreen` takes one real extra step, the same precedent R32
established for `workspaceManager.reportRuntimeStateForExperience()`:
once a real experience finishes loading, it publishes one real
`WorkspaceUpdated('runtime_loaded', sessionId)` event via a fresh
`WorkspaceEventPublisher` — a genuine, safe, additive use of already-real
data, not a fabricated call. `HomeScreen` has no equivalent safe next
step this milestone (no single real "workspace changed" callback point);
accept-and-store is the honest limit there.

## Duplicate suppression

`AutonomousWorkspaceRuntime.captureRuntimeState()` (R34) already
de-duplicates notifications per session/outcome before returning its
snapshot; `publishRuntimeSnapshotCaptured()` publishes exactly one
`NotificationGenerated` per real, already-deduplicated
`WorkspaceNotification` — no second de-duplication layer invented here.
Proven in the "duplicate suppression" test (second `captureRuntimeState()`
call with no new terminal outcome publishes zero further
`NotificationGenerated` events).

## Performance

- 5000 `publish()` calls dispatched to a live subscriber: 5ms.
- 50 `EventBus` create/dispose cycles: ~508KB RSS delta (no leak growth
  pattern across cycles).

## Known limitations

- `payload` is a real, unused extension point — no current subtype needs
  it; kept only as a named place for a future subtype's untyped data.
- No subsystem publishes automatically — every publish call is manual,
  paired with its real coordinator call, matching the "remain unchanged"
  constraint. A future milestone could revisit whether specific
  call-sites (e.g. inside `HomeScreen`'s own intent-submission handler)
  should be wired to call the publisher automatically.
- `HomeScreen` has no additive publish call this milestone (see UI
  integration above) — only accept-and-store.

## Recommendation for R36

Wire `WorkspaceEventPublisher` calls into `HomeScreen`'s real intent
submission / session action handlers now that both the bus and the
publisher are real, tested, and connected to a live UI surface.
