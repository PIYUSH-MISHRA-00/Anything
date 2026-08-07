# Lifecycle Certification — Implementation Specification IS-R50

How the canonical lifecycle/retention ownership model is enforced
mechanically, on every `flutter test` run, by
`test/r46_architectural_integrity_certification_test.dart`.

## The four lifecycle invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-44 | Exactly **two** policy engines exist — `WorkspaceLifecyclePolicyEngine` (runtime) and `RetentionPolicyEngine` (data) — and they are **disjoint** | STATIC | CERTIFIED |
| I-45 | The retention engine **decides but never deletes** — no storage handle, no I/O, no `Timer` | STATIC | CERTIFIED |
| I-46 | **No repository or capability service owns a retention rule** of its own | STATIC | CERTIFIED |
| I-47 | `KnowledgeRepository` never owns retention — it reports facts and is told what to drop | STATIC | CERTIFIED |

### I-44 — one owner per domain, and no overlap

Scans every `class *Retention*Engine` / `class *Lifecycle*Engine` in `lib/`
and pins the result to exactly two. A **third** engine of either kind is a
parallel lifecycle manager and fails outright.

Disjointness is checked in **both directions**, because a merged vocabulary
would be just as much a violation as a duplicated one:

- the retention engine may not reference `ExperienceRuntimeController`,
  `AppLifecycleState` or `RuntimePolicyAction`;
- the runtime engine may not reference `RetentionClass`, `LifecycleCandidate`
  or `maxEntries`.

### I-45 — purity is what keeps storage ownership intact

The engine is forbidden from referencing `sqflite`, `Database`,
`SharedPreferences`, `dart:io`, `File(`, `Directory(` or `Timer`.

This is not stylistic. If the engine could delete, it would become a second
storage owner and R48's "the repository is storage only" would quietly stop
being true. If it could hold a `Timer`, it would become a second scheduler and
Task 5's "no second scheduler" would quietly stop being true. Purity is the
mechanism that makes both promises structural rather than aspirational.

### I-46 — the defect this milestone existed to remove

Five delegating files are checked for a re-invented private bound
(`_maxRecords` / `_maxEvents` / `_maxScheduled` / `_maxEntries` /
`_maxRetained`):

```
lib/storage/intent_repository.dart
lib/storage/activity_repository.dart
lib/capabilities/adapters/notification_service_adapter.dart
lib/capabilities/adapters/file_service_adapter.dart
lib/storage/knowledge_repository.dart
```

This is the exact shape of the pre-R50 defect — three files, three magic
numbers, invented independently. The invariant stops any of them quietly
doing it again.

### I-47 — the subtlest of the four

`KnowledgeRepository` is forbidden from referencing `RetentionPolicyEngine` or
`LifecycleDomain` at all, **and required** to still expose `keySummaries()`.

Both halves matter. The first keeps policy out of storage. The second keeps
storage able to *report the facts* policy is decided from — because the
tempting "fix" for a repository that must not decide is to make it blind, and
a blind store cannot be governed at all.

## Mutation evidence

A certification that has never been observed failing is not evidence.

**Probe A — a parallel retention engine.** A file declaring
`class ParallelRetentionEngine` with its own `maxEntries` and `evict()`:

```
I-44 Expected: [retention_policy_engine.dart:RetentionPolicyEngine,
                workspace_lifecycle_policy_engine.dart:WorkspaceLifecyclePolicyEngine]
     Actual:   [... , lib/r50_mutation_probe.dart:ParallelRetentionEngine]
     A parallel lifecycle/retention engine appeared
```

**Probe B — a repository re-inventing a bound.** Restoring
`static const int _maxRecords = 100;` to `IntentRepository`:

```
I-46 Expected: empty
     Actual:   ['static const int _maxRecords']
     lib/storage/intent_repository.dart re-invented a retention bound
     — retention belongs to RetentionPolicyEngine
```

Both probes were reverted and the tree confirmed clean.

## What certification cannot catch, and what caught it instead

R50 broke a caller. Removing `RealNotificationService.maxScheduled` — the
field R49 had added — invalidated R49's own test, which constructed the
service with `maxScheduled: 3`.

**No invariant in this file detected that.** Static certification checks
architectural shape, not API compatibility. What caught it was the
**analyzer baseline** moving 71 → 72, with one `undefined_named_parameter`.
The test was migrated to express the same bound as a retention policy — the
assertions are unchanged, which is the point: ownership moved, behaviour did
not.

This is the fourth time across R46–R50 that something other than the
certification layer caught the real defect (R46: a vacuously-passing import
scan; R47: a reference search blind to `export`; R48: a scanner blind to
string interpolation; R50: an API break invisible to static shape checks).
The consistent lesson is worth restating: the certification layer is one
mechanical check among several, and the analyzer baseline and the full suite
have each earned their keep independently.

## Behaviour-preservation evidence

Ownership moving is only safe if behaviour does not move with it. Three tests
assert the pre-R50 numbers exactly:

| Domain | Pre-R50 | Asserted post-R50 |
|---|---|---|
| intents | 100 | **100** |
| activity | 200 | **200** |
| notifications | 200 | **200** |

Plus a fourth proving the new capability: the *same* `IntentRepository` with
an injected policy of 5 retains 5 — configurable per caller, which was
impossible when the bound was a compile-time constant.
