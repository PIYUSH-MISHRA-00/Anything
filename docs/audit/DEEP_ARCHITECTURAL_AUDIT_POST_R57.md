# Deep Architectural Audit — Anything v2.0.0 (post IS-R57)

**Date:** 2026-08-08 · **Branch:** `v2.0.0` @ `1617d29` · **Mode:** audit only,
**no source file modified**

**Scope limit, stated first and not softened:** no ZIP archive was supplied in
this session. This audit covers the working repository (1,147 tracked files)
and its 235-commit history. Archived branches, experimental implementations or
generated artefacts existing *only* inside an unsupplied archive **have not
been examined, and no claim is made about them.** Where a required judgement
could not be reached from the repository, this document says
*"Cannot be established from the repository."*

This audit extends the previous one (`REPOSITORY_WIDE_ARCHITECTURAL_AUDIT.md`)
with passes it did not perform: per-file classification, disposal and resource
ownership, determinism, packaging, and a quantified test audit. Prior findings
were **re-verified, not assumed** — all three headline findings still hold at
the timestamps below.

---

## 1. EXECUTIVE SUMMARY

The architecture is canonical in every ownership dimension eleven milestones
claimed, and this audit verified that independently rather than trusting the
matrices. Ownership, lifetime, dependency direction, AI/crypto boundaries and
persistence ownership are all clean. Dead type surface is 0.24%. There are no
cycles. `Random(` appears **zero** times in `lib/`.

**The problem is not the architecture. It is that nothing enforces it.**

**FINDING 1 — CRITICAL, re-verified 2026-08-08.** CI cannot pass and never
could. `.github/workflows/ci.yml` runs `dart format --set-exit-if-changed` at
step 3 (**exit 1**, 424 of 668 Dart files unformatted) and `flutter analyze` at
step 4 (**exit 1** against the documented 71-issue baseline). GitHub Actions
halts a job at its first failing step, so **`flutter test` has never run in
CI**. All **89** certification invariants and 40+ mutation proofs gate nothing.

**FINDING 2 — HIGH.** The duplicate-declaration invariant iterates
`canonicalConstructionSites.keys` — **13 of 1,263 declared types**. Ten class
names are currently declared twice, invisible to certification.

**FINDING 3 — HIGH.** `lib/core/contracts/knowledge_provider.dart` is dead and
colliding — the *third* instance of a pattern R47 and R57 each deleted a file
for.

**New in this pass — FINDING 4, MEDIUM.** `lib/memory/sqlite_service.dart`
opens a SQLite database and declares **no `close()`**. It is the only
handle-holder in the repository without one.

**New in this pass — FINDING 5, LOW.** Four declared dependencies are imported
nowhere: `url_launcher`, `shimmer`, `record`, `cupertino_icons`.

**Recommendation (§16):** one milestone — repair the gate. It is the largest
architectural value available and the lowest architectural risk, because it
changes no architecture.

---

## 2. REPOSITORY STATISTICS

| Metric | Value | Evidence |
|---|---|---|
| Tracked files | 1,147 | `git ls-files` |
| Dart files / lines | 668 / 121,655 | `lib` 468 / 65,246 · `test` 200 / 56,409 |
| Markdown | 185 (`docs` 148, `lib` READMEs 25, other 12) | file index |
| Design assets | 163 (`design/stitch/`) | `git ls-files design` |
| Platform scaffolding | 127 (ios/macos/android/windows/linux/web) | file index |
| Declared public types (`lib`) | 1,263 | regex scan |
| **Tests passing** | **2,062** (0 skipped) | `flutter test` |
| **Certification invariants** | **89** | suite run 2026-08-08 |
| Analyzer issues | **71** (baseline) | `flutter analyze` |
| `expect()` assertions | 4,759 | test scan |
| Direct dependencies | 22 (**4 unused**) | `pubspec.yaml` vs imports |
| Commits | 235 | `git rev-list --count` |
| Test:source ratio | **0.86:1** by line | derived |

---

## 3. FILE CLASSIFICATION MATRIX

Every tracked file classified. Counts are exhaustive (sum = 1,147).

| Class | Count | Runtime reachable | Examples / notes |
|---|---|---|---|
| **Runtime — core** | 468 `.dart` in `lib` | yes | see subsystem split below |
| **Test — certification** | 1 | test only | `r46_architectural_integrity_certification_test.dart` (89 invariants) |
| **Test — milestone suites** | 55 (`rNN_*`) | test only | R1–R57 behavioural suites |
| **Test — stage suites** | 24 (`stageNN/`) | test only | legacy staged suites; source of all 71 analyzer infos |
| **Test — domain suites** | 120 | test only | `world_model/`, `evolution/`, `knowledge/`, … |
| **Documentation — architecture** | 60 | none | `docs/architecture/` |
| **Documentation — audit/matrices** | 88 | none | `docs/audit/` |
| **Documentation — subsystem READMEs** | 25 | none | `lib/**/README.md` |
| **Documentation — root** | 12 | none | `README.md`, `plan.md`, `design/README.md`, `assets/README.md` |
| **Design artefacts** | 163 | none | `design/stitch/**` — DESIGN.md + html + png mockups |
| **Platform scaffolding** | 127 | build | generated Flutter host projects |
| **Build / CI config** | 8 | build | `.github/workflows/ci.yml`, `pubspec.yaml`, `analysis_options.yaml`, `.metadata`, `.gitignore` ×6 |
| **Assets** | 8 | 1 real | `app_icon.png` + 7 `.gitkeep` placeholders |
| **DEAD — whole file** | 1 | **no** | `lib/kernel/specification/experience_spec_builder.dart` (170 lines, zero importers) |
| **DEAD — symbol in live file** | 2 symbols | **no** | `AcquisitionStatus`, `CreationPhase` |
| **DEAD — contract** | 1 | **no** | `lib/core/contracts/knowledge_provider.dart` |

**`lib` subsystem split (top 12 by line):** `app` 7,075 · `runtime` 6,836 ·
`synthesis` 3,453 · `software_architect` 2,988 · `creation` 2,775 · `kernel`
2,506 · `features` 2,392 · `screens` 2,335 · `storage` 2,300 · `core` 2,247 ·
`evolution` 2,158 · `application_engineering` 2,139.

**No file is unclassified.** `tools/` is listed in the specification and **does
not exist** — stated rather than silently skipped.

---

## 4. COMPLETE DEPENDENCY GRAPH

```
AppComposition.production()                              ← ONE composition root
 ├─ SqliteExperienceRepository ─┬─ WorldModelRepository        (reuses the handle)
 │                              ├─ EngineeringMemoryRepository (reuses the handle)
 │                              └─ ExperienceCommitFramework   ← ONLY writer (R55, I-69)
 │                                   └─ RepositoryTransactionCoordinator
 │                                        ├─ ExperienceProtectionService → Kaalka
 │                                        └─ ExperienceInstallationFramework (R54)
 │                                             └─ ExperienceDistributionFramework (R53)
 ├─ ActivityRepository ┐
 ├─ IntentRepository   ┼─ DurableCollectionStore (R56) → SharedPreferences
 ├─ KnowledgeRepository┘   └─ KnowledgeCache → RetentionPolicyEngine (R50)
 ├─ CredentialVault → FlutterSecureStorage
 ├─ CapabilityPlatform ← OperatingSystemGovernanceEngine (R51)
 │                     ← ExperienceTrustClassifier (R52)
 ├─ ExperienceEntryPipeline (R45) → ActivationManager → SchedulingEngine → RuntimeSupervisor
 ├─ AnythingKernel → ApplicationReasoner → ModelProvider   ← ONE AI boundary
 └─ EventBus

DataRuntime (per Experience) → ExperienceDatabase(experienceId)
AnythingRuntime ← ONE construction site (experience_host_screen.dart:205)
SQLiteService (lib/memory) → its own DB          ← OUTSIDE the composition (§10, §13 C-4)
```

**Back edges:** none. **Cycles:** none. **Cross-layer references:** none
outstanding (R57 removed the last five). **Construction leaks:** one —
`SQLiteService`, reached via `MemoryManager` from `core/context_engine.dart` and
`workflow/workflow_memory.dart`, never composed.

---

## 5. OWNERSHIP MATRIX

| Verb | Owner | Certified |
|---|---|---|
| Compose | `AppComposition` | I-78/79 |
| Construct runtime | `ExperienceHostScreen` (sole site) | R46 |
| **Write Experience state** | **`ExperienceCommitFramework` only** | I-69 |
| Transact | `RepositoryTransactionCoordinator` | I-70 |
| Roll back / Repair | `ExperienceCommitFramework` | I-72/73 |
| Store | `SqliteExperienceRepository` | I-74 |
| Mutate durable collections | `DurableCollectionStore` | I-75/76 |
| Retain | `RetentionPolicyEngine` | I-46/47 |
| Protect / encrypt | `ExperienceProtectionService` (Kaalka) | I-21a |
| Govern | `OperatingSystemGovernanceEngine` | R51 |
| Compute trust | `ExperienceTrustClassifier` | R52 |
| Enforce | `CapabilityPlatform` | R49/51 |
| Activate | `ExperienceEntryPipeline` | I-02/16/17 |
| Distribute (move) | `ExperienceDistributionFramework` | I-57/67 |
| Install / upgrade / compat / deps | `ExperienceInstallationFramework` | I-61…66 |
| Import / Export | distribution → installer → commit | I-67 |
| Migrate | `MigrationExecutor` | I-66 |
| Reason (AI) | `ApplicationReasoner` | R46 |
| Dispose | per-holder (§6) | — |

**Every ownership row traces to source.** No verb has two owners.

---

## 6. LIFETIME MATRIX

| Object | Lifetime | Mutable | Handle | Disposal | Risk |
|---|---|---|---|---|---|
| `SqliteExperienceRepository` | singleton | yes (`Database?`) | **DB** | `close()` declared | production never calls it (§13 L-2) |
| `KnowledgeRepository` | singleton | yes | **DB** | `close()` declared | same |
| `ExperienceDatabase` | **per Experience** | yes | **DB** | `close()`, called by `DataRuntime.dispose()` | **clean** |
| **`SQLiteService`** | ad-hoc | yes | **DB** | **NONE DECLARED** | **leak (§13 C-4)** |
| `WorldModelRepository` | singleton | no own handle | — | n/a | reuses injected repo — correct |
| `EngineeringMemoryRepository` | singleton | no own handle | — | n/a | correct |
| `ActivityRepository` / `IntentRepository` / `DurableCollectionStore` | singleton, **`const`, stateless** | no | — | none needed | **clean** |
| `CredentialVault` | singleton | no | OS keystore | delegated | clean |
| `AnythingRuntime` | per host screen | yes | streams | `dispose()` closes router, controllers, state engine, data runtime | **clean** |
| `ObservationEngine` subscriptions | per session | — | 3 `StreamSubscription` | all retained in `_subscriptions`, all cancelled | **clean** |
| `EventBus` | singleton | yes | `StreamController` | — | app lifetime |

**Balance check:** StreamControllers created 10 / `.close()` 12; Timers 4 /
`.cancel()` 5; `.listen(` 4 (3 retained + cancelled, 1 is `speech_to_text`'s own
API). **No double disposal found. No hidden disposal found.** No screen disposes
a resource it did not create.

---

## 7. ARCHITECTURAL GRAPH — layering

```
UI (features/, screens/, widgets/)
   ↓ composition-sourced only (R57)
Coordinators (app/, evolution/)
   ↓
Frameworks (commit, installation, distribution, governance, trust, retention)
   ↓
Repositories (storage/, security/)
   ↓
Persistence (sqflite, SharedPreferences, FlutterSecureStorage)
   ↓
External (kaalka, webweavex — behind adapters, I-21a/b/c)
```

Direction is strictly downward. Verified: no repository imports a coordinator,
capability, screen or the composition.

---

## 8. CERTIFICATION AUDIT

**89 invariants; all pass (re-run 2026-08-08). Zero stale allowlist paths.**

**Strengths, verified:** scanners strip comments *and* string literals while
preserving `${…}` (the R48 fix); import scans run on **raw** source; several
checks assert non-empty before asserting content; allowlists are pinned with
recorded rationale rather than narrowed.

**BLIND SPOT 1 — HIGH. The duplicate-declaration check covers 13 of 1,263
types.**
```dart
for (final type in canonicalConstructionSites.keys) { … expect(declaring.length, 1) }
```
`knownDuplicateDeclarations` is empty and documented as "no known duplicates" —
true only of those 13. Ten collisions live outside the scan (§11).

**BLIND SPOT 2 — LOW. Two mechanisms guard deleted files.** `removedDeadFiles`
(R47) lists one path; R57's deletions are guarded by a separate hard-coded list
inside its own test. A future deletion could be added to neither.

**BLIND SPOT 3 — MEDIUM. Invariant IDs are not traceable.** `I-NN` appears 12
times across 89 tests, almost always as a *range header* (`I-61 … I-67`). No
test carries its own ID. Every matrix references invariants by number; a
failing test cannot be mapped back without counting positions in a comment.
**`I-79` is referenced in documentation and appears nowhere in the test file.**

**BLIND SPOT 4 — CRITICAL (the meta-finding).** None of this executes in CI
(§1). An invariant that runs only on a developer's machine is a convention with
a test harness attached.

**No obsolete, vacuous, duplicated or bypassable invariant was found.**

**AST opportunity:** the scanner is textual (documented limitation L-01). The
collision scan in §11 took seconds with regex; an `analyzer`-package lint would
be exact but adds a dev dependency. **Not recommended** — regex suffices for
the one check that needs it.

---

## 9. MUTATION AUDIT

40+ probes across R46–R57, reviewed for whether each still proves something.

**Verdict: sound.** Two systemic observations:

1. **Mutation testing has twice caught a defect in a brand-new invariant**, not
   merely in code — R48 (scanner blind to string interpolation) and R56 (an
   *ordering* assertion that should have been a *containment* assertion). That
   is the practice working as designed.
2. **Positive-presence clauses are consistently un-probed and consistently
   disclosed** (R53 I-59/60, R54 I-65, R55, R56, R57 I-79 clause 3). Honest;
   low risk, since such assertions fail by construction when the required thing
   is removed.

**No probe was found that proves nothing.** Probes are correctly deleted after
use — 10 `rNN_mutation_probe.dart` paths appear in docs, none on disk.

---

## 10. DEAD CODE REPORT

Scanned all 1,263 declared public types.

**Method correction, recorded because it changed the result.** A
name-reference count initially flagged 7 candidates. **Four were extensions**
(`BackendEngineeringPlanJson`, `CanonicalImplementationModelJson`,
`SemanticSolutionArchitectureJson`, `SolutionComponentJson`) — invoked
implicitly, so `.toJson()` never names them. Proven **live** by a different
route: none of their receiver types declares its own `toJson`, and each
serialization file has real importers. *A name-reference count cannot decide an
extension's liveness.*

| Item | Evidence | Verdict |
|---|---|---|
| `lib/kernel/specification/experience_spec_builder.dart` | 170 lines, sole declaration, **zero importers of the file**, zero references to the type | **DEAD FILE** |
| `lib/core/contracts/knowledge_provider.dart` | zero direct importers; both implementors resolve the *other* `KnowledgeProvider` | **DEAD CONTRACT** |
| `AcquisitionStatus` (`knowledge_acquisition_engine.dart:32`) | 1 reference: its own declaration | dead enum, live file |
| `CreationPhase` (`creation_engine.dart:14`) | 1 reference: its own declaration | dead enum, live file |
| `url_launcher`, `shimmer`, `record`, `cupertino_icons` | 0 import sites each | **unused dependencies** |
| 7 of 8 `assets/` subdirectories | contain only `.gitkeep`; **pubspec declares no `assets:` block** | empty placeholders |

**0.24% dead type surface (3 of 1,263) — excellent.**

---

## 11. DUPLICATION REPORT

**Ten class names declared in two files each. None caught by certification.**

| Name | A | B | Classification |
|---|---|---|---|
| **`KnowledgeProvider`** | `core/contracts/knowledge_provider.dart:64` | `capabilities/builtin/knowledge_capability.dart:7` | **DEFECT — A is dead** |
| **`ProtectionMetadata`** | `core/contracts/experience.dart:234` | `creation/experience_package.dart:731` | **Suspected dead A** (A's file has 3 importers, all inside `contracts/`) |
| `ExecutionPlan` | `core/contracts/kernel.dart:19` | `kernel/planning/execution_plan.dart:14` | both live (61 vs 7 importers) — collision hazard |
| `ExecutionStep` | `core/contracts/kernel.dart:45` | `kernel/planning/execution_plan.dart:68` | both live — collision hazard |
| `ExperienceFingerprint` | `app/experience_provenance.dart:80` (R52) | `runtime_intelligence/experience_relationship_graph.dart:16` | distinct domains, both live |
| `AnythingPadding` | `design_system/tokens/layout.dart:35` | `design_system/tokens/spacing.dart:56` | **same package, same concern — suspected duplicate** |
| `DependencyGraph` | `feature_discovery/` | `software_cognition/` | distinct domains — acceptable |
| `SemanticEntity` | `synthesis/` | `world_model/` | distinct domains — acceptable |
| `CreationFailed` / `CreationResult` | `app/creation_coordinator.dart` | `creation/creation_engine.dart` | distinct result hierarchies — acceptable |

**`lib/core/contracts/` is the epicentre.** R47 deleted `runtime.dart` from it;
R57 deleted `repository.dart`; three colliding contracts remain. The barrel
still carries R47's comment explaining its own deletion, four lines above two
more instances.

**Every collision is a latent compile break** — the first file importing both
declaring libraries fails with `ambiguous_import`, exactly as R54 hit with a
duplicated constant and R57 with `IntentRepository`.

**No duplicated retention, policy, transaction, protection, installation,
distribution, governance, AI boundary or storage owner found** — those are
canonical.

---

## 12. DOCUMENTATION DRIFT REPORT

| Drift | Severity | Evidence |
|---|---|---|
| CI step named *"0 new errors, 0 new warnings beyond the documented baseline"* performs no baseline comparison; bare `flutter analyze` exits 1 on the baseline itself | **Critical** | `ci.yml:35-36`; measured |
| Certification docs state "no known duplicate declarations" | **High** | true of 13 pinned types; 10 collisions exist |
| `I-79` referenced in matrices, absent from the test file | Medium | §8 blind spot 3 |
| `lib/features/experiences_screen.dart` cited; real path is `lib/features/experiences/experiences_screen.dart` | Low | `RELEASE_CANDIDATE_HARDENING.md:153` |
| `lib/webweavex.dart` cited; no such file (adapter is `lib/knowledge/webweavex_adapter.dart`) | Low | `SOFTWARE_COGNITION_ENGINE.md:52` |

**Not drift:** 14 references to deleted files — each appears in prose
*describing the deletion*. **Not drift:** varying historical test counts
(1,719 … 2,062) — each milestone records its own.

---

## 13. REMAINING GAP MATRIX (fresh; prior matrices ignored)

| # | Sev | Category | Gap | Evidence | Impact / Risk | Canonical solution | Rejected alternatives |
|---|---|---|---|---|---|---|---|
| **C-1** | **CRITICAL** | CI/CD | **CI cannot pass; `flutter test` never runs.** format exit 1 (424/668 unformatted), analyze exit 1; both precede the test step | measured 2026-08-08 | 89 invariants gate nothing; drift ships silently | Format once; make analyze baseline-enforcing; run tests in CI | *Delete the format step* — hides a real inconsistency. *Lower analyze to warnings-only* — weakens the signal |
| **H-1** | HIGH | Certification | Duplicate-declaration check covers 13/1,263 types | certification source | a second `AnythingRuntime`-class type appears silently | Scan all types; pin the 10 with individual justification | *Rename all collisions* — public API churn for no proven defect |
| **H-2** | HIGH | Architecture | `contracts/knowledge_provider.dart` dead + colliding | zero importers; implementors use the other | latent `ambiguous_import` | Delete; remove barrel export in the same commit | *Keep for future use* — speculative; R47/R57 precedent says delete |
| **M-1** | MEDIUM | Testing | Suite flakiness (`database is locked`), ~2–3 per 11 runs, **pre-existing** (measured on R55 and R57 alike) | controlled comparison | CI would be red even after C-1 | Optional `dbName` on `AppComposition.production()`; per-test DBs in widget suites | *Retry-on-failure* — hides a real race |
| **M-2** | MEDIUM | Reliability | `SQLiteService` opens a DB, **declares no `close()`** | `lib/memory/sqlite_service.dart` | one leaked handle for process lifetime; bounded | Add `close()`; call from `MemoryManager` | *Compose it* — it is outside the composition by design; larger change |
| **M-3** | MEDIUM | Certification | Invariant IDs untraceable; `I-79` absent | §8 | a failing test cannot be mapped to its matrix row | Tag every test with `I-NN` | *Renumber* — churns every matrix |
| **M-4** | MEDIUM | Dead code | `experience_spec_builder.dart` — 170-line dead file | zero importers | maintenance noise | Delete with proof | — |
| **L-1** | LOW | Packaging | 4 unused dependencies | 0 import sites each | build weight, supply-chain surface | Remove `url_launcher`, `shimmer`, `record` | *Remove `cupertino_icons`* — Flutter template default; verify iOS first |
| **L-2** | LOW | Lifetime | Production never calls `close()` on composition repositories | `lib` scan | none at app lifetime; contract is test-only | Document as intentional | *Add shutdown hooks* — no proven need |
| **L-3** | LOW | Dead code | `AcquisitionStatus`, `CreationPhase` dead enums | 1 self-reference each | noise | Delete with proof | — |
| **L-4** | LOW | Certification | Two mechanisms guard deleted files | §8 | a deletion could be added to neither | Merge into one list | — |
| **L-5** | LOW | Documentation | 2 wrong paths; 1 unenforced baseline claim | §12 | reader misdirection | Correct | — |
| **L-6** | LOW | Tooling | Test DBs regrow unbounded (24,699 / 1.8 GB cleared at R56) | R56 audit | disk; contributes to M-1 | `tearDown` deleting each created DB | — |
| **L-7** | LOW | Packaging | 7 of 8 asset dirs are empty placeholders; pubspec declares no `assets:` | file index | dead scaffolding | Remove or populate | — |
| **L-8** | LOW | Behavioural | Carried forward, re-verified: atomicity stops at the repository; at-most-once delivery; constructor defaults permit multiple instances | prior matrices | documented trades | none — by design | — |

**Confirmed CANONICAL, no work recommended:** repository ownership, commit
ownership, transaction ownership, runtime construction, AI boundary, crypto
boundary, retention, governance, trust, distribution, installation, durable
collections, dependency direction, disposal (except M-2).

**Determinism:** `Random(` appears **zero** times in `lib/`. 187 `DateTime.now()`
sites remain the sole nondeterminism surface; most canonical paths already
accept an injected `at`/clock.

---

## 14. RISK ASSESSMENT

| Risk | Likelihood | Impact | Driver |
|---|---|---|---|
| Architectural drift ships unnoticed | **Certain today** | **Severe** — eleven milestones' enforcement is advisory | C-1 |
| A duplicate canonical type appears outside the 13 pinned | Moderate | High (silent) | H-1 |
| A future import fails to compile on a collision | Moderate | Low (loud, immediate) | H-1/H-2 |
| Full-suite results mistrusted or mis-attributed | **Observed twice** | Medium | M-1 |
| Formatting churns 424 files and obscures `git blame` | High if careless | Medium | mitigate: one isolated commit |
| Certification sustainability — 89 invariants in one 1,700-line file | Growing | Medium | consider splitting per milestone family after C-1 |
| Test sustainability — 2,062 tests, 56k lines, ~2.5 min | Low | Low | healthy |
| API stability | Low | Low | R53–R57 broke nothing; every seam optional and defaulted |

---

## 15. ARCHITECTURAL TRADE-OFF ANALYSIS

**Formatting 424 files churns history.** Accepted: one isolated commit,
skippable in `git blame`. The alternative — CI permanently red — has already
cost eleven milestones of enforcement.

**Baseline-enforcing analyze uses a hand-maintained number (71).** Same class
as `currentRuntimeVersion` (G-29). Accepted: one number in one file, versus a
step that can never pass.

**Pinning ten collisions rather than renaming.** Renaming touches public API
for types with no proven defect. Pinning makes them visible and fails on an
eleventh. Cost: four acceptable collisions remain permanently.

**Not adopting an AST lint.** Loses exactness on reflection/aliasing; saves a
dependency and machinery for a pattern this codebase does not use. Consistent
with L-01.

**Fixing M-1 before C-1 vs after.** Recommended *within* the same milestone:
turning CI on while the suite is 2–3/11 flaky would train the team to ignore
red.

---

## 16. RECOMMENDED NEXT MILESTONE

### IS-R58 — Make the certification layer actually gate

**One milestone. Justified entirely by evidence:** the repository contains 89
invariants and 40+ mutation proofs whose sole purpose is preventing
architectural regression, and measurement shows CI halts two steps before the
test suite. Repairing that is the **largest architectural value available at
the lowest architectural risk, because it changes no architecture at all.**

Every other finding is smaller, and H-1/H-2 are *only worth doing once a gate
exists to keep them fixed*.

**Explicitly rejected as the next milestone:**
- *A new ownership milestone* — the audit found ownership canonical (§5). Inventing scope would violate the first principle.
- *An AST/lint framework* — §15.
- *Reformatting alone* — fixes step 3, leaves step 4 failing.
- *Renaming the ten collisions* — public API churn for no proven defect.

---

## 17. COMPLETE IMPLEMENTATION PLAN

**Commit 1 — formatting only.** `dart format .` (~424 files). No logic change.
Verify test count still **2,062** immediately after.

**Commit 2 — CI gate.**
- Replace bare `flutter analyze` with a baseline-enforcing step: fail on any
  *error* or *warning*, and on info count > 71.
- Add the certification suite as its own named CI step so a regression is
  legible in the job list.
- Keep `flutter test --coverage`.

**Commit 3 — flakiness (M-1).** Add optional `dbName` to
`AppComposition.production()` — additive and defaulted, the same seam shape R55
used for `DatabaseExecutor`. Widget suites pass a fresh name.
**Re-measure over ≥11 runs. If it does not improve, say so and stop** — do not
iterate on an unproven hypothesis (the R57 lesson).

**Commit 4 — certification blind spot (H-1).** Extend the duplicate-declaration
invariant to all declared types; pin the ten collisions with individual
justifications; mutation-prove by adding an eleventh. **Do not narrow the scan
to make it pass.**

**Commit 5 — dead code (H-2, M-4, L-3).** Delete
`contracts/knowledge_provider.dart` **and its barrel export in the same
commit** (R57's precedent, which avoided R47's dangling export);
`experience_spec_builder.dart`; the two dead enums. Proof recorded per item.

**Commit 6 — resource leak (M-2).** Add `close()` to `SQLiteService`; call it
from `MemoryManager`.

**Commit 7 — documentation (M-3, L-5).** Tag every certification test with its
`I-NN`; reconcile `I-79`; fix the two paths.

**Out of scope, deliberately:** the four acceptable collisions; unused
dependency removal (L-1) unless iOS/macOS builds are verified;
`ProtectionMetadata` and `ExecutionPlan`/`ExecutionStep` disambiguation —
investigate under H-1's pinning, do not rename this milestone.

---

## 18. SUCCESS CRITERIA

- `dart format --set-exit-if-changed .` exits **0**.
- Analyze step **passes** at baseline and **fails** on any new error/warning or
  info count > 71.
- **`flutter test` executes in CI** and reports ≥ 2,062 passing.
- Flake rate re-measured over ≥ 11 runs and reported — improved or not.
- Duplicate-declaration invariant scans **all** declared types; ten collisions
  pinned with individual reasons; mutation-proven by an eleventh.
- `contracts/knowledge_provider.dart` deleted, barrel export removed in the
  same commit, analyzer baseline still 71.
- `SQLiteService.close()` exists and is called.
- Every certification test carries its `I-NN`; `I-79` reconciled.
- **No invariant weakened or removed; no test skipped; behaviour unchanged.**

---

## 19. BACKWARD COMPATIBILITY ASSESSMENT

| Change | Compatibility |
|---|---|
| `dart format .` | **No semantic change** — whitespace only; verified by unchanged test count |
| CI step changes | No source impact |
| `AppComposition.production({String? dbName})` | **Additive, defaulted** — every existing caller unaffected |
| Delete `contracts/knowledge_provider.dart` | Zero direct importers; both implementors use the other declaration. **3 test files import the barrel — must be verified to compile**, exactly as R57 did |
| Delete `experience_spec_builder.dart`, 2 enums | Zero references |
| `SQLiteService.close()` | Purely additive |
| Extend duplicate invariant | Test-only |

**No schema change. No migration. No public API break. No new dependency.**

---

## 20. VALIDATION STRATEGY

1. **Per commit:** `flutter analyze` (expect 71) and `flutter test`
   (expect ≥ 2,062). Commit 1 must show **exactly 2,062** — any deviation means
   formatting changed semantics and must be investigated, not accepted.
2. **Flakiness:** ≥ 11 runs of `r43` + `r44` before and after commit 3, with
   the rate reported either way.
3. **Mutation:** one probe per new invariant; `git add` before probing **and
   re-stage after each revert** (the R56 lesson, where a `stash pop` silently
   invalidated a checkout).
4. **CI:** confirm on a branch push that all three jobs go green — the first
   time in the repository's history.
5. **Tree:** `git status --porcelain` empty at each milestone boundary.

---

## 21. CERTIFICATION UPDATE PLAN

| Invariant | Change |
|---|---|
| Duplicate-declaration (existing) | **Widen** from 13 pinned types to all 1,263 declared; add `knownDuplicateDeclarations` entries for the ten current collisions, each with a one-line justification |
| `removedDeadFiles` | **Merge** R57's separate list into it; add `contracts/knowledge_provider.dart`, `experience_spec_builder.dart` |
| New: CI gate integrity | Assert `ci.yml` contains a baseline-enforcing analyze step and a test step — so the gate cannot be silently removed again |
| All 89 existing | **Unchanged.** None weakened, none removed |
| Labelling | Tag each test with its `I-NN`; reconcile `I-79` |

**Certification count after IS-R58: 89 → ~91.**

---

## 22. FILES EXAMINED APPENDIX

| Area | Files | Depth |
|---|---|---|
| `lib/**/*.dart` | 468 | Repository-wide scans (types, constructions, imports, collisions, disposal, determinism). Read in full: composition root, all 9 repositories, contracts, certification-relevant subsystems, `sqlite_service.dart`, `observation_engine.dart` |
| `test/**/*.dart` | 200 | Indexed; certification suite read in full; scans for skips, weak assertions, private-member access, duplicate names, golden/perf/determinism suites |
| `docs/**` | 148 | Indexed; cross-referenced against source for drift |
| `lib/**/README.md` | 25 | Indexed |
| `.github/workflows/ci.yml` | 1 | **Read in full; every step executed locally** |
| Root config | 7 | Read (`pubspec.yaml`, `analysis_options.yaml`, `plan.md`, `README.md`, `.metadata`, `.gitignore`, `pubspec.lock`) |
| `design/stitch/**` | 163 | **Indexed and classified only** — design mockups, not code; no architectural claim |
| `assets/**` | 8 | Indexed |
| Platform dirs | 127 | **Indexed only** — generated Flutter scaffolding; no architectural claim |
| **Total** | **1,147** | every tracked file classified |

**Not examined, explicitly:** contents of any unsupplied ZIP; `.dart_tool/`
build output (gitignored); remote CI run history — **no access**. The
conclusion that CI fails is derived from *executing its steps locally*, not
from observing a red build. **Whether a CI run has ever been triggered on the
remote cannot be established from the repository.**

---

## 23. EVIDENCE APPENDIX

| Claim | Command / location | Result |
|---|---|---|
| CI format step fails | `dart format --set-exit-if-changed --output=none .` | exit **1**; "Formatted 668 files (424 changed)" |
| CI analyze step fails | `flutter analyze` | exit **1**; "71 issues found" |
| Test step unreachable | `ci.yml:32-39` | format(3) → analyze(4) → test(5) |
| 89 invariants pass | certification suite | "00:13 +89: All tests passed!" |
| 2,062 tests pass | `flutter test` | "All tests passed!" |
| 1,263 declared types | regex over `lib/**/*.dart` | — |
| 10 name collisions | duplicate class declarations | §11 |
| Duplicate check scans 13 | `for (final type in canonicalConstructionSites.keys)` | §8 |
| `KnowledgeProvider` contract dead | zero direct importers; adapter imports `../builtin/knowledge_capability.dart` | §11 |
| `ExperienceSpecBuilder` dead | zero importers of file and type | §10 |
| 4 extensions live | receiver types declare no `toJson`; serialization files imported | §10 (corrected false positive) |
| `SQLiteService` has no `close()` | grep for `close()` in the file | 0 |
| Subscriptions cancelled | `observation_engine.dart:32,56,81,99,133-136` | all 3 retained and cancelled |
| `Random(` in `lib/` | grep | **0** |
| 4 unused dependencies | `pubspec.yaml` vs `package:` imports | `url_launcher`, `shimmer`, `record`, `cupertino_icons` |
| No cycles | no repository imports a coordinator/capability/screen/composition | §4 |
| Ownership canonical | construction census, all 9 repositories | 0 bare constructions |

---

## CONCLUSION

Eleven milestones produced a genuinely canonical architecture, and this audit
verified that independently rather than trusting the matrices that claim it.

The significant discovery is not *in* the architecture but in its
**enforcement**: the mechanism built to protect all of it has never run in CI.
Every "certified" claim is true of the code today and enforced by nobody
tomorrow.

**Fix the gate before putting anything else behind it.**
