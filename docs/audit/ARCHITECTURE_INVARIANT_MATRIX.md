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

**R49 probe B — duplicate registration.** Registering `FileCapability` twice
failed I-40:

```
I-40 Expected: <1> / Actual: <2>
     RealFileService must be constructed exactly once in the composition root; found 2
```

Both probes were reverted and the tree confirmed clean.
