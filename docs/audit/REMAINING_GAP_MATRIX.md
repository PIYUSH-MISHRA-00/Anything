# Remaining Gap Matrix — IS-R46, updated through IS-R59

Everything the repository-wide audit surfaced that is **not** resolved. Each
row cites real evidence; nothing here is hypothetical.

Severity: **A** = architectural integrity, **B** = correctness/UX,
**C** = hygiene.

## CLOSED BY IS-R47

| # | Gap | How it was closed |
|---|---|---|
| G-01 | Dead, name-colliding v1 runtime contract | **DELETED.** Re-verified repository-wide that nothing implemented it and all six of its symbols were unused, then removed `lib/core/contracts/runtime.dart`. `AnythingRuntime` now declares exactly once; `knownDuplicateDeclarations` is empty. Three guards prevent its return (I-15, I-15b, I-15c), mutation-proven. |
| G-07 | Stale R44 comment in `experience_activation_manager.dart` | **CORRECTED** (documentation only, no behavior change). It now names `ExperienceEntryPipeline` as the single pusher, states plainly that the old `HomeScreen` claim was never true, explains why it was deliberately left through R45/R46, and points at the invariants that now enforce it mechanically. |
| G-08 | `HomeScreen` submit-button reactivity | **FIXED.** The icon subtree is wrapped in a `ValueListenableBuilder<TextEditingValue>` on the existing `_textController` — the native Flutter mechanism, rebuilding only that subtree. No new state, no listener to dispose, no business-logic change. |
| G-10 | WebWeaveX deterministic serialization unused | **IMPLEMENTED** (IS-R47 Task 4). See `WEBWEAVEX_USAGE_MATRIX.md` W-1. |

## CLOSED BY IS-R48

| # | Gap | How it was closed |
|---|---|---|
| G-13 | `KnowledgeCache` in-memory only; no cross-restart persistence | **CLOSED.** Persistence added *inside* `KnowledgeCache` as an implementation detail, backed by a new `KnowledgeRepository` following the same per-domain pattern as the ten repositories already in `lib/storage/`. Canonical ids, hashes and representations are proven byte-identical across a genuine restart. Restoration is lazy and per-key — no startup scan, no eager load. |

## CLOSED BY IS-R49

| # | Gap | How it was closed |
|---|---|---|
| G-03 | Two production `Fake*` services registered in the real composition | **CLOSED.** `FakeNotificationService` → `RealNotificationService` (durable schedules, real ownership, real due computation, real foreground delivery on the existing `EventBus` via R35's `NotificationGenerated`). `FakeFileService` → `RealFileService` (real picking via the already-present `file_picker`, real sandboxed adoption/export/temp/workspace assets via `path_provider` + `dart:io`). No `Fake*` is constructed in the composition root any more (I-39), mutation-proven. |

## CLOSED BY IS-R50

| # | Gap | How it was closed |
|---|---|---|
| G-18 | Persisted knowledge had no retention policy — unbounded growth | **CLOSED.** `RetentionPolicyEngine` now owns it: 500 entries / 20 MB / 30 days. `KnowledgeCache.applyRetention()` asks the engine and tells `KnowledgeRepository` which keys to drop; the repository still owns no policy (I-47). R48 deliberately did not invent a policy because none existed to reuse — R50 created the canonical owner first, then applied it. |
| G-22 | Retention was invented independently three times with three magic numbers (`_maxRecords=100`, `_maxEvents=200`, `maxScheduled=200`) | **CLOSED.** All three delegate to the ONE engine. Values unchanged — three tests assert 100/200/200 exactly, so ownership moved without behaviour moving. No repository or capability service may hold a retention rule any more (I-46), mutation-proven. |

## OPENED BY IS-R61 — recorded at the moment they were created

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-56 | MED | **Nothing consumes the execution contract.** No package carries one, `ExperienceEntryPipeline` does not read one, and no governance path is fed by one. The contract is a correct, certified, unwired declaration. | `grep -rln ExecutionMode lib/` returns exactly one file — the contract itself | **Open, deliberately.** IS-R61's ABSOLUTE RULES forbid redesigning the runtime, scheduler, lifecycle, installation, packaging, governance, trust, commit and repository layers, which is every subsystem a consumer would have to touch. Named as the recommended IS-R62. |
| G-57 | LOW | **Reserved execution semantics have no implementation.** `ExecutionMode.headless`, `ExecutionMode.autonomous`, `IsolationPolicy.strict` and `recoverable` are architecture only. | `ExperienceExecutionValidator` refuses the two reserved modes; `strict` and `recoverable` are inert | **Open by design.** Refusing beats accepting-and-ignoring: accepting a reserved mode would promise execution semantics no runtime implements. Declaring the vocabulary now means no widening later. |

## PROGRESSED BY IS-R60

| # | Sev | Gap | Movement |
|---|---|---|---|
| **G-25** | **A** | **A user still cannot import an Experience** — open since R53 | **HALF CLOSED, and only half.** The FORMAT half is done: a canonical container, a deterministic writer, a reader, checksum verification, and `ExperienceDistributionPackage.fromJson` (R53 shipped `toJson()` with no way back). The FILE half is NOT done — nothing writes bytes to a `.anything` file and no UI lets a user pick one. `RealFileService` (R49) owns file I/O and `file_picker` is already a dependency, so the remainder is small and named. **G-25 stays OPEN.** |

## OPENED BY IS-R60

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-53 | MED | **No file I/O for packages.** The codec produces and consumes bytes; nothing persists them to disk or reads a user-chosen file. | `experience_package_codec.dart` contains no `dart:io` — certified by I-88 | **Open, deliberately.** The codec must not own file I/O (R49 does). Wiring the two is the last step of G-25 and the recommended IS-R61. |
| G-54 | LOW | **No signature verification.** The container reserves a `signature` block, carries it verbatim and verifies nothing. | `ExperiencePackageReader` | **Open by design.** Same position as R52/R53: a package earns no authority by being well-formed. A real verifier needs a key-distribution decision, which is a product question. |
| G-55 | LOW | **Packages are uncompressed.** Canonical JSON, no archive. | `ExperiencePackageFormat` | **Open, deliberately.** `archive` is not a dependency and R60 forbids adding one. The explicit `formatVersion` means a binary encoding can replace it without touching the manifest, the validator or any caller. |

## CLOSED BY IS-R59

| # | Sev | Gap | How it was closed |
|---|---|---|---|
| **G-48 (part)** | HIGH | **An entire parallel subsystem was unreachable and unclassified** | **PARTIALLY CLOSED.** The subsystem still exists and was deliberately NOT deleted (~50 mutually-referencing files meet no proof standard, and migrating to/from Riverpod is forbidden). What IS closed is the *unknown* part: every one of 451 `lib/` files now carries exactly one classification, and **I-86** fails on any file in an unknown state. **I-85** additionally certifies that no `ProviderScope` exists, so the subsystem cannot be revived silently. |
| **NEW** | MED | **110 of 466 lib files (23.6%) were unreachable from `main()` with no classification** | **CLOSED.** Measured by transitive import closure; every file classified REACHABLE (356) / DORMANT (43) / EXPERIMENTAL (50) / DEPRECATED (0) / DEAD (2). Reproducible via `tool/reachability.py`. |
| **NEW** | MED | **15 dead files** | **DELETED**, each proven by BOTH import closure and type-name reference, in four validated commits. One (`onboarding_screen.dart`) was a cascade exposed by an earlier deletion. |

## OPENED BY IS-R59

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-50 | MED | **~50 EXPERIMENTAL files remain** — a coherent parallel v1 application (`app_shell`, agents, tools, memory, ui_engine, core engines, groq services) that cannot run because no `ProviderScope` exists. | `PARALLEL_ARCHITECTURE_REPORT.md` | **Open, deliberately.** They import each other, so none is individually orphaned and none meets Phase 8's proof standard. Deleting or reviving is IS-R60's subject. |
| G-51 | LOW | **Two DEAD files could not be proven dead.** `layout.dart` and `semantic_entity.dart` are unreachable and unimported, but their type names collide with live declarations (36 and 167 unattributable references). | `DEAD_SUBSYSTEM_REPORT.md` | **Open.** Pinned in `pinnedUnreachableFiles` so I-86 keeps them visible. Needs type-aware analysis; a dependency for two files is not justified. |
| G-52 | LOW | **43 DORMANT files are tested but unreachable from `main()`** — their tests assert behaviour no user can reach. | `tool/reachability_report.json` | **Open.** Not a defect: coverage of inert code is harmless. Recorded because "2,068 tests pass" reads as "2,068 tests of reachable behaviour", and that is not true. |
| **G-40** | **HIGH** | **Suite flakiness is NOT resolved, and is far worse under contention.** Measured during R59's deliverable build: **27 failures / 2,068** with 79 `database is locked` errors when other flutter processes overlapped, versus 0 failures on a clean re-run. The rate is a function of concurrent database access, not a fixed probability. **Now the highest-priority remaining item** — CI runs the suite as of R58, and an intermittently red gate trains everyone to ignore it. R58 measured 0/22 and I reported it as not currently reproducible; it recurred twice during R59. | R59 full-suite runs | **Open, and my R58 reading was too confident.** 0/22 bounds the rate; it does not prove absence. Intermittent at a low rate. |

## CLOSED BY IS-R57

| # | Sev | Gap | How it was closed |
|---|---|---|---|
| **G-37** | B | **`ActivityRepository` had no composition ownership** — nine construction sites, absent from `AppComposition`, the only repository that could not be injected in production | **CLOSED.** Composed once and handed to every consumer. The six existing `?? ActivityRepository()` seams are retained (that is the injection pattern, and removing it would break the public constructors); the THREE bare constructions with no seam — `activity_screen`, `experiences_screen`, `experience_host_screen` — are gone. Certified I-78/I-79, five mutation probes. **Ownership only: R56 proved this was never a correctness defect, and all 2059 pre-existing tests pass untouched.** |
| **G-02** | C | **`MinimalKernel` is dead** — declared, never constructed. Open since R47. | **DELETED.** Two references repository-wide, both its own declaration and constructor. Certified I-80 that it stays deleted. |
| **NEW** | B | **`lib/core/contracts/repository.dart` was dead AND a latent compile break.** Four abstract contracts, twenty methods, ZERO implementations, reachable only through a barrel re-export — and its `IntentRepository` COLLIDED BY NAME with the live `lib/storage/intent_repository.dart`, so any file importing both would have failed with `ambiguous_import` (the trap R54 hit with a duplicated constant). | **DELETED**, barrel export removed. Identical in shape to the dead `runtime.dart` R47 removed — the barrel still carries R47's comment about that. Certified I-80, including that `IntentRepository` now declares exactly once. |
| **NEW** | C | **`IntentRepository` had no composition owner either** — constructed bare inside `HomeScreen`. Not flagged by R56's audit. | **CLOSED.** Found by I-78 on its first run and composed rather than excluded from the rule. |

## STILL OPEN AFTER IS-R57 — with what R57 tried

| # | Sev | Gap | Status |
|---|---|---|---|
| G-40 | B | Parallel test files share one `anything_experiences.db`; runs intermittently fail with `database is locked` | **STILL OPEN, and R57's explanation FAILED.** I hypothesised the cause was `HomeScreen` building its own `SqliteExperienceRepository` alongside the composition's, fixed it, and measured: **3 failures / 11 runs with the fix, 3 / 11 without.** No improvement — hypothesis disproved. The `HomeScreen` change was kept on ownership grounds only. The real mechanism is still unidentified; the recommended fix remains an injectable database name for `AppComposition.production()`, or per-test databases in widget suites. |
| G-35 | B | Atomicity stops at the repository boundary | Unchanged. |
| G-38 | B | Notification delivery is at-most-once | Unchanged. |
| G-34, G-36, G-39, G-41 | C | `touchLastUsed` writes directly; protection holds a repository for reads; `ThemeProvider` writes directly; stale test databases regrow | Unchanged. |
| **NEW** G-42 | C | **Constructor defaults still permit multiple instances.** `x ?? Repository()` remains everywhere it existed, so a caller that injects nothing still gets its own instance. | **Open by design** (ADR Decision 1). Removing the defaults would change public constructors — forbidden by this milestone — and break every test relying on them. The composition now passes its instance, so the default does not fire in production. Certification distinguishes a defaulted SEAM (allowed) from a BARE construction (forbidden). |
| **NEW** G-43 | C | **`EvolutionCoordinator` is not composed** — and nothing in `lib/` constructs it at all, so its `?? ActivityRepository()` default never fires in production. | **Open, deliberately.** Composing a coordinator nothing constructs would be speculative. Recorded so the asymmetry is visible rather than discovered later. |

## CLOSED BY IS-R56

| # | Sev | Gap | How it was closed |
|---|---|---|---|
| **NEW, found and closed in-milestone** | **A** | **Concurrent notification writes lost data and double-delivered.** Ten concurrent `schedule()` calls stored ONE. Two concurrent `deliverDue()` calls presented the same notification TWICE, breaking the exactly-once contract in that method's own doc comment. | **CLOSED.** `DurableCollectionStore` serialises read-modify-write per storage key; `deliverDue` now CLAIMS inside the critical section and PRESENTS outside it. Measured before and after; both probes are now permanent regression tests. Reachable in production — `NotificationCapability` exposes schedule/cancel to any running Experience while `BackgroundCoordinator` polls `deliverDue`. |
| **NEW** | B | **`IntentRepository.updateStatus`/`delete` silently truncated history to 50.** They read through `list()` (default limit 50) and wrote the result back as the WHOLE history; retention allows 100. With 51–100 records stored, every record past the 50th was discarded on any status update. | **CLOSED.** The mutation now runs against the full stored list inside the critical section, where no display limit applies. Unrelated to concurrency — found because consolidating the pattern put every read and write of that key side by side. |
| **NEW** | C | **Dead code: `lib/storage/local_database.dart`.** `AnythingLocalDatabase` and `AnythingPreferences`, ZERO references in `lib/` or `test/`. `AnythingPreferences` also duplicated theme-mode persistence that `ThemeProvider` really owns — a dead parallel implementation of a live feature. | **DELETED**, following R47's precedent for the dead runtime contract (G-01). |

## OPENED BY IS-R56 — recorded at the moment they were created

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-37 | B | **`ActivityRepository` has no composition ownership.** Constructed in NINE separate places and absent from `AppComposition` — the only repository in the codebase that cannot be injected in production. | `creation_coordinator:147`, `experience_modification_coordinator:84`, `experience_opening_coordinator:76`, `experience_workspace_manager:55`, `intent_session_manager:128`, `evolution_coordinator:44`, `activity_screen:19`, `experiences_screen:81`, `experience_host_screen:240`. | **Open. NOT a correctness defect — proven.** The class is stateless with a `const` constructor and `SharedPreferences.getInstance()` is a process singleton, and the R56 probe confirmed ten concurrent records all survive. It is why R56's lock is keyed by STORAGE KEY rather than by instance: per-instance locking would protect nothing here. Composing it means touching nine call sites across coordinators and UI — a milestone of its own, and the recommended next one. |
| G-38 | B | **Notification delivery is now AT-MOST-once.** If the process dies between the claim and the presentation, that notification is not delivered and will not be retried. | `RealNotificationService.deliverDue` — claim inside the critical section, present outside it. | **Open, deliberately, and it is a TRADE not a regression.** The previous behaviour was at-least-once WITH duplicates, which satisfied neither contract. The method promises exactly once; a duplicate alarm is worse than a missed one. A durable retry (claim → present → confirm) would close it and is recommended only if at-most-once proves too weak in practice. |
| G-40 | **B** | **Test-infrastructure flakiness: parallel test files share ONE `anything_experiences.db`.** Every test that builds `AppComposition.production()` opens the DEFAULT database path, and `flutter test` runs files concurrently, so runs intermittently fail with `SqfliteFfiException(sqlite_error: 5) — database is locked`. | `r43_workspace_experience_switcher_test.dart`, `r44_experience_activation_manager_test.dart` are the usual victims; `AppComposition.production()` passes no `dbName`. | **Open. PRE-EXISTING — established by controlled comparison, not assumed.** The same two files were run 11× on R56 and 11× on R55 HEAD under identical conditions after clearing the test-database directory: **R56 failed 3, R55 failed 2** — statistically indistinguishable, and the failure mode (`database is locked`) is sqflite, which R56 does not touch at all. This supersedes G-24 (R50's non-reproducing failure), which is now explained: it was the same race. **Fix:** give `AppComposition.production()` an injectable database name, or have widget tests use per-test databases the way every R53–R55 suite already does (`_freshDbName()`). Recommended as a near-term milestone — it makes every future full-suite result trustworthy. |
| G-41 | C | **24,699 test databases (1.8 GB) had accumulated** under `.dart_tool/sqflite_common_ffi/`, dating back to 2026-08-02. | Directory listing during the R56 audit. | **Closed for now by deletion** (gitignored scratch), but nothing prevents regrowth: per-test databases are created with unique names and never removed. A `tearDown` that deletes the file it created, or a periodic clean, would stop it. Related to G-40. |
| G-39 | C | **`ThemeProvider` writes `SharedPreferences` directly.** | `design_system/theme/theme_provider.dart`. | **Open, deliberately, and PINNED IN CERTIFICATION rather than silently excluded.** It stores ONE scalar key (the selected theme mode): no read-modify-write, no collection, nothing to serialise. Routing it through a collection store would be ceremony. Pinned so a NEW direct `SharedPreferences` user still fails I-75. |

## CLOSED BY IS-R55

| # | Sev | Gap | How it was closed |
|---|---|---|---|
| **G-30** | **A** | **Committing was not unified** — creation, modification, evolution, protection and a UI screen all wrote to the repository directly | **CLOSED.** `ExperienceCommitFramework` is the ONE writer. All six paths were rerouted (the audit found six, not the five R54 listed — `experiences_screen.dart:270` was deleting Experiences straight from a widget). Certified by I-69: no file in `lib/` outside the framework and the repository may call `savePackage`, `saveMetadata`, `deletePackage`, `saveProtectedEnvelope`, `deleteProtectedEnvelope`, `updateProtectionState`, or a repository `delete`. Mutation-proven three separate ways. **All 2015 pre-existing tests pass unchanged** — ownership moved, behaviour did not. |
| **G-28** | **A** | **The installation transaction was compensating, not atomic** — a crash between the two writes stranded torn state | **CLOSED FOR REPOSITORY COMMITS, and precisely that far.** Task 7's investigation found transaction exposure was justified and achievable without moving ownership: `SqliteExperienceRepository.database` was already public, `Transaction` and `Database` are both `DatabaseExecutor`, so each write method needed ONE optional `using` parameter — additive, defaulted, no caller touched, no schema change. `RepositoryTransactionCoordinator` now runs writes inside one real SQLite transaction. **The security-relevant win:** protection's three sequential writes are now one, so an Experience can no longer be left MARKED PROTECTED WITH ITS PLAINTEXT STILL ON DISK — asserted directly by test. **What is NOT closed:** a repository write is still not atomic with World Model ingestion, engineering-memory persistence or activity records. Those are cross-store, were never in scope, and remain deliberately best-effort. See G-35. |

## OPENED BY IS-R55 — recorded at the moment they were created

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-34 | C | **`touchLastUsed` still writes directly**, from four call sites (`experience_opening_coordinator.dart:128,171,201`, `experiences_screen.dart:89`). | Repository-wide write audit. | **Open, deliberately, and PINNED IN CERTIFICATION rather than silently excluded.** It stamps an access time on an existing row: it persists no package, no metadata record, and no state any rollback could need to restore. Routing four sites through a commit framework to bump a timestamp is ownership ceremony with no ownership benefit. Recorded so the judgement is reviewable rather than discovered later as an inconsistency. |
| G-35 | B | **Atomicity stops at the repository boundary.** A creation's repository write is atomic; the World Model ingestion, engineering-memory save and activity record that follow it are separate and best-effort. | `creation_coordinator.dart`; `docs/architecture/ENGINEERING_MEMORY.md` §Atomicity. | **Open, deliberately and pre-existing.** These are different stores with different lifetimes, and their failures are explicitly non-fatal by design — a bookkeeping failure must never fail a successful creation. Recorded because "commits are atomic" is easy to over-read after R55, and this is exactly where that reading stops being true. |
| G-36 | C | **`ExperienceProtectionService` still holds a repository**, for reads (loading metadata and envelopes). | `protection_service.dart`. | **Open, deliberately.** Certification forbids it from WRITING, not from reading, and the mutation probe confirms a restored write fails. Splitting read from write access would need a repository-side change R55's rules do not permit. |

## CLOSED BY IS-R54

| # | Gap | How it was closed |
|---|---|---|
| G-27 (part) | R53's `dependencies` were transported and resolved by nothing | **PARTIALLY CLOSED.** `ExperienceDependencyPlanner` is the field's first reader: an import declaring a dependency that is not installed is now REFUSED, tested. The other half of G-27 (protection state transported but not restored) remains open and deliberate — see below. Nothing fetches a dependency, and nothing can: that is G-31. |

## OPENED BY IS-R54 — recorded at the moment they were created

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| ~~G-28~~ | **A** | **CLOSED BY IS-R55 — see above.** The installation transaction was COMPENSATING, not atomic. It snapshots prior state at `prepare`, writes at `commit`, and restores the snapshot on failure. If the process dies BETWEEN the two writes, the snapshot dies with it and nothing is left to call `rollback()`. | `InstallationTransaction`; `SqliteExperienceRepository.savePackage`/`saveMetadata` are separate `INSERT … ConflictAlgorithm.replace` calls and `db.transaction` is not exposed. | **Open, and structurally forced.** IS-R54 Task 5 says "Repository unchanged" and Task 12 forbids a persistence migration, so one real SQL transaction was not available. This is exactly why `repair()` exists and why it is tested against the torn state a crash produces. Closing it properly means exposing a transaction on the repository — a real change to a canonical type, correctly deferred to a milestone that is allowed to make it. |
| G-29 | B | **`currentRuntimeVersion` is hand-maintained and can silently drift from `pubspec.yaml`,** which still reads `1.0.0+1` while the branch is v2.0.0. | `ExperienceCompatibilityEvaluator.currentRuntimeVersion = '2.0.0'`. | **Open, deliberately.** Reading the pubspec at runtime needs `package_info_plus`; IS-R54 adds no dependency. It is declared in exactly ONE place and every entry point takes an override, so the blast radius is one line — but nothing mechanically ties it to the pubspec, and a compatibility check against a wrong runtime version is worse than none. Worth a build-time generated constant. |
| ~~G-30~~ | **A** | **CLOSED BY IS-R55 — see above.** Committing was NOT unified. Four sites still write to the repository directly: creation (`creation_coordinator.dart:442`), modification (`experience_modification_coordinator.dart:136, 295, 379`), evolution (`evolution_coordinator.dart:79`) and protection (`protection_service.dart:289`). | Repository-wide `savePackage` scan. | **Open, deliberately and explicitly.** R54 established the owner and moved the ONE path Task 8 names (distribution). Rerouting four coordinators — each with genuinely different pre-conditions — would be replacing architecture, which this milestone's rules forbid. Stated rather than implied, because "there is now one installer" reads as "everything installs through it" and that is false. |
| G-31 | C | **Dependencies are planned but can never be fetched.** A package declaring an uninstalled dependency is simply refused; nothing can supply it. | `ExperienceDependencyPlanner` — no networking, by instruction (Task 4 is architecture only). | **Open by design.** There is no transport for a dependency to arrive on. Refusing is the correct conservative behaviour until one exists. |
| G-32 | C | **Platform compatibility is not actually checked.** `IncompatibilityReason.platformUnsupported` exists and is never emitted. | `ExperienceCompatibilityEvaluator.evaluate`. | **Open, deliberately.** `NetworkMode`/`StorageMode` exist on the manifest, but no device policy exists to check them against. Inventing one would be a fabricated check that looks like enforcement. The reason code is declared so the vocabulary does not need widening later; that it is unused is recorded here rather than left for someone to discover. |

## Gaps IS-R54 found and closed within the same milestone

| # | What happened |
|---|---|
| G-33 | **`experiencePackageVersion` was declared TWICE** — `experience_package.dart:10` and `package_validator.dart:221`, both `const int = 1`, independent. The validator's local declaration shadowed the canonical one, so bumping the package-format version in one place would have left the validator silently enforcing the other. Invisible for as long as nothing imported both libraries; the new installer does, and could not compile (`ambiguous_import`). **The ANALYZER caught it — the fifth time across R46–R54 that something other than the certification layer found the real defect.** Fixed by deleting the duplicate; no consumer imported it from there. |

## OPENED BY IS-R53 — recorded at the moment they were created

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-25 | **A** | **A user still cannot import an Experience.** R53 built a complete, end-to-end-tested distribution pipeline — but it moves `ExperienceDistributionPackage` *objects* and serialises them to JSON. There is no `.anything` file format, no file read or write, no zip, no share-sheet integration. | `lib/app/experience_distribution.dart` — no `dart:io`, no `FileService`, no `RealFileService` reference anywhere in the file. | **Open, deliberately and explicitly.** Stated first in every R53 document, because a working pipeline reads as a shipped feature and it is not one. The pieces exist: `RealFileService` (R49) owns file I/O and `file_picker` is already a dependency. Deferred so this milestone established ownership boundaries before adding a file layer on top of them. |
| G-26 | B | **Nothing verifies publisher signatures, so nothing is ever `verified`.** `MarketplaceMetadata.publisherSignature` is transported and never checked. Every channel — including `marketplace` and `enterprise` — yields `VerificationState.unverified` and classifies as `imported`. | `provenanceFor()`; asserted for all five channels in `test/r53_experience_distribution_test.dart`. | **Open by design, not by omission.** Assigning `verified` because a signature *field* was present is precisely the "assumed rather than computed" failure R52 removed. The honest state is recorded in the data rather than hidden. A real verifier needs a key-distribution decision that is a product question, not an implementation one. |
| G-27 | C | **Protection state is transported but never restored; `dependencies` is transported but never resolved.** An imported Experience is persisted with `isProtected: false` even when the envelope says the source was protected. | `import()`; `ExperienceDistributionManifest.dependencies`. | **Open, deliberately.** Distribution must not fabricate a protected state it cannot honour — the Kaalka ciphertext envelope is not transported, and `ExperienceProtectionService` remains the sole owner of protection. An imported Experience must be re-protected on the receiving device. `dependencies` is declared so the envelope format needs no version bump when dependency resolution arrives. |

## Gaps IS-R50 found and closed within the same milestone

| # | What happened |
|---|---|
| G-23 | **R50 broke a caller of R49's own API.** Removing `RealNotificationService.maxScheduled` invalidated R49's test, which constructed the service with `maxScheduled: 3`. No certification invariant caught it — static checks verify architectural shape, not API compatibility. The **analyzer baseline** caught it, moving 71 → 72 with an `undefined_named_parameter`. The test was migrated to express the same bound as a retention policy; its assertions are unchanged. Fourth time across R46–R50 that something other than the certification layer caught the real defect. |
| G-24 | **An observed, non-reproducing test failure, recorded rather than buried.** One full-suite run reported `r43_workspace_experience_switcher_test.dart` failing with `type 'CreationFailed' is not a subtype of type 'CreationCreated'` — a Kernel creation failure, in the same run that carried the broken R49 test file. It did **not** reproduce: the file passed 14/14 in isolation, and the subsequent clean full run passed 1878/1878. Reported because "it passed the second time" is not the same as "it never failed", and a future recurrence should find this note rather than start from zero. |

## Gaps IS-R49 found and closed within the same milestone

| # | What happened |
|---|---|
| G-21 | **A file id could carry `..`.** `_idFor()` collapsed non-`[A-Za-z0-9._-]` to `_`, which removes path separators — but `.` is in that safe set, so a display name of `../../evil` survived as `.._.._evil`. The path was still *contained* (one segment, so `p.normalize` does not treat it as traversal, and `_resolveInside` would reject it regardless), but an id carrying `..` is a latent hazard the moment any future code joins it with a non-normalising API. Found by a test asserting the stronger property; fixed by collapsing runs of dots rather than by weakening the assertion. |

## Gaps IS-R48 found and closed within the same milestone

| # | What happened |
|---|---|
| G-14 | **`KnowledgeResource.toJson()` silently dropped `content`**, and `fromJson()` never read it — so `fromJson(toJson(r))` returned a resource with `content == null`. A latent round-trip bug in `KnowledgeBundle` serialization (its only consumer) that was harmless while nothing round-tripped resources, and fatal for R48: `canonicalRepresentation()` includes `content`, so a content-less round trip would have produced a DIFFERENT canonical representation after restart. Fixed and directly tested. |
| G-15 | **The certification scanner was blind to string interpolations.** A mutation probe reintroducing timestamp ids as `return 'wwx-${DateTime.now().microsecondsSinceEpoch}';` **passed** certification, because the offending code sat inside a string literal and the stripper blanked string contents wholesale — meaning *any* logic inside `${...}` was invisible to *every* static invariant. The instrument was fixed (interpolations now survive stripping) and a self-certification test added. This is the **third** scanner defect found by mutation or tooling rather than by inspection, after R46's vacuously-passing import scan and R47's incomplete reference search. |
| G-16 | **The restart test had the same blind spot from the other direction.** It extracted once and then only round-tripped the stored value, so it would have passed with timestamp ids too. A stronger test now re-extracts the same page in the second session and requires the fresh id to equal the persisted one — true only if identity is genuinely canonical. |
| G-17 | **Stale rationale in `knowledge_graph_bridge.dart`.** Its R2 doc comment stated `KnowledgeResource.id` is `'wwx-${microsecondsSinceEpoch}'`, "a fresh value on every fetch, by design" — true when written, false since R47. Corrected (documentation only). The R2 *decision* to key the World Graph on `sourceUri` still stands, on stronger footing: a page edited between fetches now correctly yields a different canonical id, and keying on that id would split one real entity into two nodes. |

## A gap R47 created and closed within the same milestone

| # | What happened |
|---|---|
| G-11 | Deleting `lib/core/contracts/runtime.dart` left a **dangling barrel export**. `lib/core/contracts/contracts.dart` re-exported it as `export 'runtime.dart';` — a **relative** path with no `contracts/` segment, which R47's first verification search (for the literal text `contracts/runtime.dart`) never matched. The deletion produced `uri_does_not_exist` and moved the analyzer baseline 71 → 72, which is how it surfaced. The export was removed and invariant I-15 widened to match `import|export` on the anchored bare filename. **Lesson recorded rather than hidden: a "find all references" search must cover `export` and relative paths, not just `import` and package paths.** |
| G-12 | The widened I-15 pattern `[^'"]*runtime\.dart` then matched `anything_runtime.dart` — the LIVE implementation — producing a repository-wide false positive that failed the full suite. Anchored to `(?:[^'"]*/)?<basename>['"]`. **Caught by the full suite, not by inspection.** |

## Open gaps

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-02 | C | **`MinimalKernel` is dead.** `lib/kernel/minimal_kernel.dart` declares it; nothing constructs it. | Repository-wide construction scan: 1 occurrence, its own declaration. | **Still open.** R47's spec scoped Task 1 to the runtime contract specifically. Unlike G-01 this name collides with nothing, so it is inert. Deletion is a candidate for R48 review. |
| G-20 | B | **OS-level BACKGROUND notification delivery is not implemented.** `RealNotificationService` schedules durably, computes due state and delivers in-app (foreground) through the existing `EventBus`. A notification that fires while Anything is not running still requires a platform plugin (`flutter_local_notifications` + timezone database, Android manifest permissions/receivers, iOS `AppDelegate` registration, a notification icon asset). | `lib/capabilities/adapters/notification_service_adapter.dart`. | **Open, deliberately and explicitly.** None of that native configuration can be exercised by `flutter test` (no platform channels) and no device or emulator is available in this environment. Shipping it unverified would LOOK complete while silently never delivering — strictly worse than a documented gap. `background_coordinator.dart` already drew this exact line in its own words ("never fabricating live execution"). The seam is singular and named: `NotificationPresenter`. **R50 should implement it and verify on a real device.** |
| G-04 | A | **`EncryptionManager` bypasses the `ProtectionProvider` contract** (path K-B), reaching `KaalkaService` directly. | `security/encryption_manager.dart:40,45`; consumers `memory/memory_manager.dart`, `screens/kaalka_security_screen.dart`. | Collapsing it into the canonical contract is a real architectural change requiring review. Does **not** violate I-21a — there is still exactly one crypto importer. See `KAALKA_USAGE_MATRIX.md` §2. |
| G-05 | B | **`savePackage()` stores Experience packages in plaintext by default.** Kaalka protection is opt-in per Experience. | `storage/sqlite_experience_repository.dart:172` vs `:292`. | Confirmed deliberate product design, cited in three places in `lib/`. Restated because "Kaalka is canonical" is easily misread as "everything is encrypted". Not a defect; a disclosure. |
| G-06 | B | **`IntentRepository` stores raw user intent text unprotected.** User-authored natural language can be sensitive. | Persistence audit, `KAALKA_USAGE_MATRIX.md` §3. | Product/security decision, out of certification scope. Worth explicit review. |
| G-09 | C | **`FakeKnowledgeProvider` lives in production `lib/`.** | `capabilities/builtin/knowledge_capability.dart:12`. Verified **not** wired in production — `AppComposition:220` wires the real `KnowledgeAcquisitionProviderAdapter`. | **Still open.** Harmless test double in the wrong directory. Hygiene only. |
| G-18 | C | **Persisted knowledge has no size ceiling or eviction.** The durable store grows until `clear()`. Each resource is bounded by `RuntimeSecurityLimits.maxKnowledgeBytes` (200 KB), but the number of rows is not. | `lib/storage/knowledge_repository.dart`. | **Open, deliberately.** IS-R48 Task 5 required reusing existing expiration policies and forbade a second policy engine — and a repository-wide search found the knowledge subsystem has **no** TTL, eviction or staleness rule to reuse. Inventing one would have been exactly the speculative machinery the rules forbid. The honest position: R48 gave persistence the same replace-on-put/clear semantics the in-memory cache always had, and a real retention policy is a deliberate product decision for a future milestone. |
| G-19 | C | **The 3 network-dependent knowledge tests could not run in this environment.** They self-skip when there is no outbound network. | `test/knowledge/performance_test.dart`, `test/knowledge/knowledge_pipeline_production_test.dart`. | **Environmental, not a defect.** They passed during R47's run (network up) and skipped during R48's (network down). They exercise the real DuckDuckGo + WebWeaveX path, so R48's changes to that path are verified only by the injectable-fetcher tests, not against live network. Stated plainly rather than reported as a clean pass. |

## Deliberately closed options — recorded so they are not reopened by accident

| Option | Decision | Reason |
|---|---|---|
| Adopt WebWeaveX runtime graph / memory fabric | **REJECTED** | Would create a second graph and second memory system — direct "no parallel architecture" violation. |
| Route Kaalka crypto through WebWeaveX v5 | **REJECTED** | Would create a second protection path and break I-21a. |
| Put the certification layer in `lib/` | **REJECTED** | Zero runtime value; would ship dead weight and be exactly the speculative parallel machinery the rules forbid. Certified: R46 added nothing to `lib/` (I-34). |
| Add test-only public accessors to `HomeScreen` for identity assertions | **REJECTED** | Production surface for test convenience. Certified structurally instead; recorded as a known limitation. |

## Limitations of the certification itself

| # | Limitation | Impact |
|---|---|---|
| L-01 | The scanner is **textual**, not AST-based. Comments and string literals are stripped (defeating the real false positives in this repo), but a construction via type alias, reflection, or a generic factory would go undetected. | Small, given Dart's static nature and this codebase's plain constructor style. An `analyzer`-package custom lint would close it; not built here to avoid a dev dependency and significant machinery for a pattern the codebase does not use. |
| L-02 | `HomeScreen`'s shared-activation-manager binding is certified **structurally**, not by object identity. | Weaker than an identity assertion; fails loudly if the binding is removed or inverted. See G-07 rationale and `ARCHITECTURAL_INTEGRITY_CERTIFICATION.md` §Known Limitations. |
| L-03 | Allowlists require deliberate maintenance on legitimate architectural change. | Intentional friction — it converts silent drift into an explicit, reviewable decision. |
| L-04 | Dynamic certification does not drive a full end-to-end Experience open. | Covered by R45's own suite rather than duplicated. |

## Closed by R46

| Previously-open item | Now |
|---|---|
| "Every production entry path flows through one pipeline" was prose, verified by hand-run grep | **Mechanically certified** every run (I-02, I-16, I-17), and **proven to fail** via mutation test |
| "Exactly one AI boundary" was prose | **Mechanically certified** (I-18, I-19, I-20) with the honest four-site distinction |
| "Kaalka/WebWeaveX stay behind their adapters" was prose in two architecture docs | **Mechanically certified** (I-21a/b/c) |
| No repository-wide invariant enforcement existed at all | 37 certification tests, ~1.2 s total cost |
