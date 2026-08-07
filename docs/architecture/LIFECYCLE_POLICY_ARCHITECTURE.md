# Lifecycle Policy Architecture — Implementation Specification IS-R50

## REALITY

Retention was invented independently, three times, with three unexplained
magic numbers — and one domain had none at all. Repository audit (Task 1):

| Owner | Rule | Where |
|---|---|---|
| `IntentRepository` | `_maxRecords = 100`, enforced inline | `storage/intent_repository.dart` |
| `ActivityRepository` | `_maxEvents = 200`, enforced inline | `storage/activity_repository.dart` |
| `RealNotificationService` | `maxScheduled = 200`, added by R49 | `capabilities/adapters/notification_service_adapter.dart` |
| `KnowledgeRepository` | **none — unbounded** | gap G-18, open since R48 |
| `RealFileService` | none; `clearTemporaryFiles()` only on demand | R49 |

Each was locally reasonable. Collectively they were unreviewable: nobody could
answer *"what does this application retain, and for how long?"* without
reading five files, and the one domain that most needed a bound — persisted
knowledge, which grows from the open web — was the one that had none.

Related but **out of scope**, and deliberately left alone: `CredentialVault`,
`SqliteExperienceRepository.delete()`, `MemoryManager.deleteConversation()`
and `IntentComposer.clear()` are *explicit user or caller actions*, not policy
outcomes. Retention decides what happens **without** anyone asking. Deletion
someone asked for is not retention, and routing it through a policy engine
would have been a category error.

## THE DECISION THAT SHAPED THIS MILESTONE

IS-R50 asks that `WorkspaceLifecyclePolicyEngine` remain the canonical owner
"whenever appropriate", and that it be extended rather than joined by an
unrelated engine "**if that preserves the established ownership model**".

It was read, and extending it would **not** preserve that model — it would
damage it. Four concrete reasons:

1. **Different subject.** It decides what a *running runtime* should do
   (pause/resume/terminate/restore) and acts on an
   `ExperienceRuntimeController`. Retention decides what *stored records*
   should do; no controller exists anywhere in that path.
2. **Different input.** Its inputs are `AppLifecycleState` and
   `WorkspaceRuntimeSnapshot`. Retention's inputs are record counts, ages and
   sizes. Neither can produce the other's input.
3. **Closed vocabulary.** `RuntimePolicyAction` is a deliberately closed enum
   that `apply()` exhaustively switches over. Adding `evict`/`expire` would
   make that switch — and every caller's switch — silently incomplete, or
   force a meaningless `noAction` fallthrough. Merging two unrelated
   vocabularies into one enum is exactly how a clean ownership model rots.
4. **Different consumers.** That engine is consumed by the scheduler and
   runtime supervisor. Retention is consumed by repositories and capability
   services, which must never depend on the runtime layer.

**Result: two engines, two disjoint domains.**

```
WorkspaceLifecyclePolicyEngine   ->  runtime lifecycle   (R39, untouched)
RetentionPolicyEngine            ->  data retention      (R50, new)
```

The disjointness is not a claim, it is **certified** (I-44): the retention
engine may not reference `ExperienceRuntimeController`, `AppLifecycleState` or
`RuntimePolicyAction`; the runtime engine may not reference `RetentionClass`,
`LifecycleCandidate` or `maxEntries`. A *third* engine of either kind fails
certification outright.

## THE MODEL

```dart
enum RetentionClass { ephemeral, bounded, durable, protected }
enum LifecycleAction { retain, evict, expire }

class LifecyclePolicy    { retentionClass, maxEntries?, maxBytes?, maxAge? }
class LifecycleCandidate { id, timestamp, sizeBytes?, isProtected }
class LifecycleDecision  { id, action, reason }
class LifecycleEvaluation{ domain, policy, decisions }
```

`LifecycleCandidate` is deliberately minimal — an identity, when it happened,
optionally how big, and whether the user exempted it. Asking for more would
couple the engine to every domain's record type.

`LifecycleDecision` carries a **reason**, so a reclamation is always
explainable after the fact rather than an unattributed disappearance.

### The one retention table

| Domain | Class | Max entries | Max bytes | Max age |
|---|---|---|---|---|
| `knowledge` | bounded | 500 | 20 MB | 30 d |
| `intents` | bounded | **100** | — | — |
| `activity` | bounded | **200** | — | — |
| `notifications` | bounded | **200** | — | — |
| `temporary_files` | ephemeral | — | — | 1 d |
| `exports` | ephemeral | — | — | 7 d |

The three bolded numbers are **unchanged** from their pre-R50 values. R50
moved ownership without silently changing behaviour, and three tests assert
exactly that (still 100, still 200, still 200). Knowledge gains the bound it
never had; temporary files and exports gain age bounds so scratch space cannot
accumulate indefinitely.

An **unregistered domain is unbounded**, deliberately: an unknown domain must
never have its data reclaimed by a default nobody chose.

### Order of reasoning, and why

1. **Protected** — retained unconditionally. A manual exemption that a budget
   can override is not an exemption.
2. **Age** — evaluated before budgets, so an over-budget domain reports the
   *honest* reason (`expire`) for records that were aging out anyway, rather
   than mislabelling them `evict`.
3. **Count**, newest-first — the oldest surplus is evicted.
4. **Bytes**, newest-first — evicts until the remainder fits.

Deterministic: candidates are ordered newest-first, ties broken by id, so
input **order** cannot change the outcome. Tested by evaluating the same set
forwards and reversed.

## DECIDES, NEVER DELETES

The engine is pure and synchronous. It holds no storage handle, performs no
I/O, and owns no `Timer`. Callers apply decisions to their own stores.

That is what keeps storage ownership exactly where R46–R49 put it, and it is
certified (I-45): the engine may not reference `sqflite`, `Database`,
`SharedPreferences`, `dart:io`, `File`, `Directory` or `Timer`.

It also means R50 introduced **no scheduler and no timer** — `BackgroundCoordinator`
and `NotificationPlanner` remain the canonical planning layer, untouched
(Task 5). Retention is applied when a caller writes or explicitly asks, never
on a background tick this milestone invented.

## HOW EACH DOMAIN DELEGATES

| Domain | Applied by | When |
|---|---|---|
| intents | `IntentRepository.save()` | on write |
| activity | `ActivityRepository.record()` | on write |
| notifications | `RealNotificationService.schedule()` | on write |
| knowledge | `KnowledgeCache.applyRetention()` | after `put()`, or on demand |
| temp / exports | `RealFileService.applyRetention()` | on demand |

Each takes the engine as an injectable constructor argument defaulting to the
canonical one, so **no existing caller changed** (Task 9).

### Knowledge: the one that needed care

`KnowledgeRepository` must remain **storage only** (IS-R48's own rule, and
invariant I-36). So:

- the repository gained `keySummaries()` — a plain SQL aggregate reporting
  per-key entry count, byte size and recency. It **reports facts**;
- `KnowledgeCache` hands those facts to the engine and applies the verdict by
  telling the repository which keys to remove.

The repository still evaluates nothing, has no bounds of its own, and
reclaims nothing on its own initiative — certified (I-46). The aggregate is
computed in SQL so evaluating retention never materialises stored content:
cost is proportional to *key count*, not corpus size.

### Files: what is never reclaimed

`applyRetention()` covers `tmp/` and `exports/` only. **Adopted Experience
assets are never reclaimed by policy** — an adopted file is a user's own
document, and deleting it is an explicit action through `deleteAdoptedFile()`,
never a retention side effect. A test asserts an adopted asset survives a
retention pass that deletes a scratch file beside it.

`clearTemporaryFiles()` remains an unconditional, caller-initiated wipe and is
deliberately **not** routed through the engine, for the same reason as
`CredentialVault.delete()`: an explicit instruction is not a policy outcome.

## WHAT R50 DID NOT DO

- No `Timer`, no second scheduler, no second planner, no second notification
  graph (Task 5).
- No second cache, no second repository (Task 3).
- No API break, no Experience migration (Task 9).
- No WebWeaveX change; no Kaalka change.
- No change to the three existing bounds' values.

## KNOWN LIMITATIONS

1. **Retention is applied on write or on demand, never on a schedule.** There
   is no background sweep, because R50 was forbidden from introducing a timer
   and `BackgroundCoordinator` still has no OS-level execution (gap G-20). A
   store that is written to rarely will hold aged records until its next
   write or an explicit `applyRetention()` call. Honest consequence of the
   constraint, not an oversight.
2. **`RetentionClass.durable` and `.protected` are modelled and enforced but
   have no production producer yet.** `isProtected` is always false today —
   nothing in the UI marks knowledge as protected. The mechanism is proven by
   test; the user-facing affordance is future work (Task 3 named "manual
   protection" and "future synchronization" as forward-looking).
3. **Byte accounting for knowledge uses stored JSON length**, not on-disk
   page size. Close enough to bound growth, not an exact disk figure.
4. **`StructuredLogger(maxBuffer: 200)` and
   `CapabilityPlatform._maxInvocationsPerCapability = 100` are NOT routed
   through the engine.** Both are in-memory diagnostic ring buffers, not
   persisted data — reclaiming them is not a retention decision and folding
   them in would have widened the engine's remit for no benefit. Recorded so
   the omission is visible rather than assumed.
