# IS-R56 Repository Audit Report

R56 was specified with **nothing preselected** and with the instruction that
repository evidence overrides the specification. This is what the audit found,
including where it disproved my own hypothesis and where it contradicted the
milestone's own title.

## SCALE

| | Files | Lines |
|---|---|---|
| `lib/` | 470 | 65,278 |
| `test/` | 199 | 55,906 |
| `docs/` | 136 | — |
| `tools/` | 0 | — |

`tools/` does not exist. The specification lists it as a search target; it is
empty, and that is stated rather than silently skipped.

## PHASE 1–2 — WHAT WAS SCANNED AND WHAT CAME BACK CLEAN

Most of the duplication axes the specification lists are **already singular**,
in several cases because R46–R55 made them so. Recording the clean results
matters as much as the findings: it is the difference between an audit and a
search for a predetermined answer.

| Axis | Result |
|---|---|
| Runtime creation | **CLEAN** — `AnythingRuntime` constructed in exactly one place (`experience_host_screen.dart:205`) |
| Runtime destruction | **CLEAN** — one `dispose` chain inside `AnythingRuntime` |
| Commit / transaction / rollback / repair | **CLEAN** — R55, certified I-68…I-74 |
| Installation / compatibility / dependency planning | **CLEAN** — R54, certified I-61…I-67 |
| Distribution / verification | **CLEAN** — R53, certified I-57…I-60 |
| Trust / governance / policy | **CLEAN** — R51/R52 |
| Retention / lifecycle | **CLEAN** — R50, one engine |
| AI invocation / reasoning | **CLEAN** — certified since R46 |
| Protection / encryption | **CLEAN** — one crypto importer |
| Event publishing | **CLEAN** — one `EventBus`, composed once |
| Caching | **CLEAN** — one `KnowledgeCache` |
| Scheduling | **CLEAN** — one `WorkspaceSchedulingEngine` |
| Migration | **CLEAN** — one `MigrationExecutor` |
| **Durable collection persistence** | **DUPLICATED ×3 — see findings** |

### The milestone title was wrong, and the evidence says so

IS-R56 is titled "Canonical Runtime **Import** Framework". The audit found
runtime creation is **already** singular — one construction site — and import
was unified in R53/R54. There was no duplicated runtime-import ownership to
fix.

Per the specification's own rule ("If the audit proves my proposed owner is
wrong, abandon it and implement the correct owner instead"), R56 implements
what the evidence actually showed.

## FINDING 1 — THREE COPIES OF AN UNSERIALISED READ-MODIFY-WRITE

**Severity: A (proven data loss).**

Three collections persist a whole list under one key and mutate it identically:

```
read the whole list  ->  change it in memory  ->  write the whole list
```

| Owner | Methods |
|---|---|
| `RealNotificationService` | `schedule`, `cancel`, `cancelAllForExperience`, `deliverDue` |
| `ActivityRepository` | `record` |
| `IntentRepository` | `save`, `updateStatus`, `delete` |

Every one `await`s between the read and the write, and nothing serialised the
sequence.

### It was MEASURED, not reasoned about

A temporary probe, run before any code was written:

```
ACTIVITY:      recorded 10 concurrently, stored 10        <- NOT lost
SCHEDULE:      scheduled 10 concurrently, pending  1      <- NINE LOST
NOTIFICATIONS: 1 scheduled,  presented 2 time(s)          <- exactly-once broken
```

**The first line disproved half my hypothesis.** I expected all three to lose
writes. Activity does not — its awaits happen to resolve in a surviving order.
That is luck, not a guarantee, and nothing asserts it; but R56 claims a proven
defect **only** for the notification paths.

### Why the notification defect is reachable in production

- `NotificationCapability` exposes `schedule`/`cancel` to **any running
  Experience**.
- `BackgroundCoordinator` polls `deliverDue`.
- The workspace can run several Experiences concurrently (R39/R45).

So concurrent `schedule` + `deliverDue` is a live path, not a test artefact.

### The double-delivery mechanism

`deliverDue` presented and **then** persisted the remainder. `await
present(...)` is a yield point; a second caller entered while the due set was
still stored, read the same set, and presented it again — violating the
exactly-once contract stated in the method's own doc comment.

## FINDING 2 — SILENT TRUNCATION IN `IntentRepository`

**Severity: B. Unrelated to concurrency. Found while consolidating.**

`updateStatus` and `delete` read through `list()`, whose **default limit is
50**, then wrote the result back as the whole history. Retention allows 100
records. So with 51–100 intents stored, any status update or delete silently
discarded everything past the 50th.

Fixed by mutating the full stored list inside the critical section, where no
display limit applies.

## FINDING 3 — `ActivityRepository` HAS NO OWNER

**Severity: C (hygiene). No data defect — proven above.**

It is constructed in **nine** separate places and appears **nowhere** in
`AppComposition`:

```
app/creation_coordinator.dart:147            app/experience_workspace_manager.dart:55
app/experience_modification_coordinator.dart:84   app/intent_session_manager.dart:128
app/experience_opening_coordinator.dart:76   evolution/evolution_coordinator.dart:44
features/activity/activity_screen.dart:19    features/experiences/experiences_screen.dart:81
runtime/experience_host_screen.dart:240
```

Every other repository is composed exactly once. This one is not composable at
all in production.

It is **not** a correctness bug: the class is stateless with a `const`
constructor and `SharedPreferences.getInstance()` is a process singleton. It
is, however, why R56's lock is keyed by **storage key** rather than by
instance — per-instance locking would protect nothing here.

Recorded as **G-37**, not fixed: composing it means touching nine call sites
across coordinators and UI, which is a milestone of its own.

## FINDING 4 — DEAD CODE

**Severity: C.**

`lib/storage/local_database.dart` declares `AnythingLocalDatabase` and
`AnythingPreferences`. **Zero references** anywhere in `lib/` or `test/`.

`AnythingPreferences` also duplicated theme-mode persistence that
`design_system/theme/theme_provider.dart` really owns — a dead parallel
implementation of a live feature.

**DELETED**, following R47's precedent for `contracts/runtime.dart` (G-01).

## FALSE POSITIVE, RECORDED

An early scan flagged `software_cognition/package_analyzer.dart` as a
persistence user outside `lib/storage/`. It is not. The match was the string
literal `'shared_preferences': 'key-value storage'` in a package-name lookup
table. Recorded so the correction is visible rather than quietly dropped.

## PHASE 3 — OWNERSHIP GRAPH (durable persistence, after R56)

```
NotificationCapability ─┐
BackgroundCoordinator  ─┤
creation/modification/ ─┼──> RealNotificationService ─┐
evolution/session/UI   ─┤    ActivityRepository      ─┼──> DurableCollectionStore ──> SharedPreferences
home screen            ─┘    IntentRepository        ─┘         (ONE owner)

ThemeProvider ─────────────────────────────────────────────────> SharedPreferences
                                       (single scalar key, no collection, PINNED)

Experience state ──> ExperienceCommitFramework ──> SqliteExperienceRepository   (R55)
```

Forbidden edges, certified: no repository may reach `SharedPreferences`
directly; no second collection store may exist; presentation may not occur
inside the critical section.

**Note on the store's implementation.** The first version serialised callers
through a static per-key future chain and deadlocked across `flutter_test`
zones. It was replaced by a stateless design that removes the yield between
read and write instead of locking around it — see
`docs/architecture/ADR_R56_DURABLE_COLLECTION_STORE.md` Decision 3.

## PHASE 4 — INVARIANT REVIEW

All 83 pre-R56 invariants were re-run and pass unchanged. None was weakened.

**One R56 invariant was WRONG on its first attempt, and the mutation probe
caught it.** The `deliverDue` ordering check originally asserted
`indexOf(present) > lastIndexOf(store.update)`. Moving presentation *inside*
the mutation callback still satisfies that, because the callback text begins
after `store.update(` starts — a **false negative**: green, and checking
nothing.

Rewritten as a **containment** check using balanced-parenthesis call ranges.
The probe then failed as required. This is Phase 4's "vacuous passes" category
found in R56's own new work rather than in inherited code.

## PHASE 5–6 — GAP REVIEW

| Gap | Status after R56 |
|---|---|
| G-34 (`touchLastUsed` writes directly) | **Still valid.** Unchanged and still pinned. |
| G-35 (atomicity stops at the repository boundary) | **Still valid**, and now has a sibling: the durable store serialises one key, not a cross-key transaction. |
| G-36 (protection holds a repository for reads) | **Still valid.** |
| G-02 (`MinimalKernel` dead) | **Still valid** — deliberately out of scope; R56 deleted the other dead file it found. |

New: **G-37** (activity has no composition ownership), **G-38** (notification
delivery is now at-most-once), **G-39** (theme provider writes directly —
pinned).

## RECOMMENDED NEXT MILESTONES

1. **Compose `ActivityRepository`** (G-37). Nine construction sites, no owner —
   the last repository in the codebase with no composition entry. Mechanical,
   and the certification pattern already exists.
2. **Delete `MinimalKernel`** (G-02, open since R47) and sweep for other dead
   declarations with the technique R56 used here.
3. **Cross-key atomicity** (G-35), if and only if a real requirement appears.
   Nothing currently needs it, and inventing it would be speculative.
4. **A durable retry for notification delivery** (G-38), if at-most-once turns
   out to be too weak in practice. It is the correct default today.
