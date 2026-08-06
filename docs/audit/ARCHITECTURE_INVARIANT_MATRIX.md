# Architecture Invariant Matrix — IS-R46

Every row is enforced mechanically by
`test/r46_architectural_integrity_certification_test.dart` on every test run.
"Evidence" names the mechanism, never a human judgement.

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
| I-14 | Every canonical type declared exactly once in `lib/`, except one pinned collision | STATIC | CERTIFIED (1 known exception) |
| I-15 | The dead v1 `AnythingRuntime` contract has zero importers and zero implementors | STATIC | CERTIFIED |

The one exception: `lib/core/contracts/runtime.dart` declares an orphaned
v1-era `abstract class AnythingRuntime` whose shape does not match the live
implementation. Imported by nothing, implemented by nothing. Pinned rather
than hidden; deletion recommended for R47. See
`docs/architecture/ARCHITECTURAL_INTEGRITY_CERTIFICATION.md`.

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
| I-32 | The matcher rejects `MyExperienceHostScreen(` (no false positive) | SELF-TEST | CERTIFIED |
| I-33 | The matcher accepts a real construction (no false negative) | SELF-TEST | CERTIFIED |
| I-34 | R46 added nothing to `lib/` | STATIC | CERTIFIED |

## 8. Mutation evidence

The certification was proven to **fail** by adding a temporary probe file to
`lib/` containing a rogue `Navigator.push(... ExperienceHostScreen ...)` —
exactly the R45 bypass class. I-02, I-16 and I-17 failed immediately and named
the offending file. The probe was then deleted.

A certification that has never been observed failing is not evidence.
