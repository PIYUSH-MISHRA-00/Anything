# Architecture Invariant Matrix — IS-R46, extended by IS-R47

Every row is enforced mechanically by
`test/r46_architectural_integrity_certification_test.dart` on every test run.
"Evidence" names the mechanism, never a human judgement.

**IS-R47 changes to this matrix**, all in §2 and §5:

- **I-14 tightened.** `knownDuplicateDeclarations` is now **empty**. R47
  deleted `lib/core/contracts/runtime.dart`, so `AnythingRuntime` is declared
  exactly once like every other canonical type. The collision is *resolved*,
  not merely tolerated.
- **I-15 replaced and strengthened.** The old invariant ("the dead contract
  stays unreferenced") became "the dead contract is GONE and cannot
  reappear", with three independent guards, plus **I-15b** (declared exactly
  once) and **I-15c** (the v1 event hierarchy did not return).
- **I-21d and I-21e added** — deterministic serialization stays behind the
  adapter, and the four deliberately-closed WebWeaveX surfaces stay closed.

Legend: **STATIC** = repository-wide source scan (462 `lib/` files, comments
and string literals stripped). **DYNAMIC** = assertion on live objects built
from the real `AppComposition.production()` graph.

## 1. Construction ownership — "exactly one X"

| # | Invariant | Permitted construction sites | Evidence | Status |
|---|---|---|---|---|
| I-01 | Exactly one `ExperienceEntryPipeline` owner | `app_composition.dart`, `home_screen.dart` ¹ | STATIC allowlist | CERTIFIED |
| I-02 | **Exactly one `ExperienceHostScreen` construction path** | `experience_entry_pipeline.dart` **only** | STATIC allowlist | CERTIFIED |
| I-03 | Exactly one `WorkspaceRuntimeSupervisor` | `app_composition.dart` | STATIC allowlist | CERTIFIED |
| I-04 | Exactly one `WorkspaceSchedulingEngine` | `app_composition.dart`, `home_screen.dart` ¹ | STATIC allowlist | CERTIFIED |
| I-05 | Exactly one `ExperienceActivationManager` | `app_composition.dart`, `home_screen.dart` ¹ | STATIC allowlist | CERTIFIED |
| I-06 | Exactly one `UniversalIntentRouter` | `app_composition.dart` | STATIC allowlist | CERTIFIED |
| I-07 | Exactly one `IntentExecutionPipeline` | `app_composition.dart` | STATIC allowlist | CERTIFIED |
| I-08 | Exactly one `ExperienceWorkspaceManager` | `app_composition.dart` | STATIC allowlist | CERTIFIED |
| I-09 | Exactly one `IntentSessionManager` | `app_composition.dart` | STATIC allowlist | CERTIFIED |
| I-10 | Exactly one `ExperienceOpeningCoordinator` owner | `app_composition.dart`, `home_screen.dart` ¹ | STATIC allowlist | CERTIFIED |
| I-11 | Exactly one `AnythingKernel` production construction | `app_composition.dart`, `certification_runner.dart` ² | STATIC allowlist | CERTIFIED |
| I-12 | Exactly one `AnythingRuntime` construction path | `experience_host_screen.dart` | STATIC allowlist | CERTIFIED |
| I-13 | Exactly one `ExperienceRuntimeController` per session | `experience_host_screen.dart` | STATIC + DYNAMIC | CERTIFIED |

¹ `HomeScreen` composes these locally from its own individually-resolved
fields so R32–R44's established per-field test injection keeps taking real
effect (IS-R45). In production, with no per-field overrides, its scheduler
resolves to the composition singleton and its activation manager is bound to
the composition's by an `identical()` check — certified by I-22.

² A second Kernel **instance** with a **fake** reasoner and **fake** provider
registry, used by R23's legacy-vs-compiler equivalence certification. Not a
second AI boundary — certified separately by I-14/I-15.

## 2. Declaration integrity

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-14 | Every canonical type declared **exactly once** in `lib/` — **zero** tolerated collisions | STATIC | CERTIFIED (IS-R47: exception list now empty) |
| I-15 | The dead v1 runtime contract is **deleted** and cannot reappear | STATIC ×3 | CERTIFIED (IS-R47) |
| I-15b | `AnythingRuntime` declares in exactly one file | STATIC | CERTIFIED (IS-R47) |
| I-15c | The v1 `RuntimeEvent` hierarchy did not return | STATIC | CERTIFIED (IS-R47) |

**Resolved by IS-R47 Task 1.** R46 found `lib/core/contracts/runtime.dart`
declaring an orphaned v1-era `abstract class AnythingRuntime` whose shape did
not match the live implementation, and pinned it. R47 re-verified
repository-wide that nothing implemented it and that all six of its symbols
(`AnythingRuntime`, `RuntimeEvent`, `CapabilityExecutionStarted`,
`CapabilityExecutionCompleted`, `ExperienceOpened`, `ExperienceClosed`) were
used nowhere else, then deleted it.

I-15 now enforces three independent guards: the file does not exist on disk,
it is absent from the scanned file set, and **nothing imports *or exports*
it** — matched on the bare filename so a relative path cannot hide a
reference.

That last clause exists because it caught a real miss. R47's first
verification pass searched only for the literal text `contracts/runtime.dart`
and concluded the file was entirely unreferenced. It was not:
`lib/core/contracts/contracts.dart` re-exported it as `export 'runtime.dart';`
— a **relative** path with no `contracts/` segment. The deletion left a
dangling `uri_does_not_exist` and the analyzer baseline moved 71 → 72, which
is how it surfaced. The barrel export was removed and the invariant widened
to `import|export` on the bare filename.

I-15c deliberately pins only the three unmistakably-v1 names.
`ExperienceOpened`/`ExperienceClosed` are **not** pinned: they are plausible
names for future *canonical* workspace events, and this guard exists to stop
dead v1 code returning, not to reserve English words forever.

## 3. Pipeline certification

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-16 | `ExperienceEntryPipeline` is the ONLY file in `lib/` constructing `ExperienceHostScreen` | STATIC | CERTIFIED |
| I-17 | No file outside the pipeline both references `ExperienceHostScreen` and calls `Navigator.push` | STATIC | CERTIFIED |

I-16 is the mechanical form of R45's success criterion. Before R45's second
pass, `experiences_screen.dart` also constructed it in three places. I-17 is
a redundant, clearer-failing restatement — deliberate belt-and-braces on the
invariant that has already failed once in this codebase's history.

## 4. AI / reasoning boundary certification

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-18 | Real model invocation occurs only in 4 pinned files | STATIC (`provider.generate(`) | CERTIFIED |
| I-19 | Exactly 4 `ApplicationReasoner` implementations exist; exactly 1 may reach a provider | STATIC | CERTIFIED |
| I-20 | Intent understanding retains BOTH deterministic fallbacks (no provider; model throws) | STATIC | CERTIFIED |

The four permitted model-invocation files, and why each is permitted:

| File | Nature |
|---|---|
| `synthesis/model_reasoner.dart` | **THE ONE mandatory creation-path reasoning boundary** (SemanticApp generation) |
| `kernel/understanding/model_understanding_service.dart` | Optional, degradable — heuristic fallback on both no-provider and throw |
| `capabilities/adapters/model_provider_ai_adapter.dart` | Runtime AI capability offered to generated Experiences |
| `capabilities/builtin/ai_capability.dart` | Runtime AI capability offered to generated Experiences |

## 5. External boundary certification

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-21a | `package:kaalka` imported only by `security/kaalka_service.dart` | STATIC (raw source) | CERTIFIED |
| I-21b | `package:webweavex` imported only by its 4 documented adapters/analyzers | STATIC (raw source) | CERTIFIED |
| I-21c | No `lib/kernel/`, `lib/features/` or `lib/screens/` file imports either package directly | STATIC (raw source) | CERTIFIED |
| I-21d | WebWeaveX **deterministic serialization/normalization** (`stableSerialize`, `normalizeRuntimeValue`) is called only from `knowledge/webweavex_adapter.dart` | STATIC | CERTIFIED (IS-R47) |
| I-21e | The four deliberately-closed WebWeaveX surfaces stay closed — no runtime graph, memory fabric, workflow runtime, or Kaalka-via-WebWeaveX | STATIC | CERTIFIED (IS-R47) |
| I-35 | `KnowledgeCache` is the **only** `*Cache` class in `lib/` — no second cache, no cache hierarchy | STATIC | CERTIFIED (IS-R48) |
| I-36 | `KnowledgeRepository` is referenced **only** by `KnowledgeCache` and the composition root — persistence cannot be bypassed | STATIC | CERTIFIED (IS-R48) |
| I-37 | The durable store never imports WebWeaveX and hand-rolls no canonical encoder — it persists the canonical form it is *given* | STATIC | CERTIFIED (IS-R48) |
| I-38 | Resource identity is never timestamp-derived — no `microsecondsSinceEpoch`/`millisecondsSinceEpoch` in the adapter, and `_deterministicId` still exists | STATIC | CERTIFIED (IS-R48) |
| I-39 | **No `Fake*` implementation is constructed in the production composition** | STATIC | CERTIFIED (IS-R49) |
| I-40 | `RealNotificationService`, `RealFileService`, `NotificationCapability` and `FileCapability` are each constructed **exactly once** in the composition root | STATIC | CERTIFIED (IS-R49) |
| I-41 | Exactly one real implementation of `NotificationService` and one of `FileService` exist (plus their test doubles) | STATIC | CERTIFIED (IS-R49) |
| I-42 | The real notification service adds **no second notification framework** — it reuses the existing `EventBus` and R35's `NotificationGenerated`, declares no new `AnythingEvent` subtype, and runs no timer of its own | STATIC | CERTIFIED (IS-R49) |
| I-43 | The real file service adds **no duplicate storage system** — it references no sqflite, no experience/knowledge repository and no `SharedPreferences` | STATIC | CERTIFIED (IS-R49) |
| I-44 | Exactly **two** policy engines exist — `WorkspaceLifecyclePolicyEngine` (runtime) and `RetentionPolicyEngine` (data) — and they are **disjoint in both directions** | STATIC | CERTIFIED (IS-R50) |
| I-45 | The retention engine **decides but never deletes** — no `sqflite`/`Database`/`SharedPreferences`/`dart:io`/`File`/`Directory`/`Timer` | STATIC | CERTIFIED (IS-R50) |
| I-46 | **No repository or capability service owns a retention rule** of its own | STATIC | CERTIFIED (IS-R50) |
| I-47 | `KnowledgeRepository` never owns retention — it reports facts (`keySummaries()`) and is told what to drop | STATIC | CERTIFIED (IS-R50) |

**I-44 is the milestone's central decision, made mechanical.** IS-R50 asked
that `WorkspaceLifecyclePolicyEngine` be extended "if that preserves the
established ownership model". It would not have: that engine owns *runtime*
lifecycle (pause/resume/terminate/restore, acting on an
`ExperienceRuntimeController`), its `RuntimePolicyAction` is a closed enum
exhaustively switched over, and widening it with `evict`/`expire` would make
every caller's switch silently incomplete. So retention became a **sibling**
with a disjoint domain — and the disjointness is certified in *both*
directions, because a merged vocabulary would be as much a violation as a
duplicated engine. A third engine of either kind fails outright.

**I-45 is not stylistic.** If the retention engine could delete, it would be a
second storage owner and R48's "the repository is storage only" would quietly
stop being true. If it could hold a `Timer`, it would be a second scheduler
and IS-R50 Task 5's "no second scheduler" would quietly stop being true.
Purity is what makes both promises structural.

**I-47 has two halves that both matter.** The repository must not evaluate
policy — *and* must still expose `keySummaries()`. The tempting fix for a
store that must not decide is to make it blind, and a blind store cannot be
governed at all.

Full detail: `docs/audit/LIFECYCLE_CERTIFICATION.md` and
`docs/architecture/LIFECYCLE_POLICY_ARCHITECTURE.md`.

**I-39 is deliberately scoped to the composition root.** A `Fake*` *class* may
legitimately live in `lib/` beside the abstraction it doubles — what mattered,
and what was true until R49, is that `AppComposition` **constructed** two of
them into the real capability platform. The audited inventory of remaining
`Fake*` classes and why each is permitted is pinned in
`auditedFakeImplementations`.

**I-42 and I-43 are anti-duplication guards, not feature checks.** They exist
because the easiest way to "complete" a capability is to bring a whole second
framework with it. I-42 forbids the notification adapter from declaring an
event subtype or driving its own timer (`NotificationPlanner` and
`BackgroundCoordinator` remain the canonical planning layer); I-43 forbids the
file adapter from touching any other owner's persistence.

**I-35** is enforced structurally rather than by blacklisting names: exactly
one class in all of `lib/` may match `class \w*Cache`. That catches a
`PersistentKnowledgeCache`, a `CachedKnowledgeManager` variant, or any other
parallel cache, without needing to predict what it would be called.

**I-36** is what makes "persistence is an implementation detail" a fact rather
than an intention. `KnowledgeRepository` is a store, not a cache: it has no
lookup policy, no ranking, no deduplication and no expiry. If any file other
than `KnowledgeCache` and `AppComposition` reaches it, something has found a
path around the single canonical cache.

**I-38** exists because the pre-R47 defect (`id: 'wwx-${now.microsecondsSinceEpoch}'`)
is precisely what would silently destroy R48's guarantee: canonical ids could
no longer survive restart, and every restored resource would be a stranger to
its freshly-acquired twin.

**I-21d** is the guard for IS-R47 Task 4. R47 integrated WebWeaveX's canonical
determinism primitives; they must be reached the same way every other
WebWeaveX capability is — through the adapter. A direct call from the Kernel,
the acquisition engine, or the UI would mean a **second normalization path**
had been introduced, which is exactly what Task 4's "no parallel serialization
framework / no duplicate normalization pipeline" rule forbids.
`KnowledgeAcquisitionEngine` therefore normalizes its cache-key queries by
calling `WebWeaveXAdapter.normalizeText()`, never by importing WebWeaveX.

**I-21e** keeps R46's deliberate closures enforced rather than merely
documented: adopting WebWeaveX's runtime graph or memory fabric would create a
second graph and a second memory system, and routing crypto through its Kaalka
v5 surface would create a second protection path and break I-21a.

These three scan **raw** source deliberately: an import URI *is* a string
literal and does not survive comment/string stripping. The first
implementation of this file scanned stripped source and reported zero import
sites — a bug that would have vacuously certified "no Kaalka imports
anywhere". Both tests now additionally assert the result is non-empty, so the
vacuous-pass failure mode cannot recur.

## 6. Runtime graph coherence (dynamic)

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-22 | `HomeScreen` keeps its `identical()` binding to the composition's scheduler/activation manager | STATIC structure ³ | CERTIFIED |
| I-23 | Each canonical service on `AppComposition` is a stable single instance across reads | DYNAMIC | CERTIFIED |
| I-24 | The ONE scheduler supervises through the ONE supervisor | DYNAMIC `identical()` | CERTIFIED |
| I-25 | The ONE scheduler schedules the ONE workspace manager's sessions | DYNAMIC `identical()` | CERTIFIED |
| I-26 | The ONE activation manager activates through the ONE scheduler | DYNAMIC `identical()` | CERTIFIED |
| I-27 | The ONE entry pipeline activates through the ONE activation manager, scheduler, supervisor and workspace manager | DYNAMIC `identical()` | CERTIFIED |
| I-28 | A freshly composed production graph supervises zero runtimes | DYNAMIC | CERTIFIED |

³ Certified structurally rather than by object identity because proving it on
live objects would require adding test-only public accessors to production
code. Rejected: R46 adds nothing to `lib/`. Recorded as a known limitation.

## 7. Meta-invariants — the certification certifies itself

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-29 | The scanner really walks the repository (>400 files; found 462) | SELF-TEST | CERTIFIED |
| I-30 | Comment stripping removes doc/line/block comments | SELF-TEST | CERTIFIED |
| I-31 | String stripping removes type names in strings — proven on the real file it guards | SELF-TEST | CERTIFIED |
| I-31b | Code inside a string **interpolation** SURVIVES stripping — `${...}` is executing code, not prose | SELF-TEST | CERTIFIED (IS-R48) |
| I-32 | The matcher rejects `MyExperienceHostScreen(` (no false positive) | SELF-TEST | CERTIFIED |
| I-33 | The matcher accepts a real construction (no false negative) | SELF-TEST | CERTIFIED |
| I-34 | R46 added nothing to `lib/` | STATIC | CERTIFIED |

## 8. Mutation evidence

A certification that has never been observed failing is not evidence. Every
invariant family below was proven to **fail** under a deliberate mutation,
then the probe was deleted and the tree confirmed clean.

**R46 — pipeline bypass.** A probe file containing a rogue
`Navigator.push(... ExperienceHostScreen ...)` — exactly the R45 bypass class.
I-02, I-16 and I-17 failed and named the file:

```
Expected: ['lib/app/experience_entry_pipeline.dart']
  Actual: ['lib/app/experience_entry_pipeline.dart', 'lib/r46_mutation_probe.dart']
```

**R47 probe A — resurrect the deleted contract.** Recreating
`lib/core/contracts/runtime.dart` failed **two independent** invariants:

```
I-15  Expected: false / Actual: <true>
      lib/core/contracts/runtime.dart was deleted by IS-R47 and must not be recreated.
I-15b Expected: ['lib/runtime/anything_runtime.dart']
      Actual:   ['lib/core/contracts/runtime.dart', 'lib/runtime/anything_runtime.dart']
```

**R47 probe B — a rogue second normalization path.** A probe calling
`wwx.stableSerialize`/`wwx.normalizeRuntimeValue` directly, outside the
adapter, failed I-21d:

```
Expected: ['lib/knowledge/webweavex_adapter.dart']
  Actual: ['lib/knowledge/webweavex_adapter.dart', 'lib/r47_mutation_probe_b.dart']
Deterministic serialization/normalization must stay inside the WebWeaveX adapter boundary.
```

It independently failed I-21b as well, since the probe also imported
`package:webweavex` — layered defence working as intended.

**R48 probe A — duplicate cache + parallel persistence + WebWeaveX escape.**
A single probe declaring `class PersistentKnowledgeCache`, calling
`KnowledgeRepository` directly, and importing `package:webweavex` failed
**four** independent invariants at once — I-21b, I-21d, I-35 and I-36:

```
I-35 Expected: ['lib/knowledge/knowledge_acquisition_engine.dart:KnowledgeCache']
     Actual:   [... 'lib/r48_mutation_probe_a.dart:PersistentKnowledgeCache']
I-36 Expected: [app_composition.dart, knowledge_acquisition_engine.dart]
     Actual:   [... 'lib/r48_mutation_probe_a.dart']
```

**R48 probe B — timestamp identity, and the blind spot it exposed.** This is
the most important entry in this section. Reintroducing

```dart
return 'wwx-${DateTime.now().microsecondsSinceEpoch}';
```

into the adapter **did not fail certification**. The offending code sat inside
a **string interpolation**, and the scanner blanked string contents wholesale
— so any logic written inside `${...}` was invisible to *every* static
invariant, not just this one.

The instrument was fixed rather than the test: interpolated regions are now
copied through as code (I-31b covers this, including proof that a construction
hidden inside an interpolation is now caught, while surrounding prose is still
stripped). With the fix in place, probe B fails as it should:

```
I-38 Expected: false / Actual: <true>
     timestamp-derived resource ids returned; canonical ids could no longer
     survive restart
```

The behavioural suite had the same blind spot from a different direction: the
restart-equivalence test extracted **once** and then only round-tripped the
stored value, so it would have passed with timestamp ids too. A stronger test
was added that re-extracts the same page in the second session and requires
the fresh id to equal the persisted one — which is only true if identity is
genuinely canonical.

**R49 probe A — reintroduce a production fake.** Changing the composition root
back to `FileCapability(service: FakeFileService(), ...)` failed **two**
invariants:

```
I-39 Expected: empty / Actual: ['FakeFileService']
     AppComposition constructs Fake* implementation(s) in the real production graph
I-40 Expected: <1> / Actual: <0>
     RealFileService must be constructed exactly once in the composition root
```

**R50 probe A — a parallel retention engine.** A file declaring
`class ParallelRetentionEngine` failed I-44:

```
Expected: [retention_policy_engine.dart:RetentionPolicyEngine,
           workspace_lifecycle_policy_engine.dart:WorkspaceLifecyclePolicyEngine]
Actual:   [... , lib/r50_mutation_probe.dart:ParallelRetentionEngine]
A parallel lifecycle/retention engine appeared
```

**R50 probe B — a repository re-inventing a bound.** Restoring
`static const int _maxRecords = 100;` to `IntentRepository` failed I-46:

```
Expected: empty
Actual:   ['static const int _maxRecords']
lib/storage/intent_repository.dart re-invented a retention bound
```

**R50 — what certification did NOT catch.** Removing
`RealNotificationService.maxScheduled` broke R49's own test, which passed it.
No invariant here detected that: static certification checks architectural
shape, not API compatibility. The **analyzer baseline** caught it, moving
71 → 72 with an `undefined_named_parameter`. Fourth time across R46–R50 that
something other than this layer caught the real defect — the layer is one
mechanical check among several, not the only one.

**R49 probe B — duplicate registration.** Registering `FileCapability` twice
failed I-40:

```
I-40 Expected: <1> / Actual: <2>
     RealFileService must be constructed exactly once in the composition root; found 2
```

Both probes were reverted and the tree confirmed clean.

## IS-R51 — Governance invariants

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-48 | Exactly **three** policy engines — runtime lifecycle (R39), retention (R50), governance (R51) — mutually **disjoint** | STATIC | CERTIFIED |
| I-49 | The governance engine **decides but never enforces** — no I/O, no storage, no `Timer`, no provider, and an **empty import list** | STATIC | CERTIFIED |
| I-50 | Exactly **one** Experience trust model; **no** duplicate permission/authorization framework | STATIC | CERTIFIED |
| I-51 | The **Kernel** and the **repositories** never own or evaluate governance | STATIC | CERTIFIED |

**I-49 contains the strongest clause in the whole matrix:** the governance
engine must import NOTHING. A policy that depends on a subsystem is not a
policy, it is that subsystem''s extension. Forbidding every import is a cheap,
absolute way to keep governance a pure decision layer — the same bargain that
made R50''s retention engine safe to trust with every retention decision.

**I-48 keeps three engines from becoming three overlapping owners.** Governance
may not name `CapabilityPlatform`, deliberately: the platform asks governance,
never the reverse. A dependency in the other direction would make governance a
second capability platform.

**I-50 pins TWO trust enums, and that is correct.** `ExperienceTrustLevel`
(R51) grades an Experience''s authority; `TrustLevel` in
`knowledge_resource.dart` grades a retrieved web source''s reliability and
feeds ranking. Collapsing them would be worse than leaving them separate — an
Experience''s privileges and a web page''s credibility are not the same scale.
The first draft of this invariant asserted exactly one and failed on the
pre-existing enum; the fix was to pin both with rationale, NOT to narrow the
regex until the failure disappeared, which would have destroyed the
invariant''s ability to catch a real duplicate.

**R51 mutation evidence.** Probe A (a `ParallelGovernanceEngine` plus a
duplicate trust enum) failed I-48 and I-50. Probe B (a `PermissionManager`
alone) failed I-50''s permission clause independently, proving it is not
masked by the trust assertion preceding it. Both reverted; tree clean.

Full detail: `docs/audit/GOVERNANCE_CERTIFICATION.md`,
`docs/architecture/GOVERNANCE_ARCHITECTURE.md`,
`docs/audit/GOVERNANCE_USAGE_MATRIX.md`.

## IS-R53 — Distribution invariants

| # | Invariant | Evidence | Status |
|---|---|---|---|
| I-57 | Exactly ONE distribution framework and ONE package verifier | STATIC | CERTIFIED |
| I-58 | Distribution never computes trust, enforces governance, activates a runtime, or protects | STATIC | CERTIFIED |
| I-59 | The verifier DELEGATES structural validation to `ExperiencePackageValidator` and never computes trust | STATIC | CERTIFIED |
| I-60 | The distribution manifest EMBEDS the canonical `ExperienceManifest` rather than re-declaring it | STATIC | CERTIFIED |

**I-58 has a deliberately long forbidden list** — trust (R52), governance
(R51), activation (R45) and protection (Kaalka). A distribution layer is the
most tempting place in the system to "just also" do the next step, because it
already holds the package.

**I-59 makes "no second verifier" mechanical** by requiring the literal
`ExperiencePackageValidator.validate` call to be present. Delegation is
required, not merely intended.

**I-60 makes "exactly one Experience Manifest" mechanical** with two clauses:
exactly one class of that name exists, AND the envelope declares a field of
that type. The second clause is what distinguishes embedding from
duplicating — a parallel record copying `experienceId`/`name`/`version` would
pass the first and fail the second.

**R53 mutation evidence.** Probe A (an `ExperienceImportPipeline` plus a
second verifier) failed I-57. Probe B (a `trustFor()` on the verifier) first
failed to COMPILE — distribution has no import for `ExperienceTrustLevel`, so
the type system caught it before certification did — then, with the import
added, failed I-58 explicitly. Both removed; tree clean.

## IS-R54 — Canonical Experience Installation Framework (I-61 … I-67)

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-61 | Exactly ONE installation framework, ONE compatibility evaluator, ONE dependency planner | STATIC | CERTIFIED |
| I-62 | The installer never computes trust, enforces governance or performs distribution | STATIC | CERTIFIED |
| I-63 | The evaluator and the planner are PURE — they cannot install | STATIC | CERTIFIED |
| I-64 | INSTALL NEVER ACTIVATES | STATIC | CERTIFIED |
| I-65 | The transaction DELEGATES structural validation to the canonical validator | STATIC | CERTIFIED |
| I-66 | No second migration engine; the installer executes none | STATIC | CERTIFIED |
| I-67 | DISTRIBUTION NEVER COMMITS — the commit moved to the installer | STATIC | CERTIFIED |
| — | The installer REQUESTS protection and never performs it (Task 7) | STATIC | CERTIFIED |

**I-57 tripped on itself, and was widened rather than narrowed.** R53's pattern
already matched `Install`, so `ExperienceInstallationFramework` failed it on the
first run — the invariant working, not a false positive. The pinned set moved
from two entries to three with the reason recorded in the test; the regex was
not touched, so a fourth mover still fails. Fifth occurrence of this pattern
across R47–R54.

**I-63 is a class-body check, not a file check.** The framework, the evaluator
and the planner share one file and the framework legitimately holds a
repository, so a whole-file assertion would be either impossible to satisfy or
vacuous. Certification brace-matches each class body and asserts non-empty
first, so a rename fails loudly instead of certifying nothing.

**I-66 exists because the migration engine already did.** `MigrationExecutor`
and `DataMigrationPlan`/`MigrationValidator` run real transactional operations
against a real database. R54's `MigrationRequirement` RECORDS that a boundary
was crossed and executes nothing — certified both ways: exactly one engine
exists, and the installer may not name `MigrationExecutor`, `DataMigrationPlan`,
`MigrationOperation` or `ALTER TABLE`.

**R54 mutation evidence.** Seven probes, all failed as required. A (parallel
installer), A2 (duplicate compatibility evaluator) and A3 (duplicate dependency
planner) were run SEPARATELY because `expect` short-circuits — probing only the
first clause would have left the other two unproven. B (installer computing
trust) failed I-62. C (installer naming `Navigator`) and D (installer holding a
`ProtectionProvider`) both failed to COMPILE first — the type system enforcing
the boundary ahead of certification, as in R53 — then failed I-64 and the Task 7
boundary once their imports were added. E (restoring `savePackage` in
distribution) failed I-67. Everything was `git add`-ed BEFORE probing this time,
so `git checkout --` could actually revert each one; on R53 the target file was
untracked and the revert silently no-opped.

## IS-R55 — Canonical Experience Commit Framework (I-68 … I-74)

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-68 | Exactly ONE commit framework and ONE transaction coordinator | STATIC | CERTIFIED |
| I-69 | **NOBODY outside the commit framework writes to the Experience repository** | STATIC | CERTIFIED |
| I-70 | EVERY write inside the commit framework runs in a transaction | STATIC | CERTIFIED |
| I-71 | The commit framework persists and does nothing else | STATIC | CERTIFIED |
| I-72 | Exactly ONE rollback owner — every other rollback delegates | STATIC | CERTIFIED |
| I-73 | Exactly ONE repair owner — the installer requests | STATIC | CERTIFIED |
| I-74 | The repository stores only and does not know the framework exists | STATIC | CERTIFIED |

**I-69 is what closing G-30 actually means** — not "a commit framework exists"
but "nothing else can write". The audit found SIX writers, one more than R54
listed: a UI screen was calling `repository.delete` directly.

**`touchLastUsed` is PINNED, not omitted.** It stamps an access time on an
existing row and holds no state a rollback could need. The exclusion and its
reason live in the test, and it is recorded as G-34 for review.

**I-70 exists because a dropped `using:` would ship silently.** Both rows would
still land, every functional test would still pass, and only the atomicity
guarantee would be gone. Certification extracts each write's arguments and
requires the executor — after first asserting the scan found at least seven
sites, so a regex that stopped matching fails loudly instead of certifying
nothing.

**I-72/I-73 pin FILES, not method counts.** Four rollbacks and two repairs
exist, correctly: the extras are façades in installation, modification and
transaction vocabulary. An invariant demanding one method would have forced
deleting API callers legitimately use. Combined with I-69 — only one file can
write — "exactly one owner" is mechanically true.

**R55 mutation evidence.** Five probes, all failed as required. A (a second
commit framework) failed I-68. B (creation writing directly) **would not
compile** — creation's repository field was removed once its writes moved, so a
direct commit does not typecheck; the type system is the guard there and
certification is the guard for paths that still hold a repository for reads.
B2 (protection writing directly) and C (the UI delete restored) both failed
I-69. D (one `using: txn` dropped inside the framework) failed I-70 — and is
the probe worth remembering, because the code still worked and every functional
test still passed; only the guarantee was gone.

## IS-R56 — Durable Collection Ownership (I-75 … I-77)

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-75 | Exactly ONE durable collection store; nothing else imports `SharedPreferences` for a collection | STATIC (raw source) | CERTIFIED |
| I-76 | Every durable collection mutates through the ONE store | STATIC | CERTIFIED |
| I-77 | `deliverDue` CLAIMS before it PRESENTS | STATIC (containment) | CERTIFIED |

**R56 was an audit-first milestone and the audit overrode its own title.** It
is specified as "Canonical Runtime Import Framework"; the scan found runtime
creation ALREADY singular (one construction site) and import settled in
R53/R54. Per the specification's first principle, R56 implemented what the
evidence showed instead.

**The defect was MEASURED before any code was written**: ten concurrent
`schedule()` calls stored ONE, and two concurrent `deliverDue()` calls
presented the same notification TWICE, breaking the exactly-once contract in
that method's own doc comment. The same probe showed `ActivityRepository` did
NOT lose events — disproving half the hypothesis — so R56 claims a proven
defect only for the notification paths.

**I-75's import scan runs on RAW source**, because import URIs are string
literals that do not survive stripping. This is R46's lesson applied by
default; both of that milestone's boundary scans once reported ZERO sites for
exactly this reason.

**I-77 WAS WRONG ON ITS FIRST ATTEMPT AND THE MUTATION PROBE CAUGHT IT.** It
originally asserted `indexOf(present) > lastIndexOf(store.update)`. Moving
presentation INSIDE the mutation callback — the exact defect — still satisfies
that, because the callback text begins after `store.update(` starts. A false
negative: green, checking nothing. Rewritten as a CONTAINMENT check over
balanced-parenthesis call ranges, after which the probe failed as required.
Generalised lesson: an ordering assertion is not a containment assertion, and
text position is a poor proxy for scope.

**R56 mutation evidence.** Three probes, all failed as required. A (presentation
moved back inside the critical section) failed I-77 — and with the shipped
design the R49 shape cannot even be written, because the store's mutation
callback is synchronous and an `await` inside it does not compile; the probe
calls `present` unawaited instead, and I-77 still catches it. B (a second
durable collection store) failed I-75. C (a repository reaching past the store
to `SharedPreferences`) failed I-76.

**A DESIGN THAT SHIPPED IN REVIEW AND FAILED, recorded so it is not retried.**
R56's first store serialised callers through a STATIC per-key future chain with
an async mutation callback. It DEADLOCKED: `flutter_test` disposes a zone
between tests, and a chain entry left by one test was awaited forever by the
next. The suite went from 2 minutes to 12 with eleven failures, and a single
14-test file ran past ten minutes. The fix was not a better lock — the lock
existed only to survive a yield that its own async callback reintroduced.
Making the callback synchronous removed the yield, the lock, the static state
and the deadlock together.

## IS-R57 — Repository Composition Ownership (I-78 … I-80)

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-78 | Every repository is constructed ONLY in its approved sites | STATIC | CERTIFIED |
| I-79 | `AppComposition` owns exactly ONE `ActivityRepository` and hands it out | STATIC | CERTIFIED |
| I-80 | The dead repository contracts and `MinimalKernel` are gone and stay gone | STATIC | CERTIFIED |

**I-78 is about SEAMS, not locations.** A construction preceded by `??` or
`const` is a defaulted injection seam — the pattern used since R32 — and is
allowed. A BARE construction is not: production cannot share the composition
instance and a test cannot substitute one. That distinction is what lets the
rule be enforced without the API break this milestone forbids. The nine
pre-R57 `ActivityRepository` sites split six seams / three bare.

**The invariant found a defect on its first run.** `IntentRepository` was
constructed bare in `HomeScreen` and had no composition owner either — missed
by R56's audit. It was composed, not excluded.

**I-79 has three clauses because one would be decoration**: exactly one
construction, exposed as a field, AND passed to at least four coordinators. A
composition can satisfy the first two and still hand nothing out, leaving every
consumer on its default. Ownership nobody receives is not ownership.

**I-80 records a SECOND dead file the specification did not anticipate.**
`lib/core/contracts/repository.dart` held four abstract contracts with twenty
methods, ZERO implementations, reachable only through a barrel re-export — and
its `IntentRepository` COLLIDED BY NAME with the live storage repository, so
importing both would have failed with `ambiguous_import`. Identical in shape to
the dead `runtime.dart` R47 deleted, and the barrel still carries R47's comment
about that removal. Deleted alongside `MinimalKernel` (G-02, open since R47).

**R57 mutation evidence.** Five probes, all failed as required: A (bare
construction from UI) and C (from the runtime layer) and E (from a capability)
failed I-78; B (double registration) failed I-79; D (registration removed)
WOULD NOT COMPILE — it now breaks the build in three places, because consumers
RECEIVE the instance instead of building their own. The type system became the
stronger guard only once the ownership was real, exactly as in R55.
