# Experience Commit Architecture — Implementation Specification IS-R55

## TASK 1 — THE COMPLETE PERSISTENCE AUDIT

Every writer of Experience state that existed before R55:

| # | Site | Write | Domain |
|---|---|---|---|
| 1 | `app/creation_coordinator.dart:442-443` | `savePackage` + `saveMetadata` | creation |
| 2 | `app/experience_modification_coordinator.dart:136` | `savePackage` | modification |
| 3 | `app/experience_modification_coordinator.dart:295` | `savePackage` | evolution-plan apply |
| 4 | `app/experience_modification_coordinator.dart:379` | `savePackage` | **modification rollback** |
| 5 | `evolution/evolution_coordinator.dart:79` | `savePackage` | evolution |
| 6 | `security/protection_service.dart:203,207,210` | `saveProtectedEnvelope` + `updateProtectionState` + `deletePackage` | protection |
| 7 | `security/protection_service.dart:289` | `savePackage` | unprotection |
| 8 | `app/experience_installation.dart` (×6) | `savePackage`/`saveMetadata`/`delete` | installation |
| 9 | **`features/experiences/experiences_screen.dart:270`** | **`delete`** | **a UI screen** |

**Site 9 was not on R54's list.** R54 named four remaining commit paths; the
repository-wide audit found five, because a UI widget was deleting Experiences
directly. That is why Task 1 says "search every coordinator, manager, service,
runtime" rather than "check the four we know about".

### Writes deliberately NOT rerouted

| Site | Write | Why |
|---|---|---|
| `experience_opening_coordinator.dart:128,171,201`, `experiences_screen.dart:89` | `touchLastUsed` | Stamps an access time on an existing row. Persists no package, no metadata record, and no state any rollback could need to restore. Routing four call sites through a commit framework to bump a timestamp is ownership ceremony with no ownership benefit. **Pinned in certification and recorded as G-34** so the exclusion is reviewable rather than silent. |

Other repositories — `KnowledgeRepository`, `WorldModelRepository`,
`EngineeringMemoryRepository`, `ActivityRepository`, `CredentialVault`,
`ExperienceDatabase` (per-Experience user data) — are outside this framework's
subject. It owns **Experience state**, not "all persistence in the process".
Claiming otherwise would be a much larger milestone wearing this one's name.

## OWNERSHIP AFTER R55

```
creation      \
modification   \
evolution       >--- ExperienceCommitFramework ---> SqliteExperienceRepository
protection     /              (COMMITS)                      (STORES)
installation  /
removal      /
```

Exactly one writer. Certification forbids every other file in `lib/` from even
naming a repository write method (I-69).

## TASK 7 — THE TRANSACTION INVESTIGATION, AND ITS ANSWER

Task 7 asked whether transaction exposure is now justified, and required that
atomicity never be fabricated.

**It is justified, and it was done, because it could be done without moving
ownership.**

R54 could not make a two-row commit atomic: `savePackage` and `saveMetadata`
each resolved their own `Database`, so sqflite's `db.transaction` was
unreachable through them. R54 compensated — snapshot, write, restore — and
recorded the residual crash window as **G-28**.

Three facts made the fix small:

- `SqliteExperienceRepository.database` was **already public**.
- `Transaction` and `Database` both implement `DatabaseExecutor`.
- So each write method needed **one optional `using` parameter**.

```dart
Future<void> saveMetadata(ExperienceMetadataRecord record, {DatabaseExecutor? using}) async {
  final db = using ?? await database;
  ...
}
```

Additive, defaulted, no existing caller touched, no schema change, no
migration. `RepositoryTransactionCoordinator` then runs several writes inside
one real transaction.

**Why this is not "a second transaction engine".** There is no engine. It is
sqflite's own transaction, reached in exactly one place. The repository still
owns every table name and every statement; it is told *which executor to write
through*, never *how to transact*. That is the difference between exposing a
seam and moving ownership.

### What this honestly delivers, and what it does not

**Delivers:** writes inside `run()` are atomic — SQLite commits them together
or not at all, including across a process kill. G-28's crash window is
**closed** for every commit that goes through the framework. Not narrowed.

**Does not:** it cannot make a repository write atomic with something *outside*
the repository. World Model ingestion and engineering-memory persistence remain
sequential and best-effort, exactly as they were and deliberately so. Nested
transactions are unsupported and never attempted — only this coordinator opens
one.

## THE STATE THAT CAN NO LONGER EXIST

Protection was three sequential writes: store the envelope, flip the flag, drop
the plaintext. A failure between the second and the third left an Experience
**marked protected with its plaintext still on disk** — the worst torn state in
the system, because it looks secure and is not.

All three now land in one transaction. A dedicated test interrupts the sequence
after the flag flip and asserts the combination `isProtected == true && package
!= null` is unreachable.

This is the clearest single argument for Task 7: the atomicity was not a
tidiness improvement, it removed a security-relevant failure mode.

## WHAT EACH SUBSYSTEM KEPT

| Subsystem | Keeps | Gave up |
|---|---|---|
| Creation | building the package, provenance, World Model + engineering memory | **all persistence** — it no longer holds a repository at all |
| Modification | diffing, validating, the modification engine | persistence, and rollback |
| Evolution | proposals, executor, validator | persistence |
| Protection | **all crypto** — still the only thing that encrypts | persistence |
| Installation | compatibility, dependencies, migrations, kind, protection request | persistence, rollback, repair |
| Distribution | movement, verification, provenance assignment | (gave up committing in R54) |
| Repository | every table name and statement | nothing |

**Creation's field disappeared.** Once its two writes moved, the analyzer
reported `_repository` as unused. That is the cleanest available evidence that
creation is decoupled from persistence rather than merely routed around it —
so the field was deleted rather than kept "just in case".

## TASK 8 — REPAIR

Repair coordination moved from the installer to the commit framework, because
repair is entirely a persistence-consistency operation: it inspects what is on
disk and reconciles rows. The installer still decides *when* to repair and
reports it in installation vocabulary; it no longer decides what repairing
*means*, and it no longer writes.

**Why repair still exists after G-28 closed.** A commit through this framework
can no longer tear itself apart. But a database can still be torn by anything
outside this framework's history — a pre-R55 write, a restored backup, manual
surgery, storage corruption. Removing a recovery path because the new code no
longer *causes* the problem would be the wrong trade.

R55 also fixed a latent false alarm: a **protected** Experience has no plaintext
package by design, and the R54 implementation would have called that damaged.
Repair now checks for an envelope and reports `healthy`.

## TASK 9 — ROLLBACK

Four `rollback` methods exist in `lib/`, and that is correct. Three are façades
in their own vocabulary — installation result, modification result, transaction
state. What makes **one owner** true is that only the commit framework can
write, so only it can actually restore anything.

All three façades are certified to reach it.

Installation rollback deliberately restores by **re-installing**, so the prior
package is re-validated and re-checked for compatibility on the way back in. A
rollback cannot restore something this build can no longer run.

Every rollback takes caller-held prior state rather than looking it up, because
the repository keeps no version history — one row per Experience,
replace-on-write. That was true before R55 and R55 does not change it.

## BACKWARD COMPATIBILITY

- No API break. Every new constructor parameter is optional; every existing
  caller compiles and behaves identically.
- No schema change, no migration, no persistence redesign.
- All 2015 pre-existing tests pass **unchanged** after six commit paths were
  rerouted — the evidence that ownership moved and behaviour did not.

## KNOWN LIMITATIONS — read this section

1. **`touchLastUsed` is not routed through the framework** (G-34). Pinned in
   certification with its reason, not silently excluded.

2. **Atomicity is per-commit, not per-operation.** A creation is atomic in its
   repository write, but World Model ingestion and engineering-memory
   persistence that follow are separate, best-effort, and can fail
   independently. That was true before R55 and remains true; it is a
   deliberate scoping decision documented in `ENGINEERING_MEMORY.md`, not an
   oversight.

3. **The commit framework owns Experience state only.** Five other
   repositories persist other subjects and are untouched.

4. **A user still cannot install or import an Experience** — no file format,
   no file I/O, no UI (R53's G-25, R54's reachability note). R55 changes who
   writes, not what a user can do.

5. **`ExperienceProtectionService` still holds a repository** for READS
   (loading metadata and envelopes). Certification forbids it from writing, not
   from reading. Splitting read and write access would need a repository-side
   change R55's rules do not permit.
