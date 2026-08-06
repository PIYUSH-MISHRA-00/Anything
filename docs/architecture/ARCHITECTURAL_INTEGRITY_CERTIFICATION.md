# Architectural Integrity Certification — Implementation Specification IS-R46

## REALITY

R45 shipped, was documented as complete, and did **not** meet its own success
criterion. `ExperiencesScreen` — the "My Apps" tab, a top-level navigation
destination constructed unconditionally in `AnythingAppShell._screenBuilders`
— bypassed the unified entry pipeline in all three of its Experience-opening
paths. A second audit pass found it.

The root cause was not carelessness. The R45 specification enumerated the
call sites to inspect, and the implementation satisfied **that list** rather
than **the goal**. A list is satisfied by inspection; an invariant is
satisfied only by evidence. Every milestone from R1 to R45 has asserted
architectural properties in prose ("exactly one scheduler", "exactly one AI
boundary") and proved them with hand-run greps recorded in a document. Prose
does not fail a build, and a grep recorded in a document certifies only the
moment it was run.

At R46 the repository contains **462 `.dart` files under `lib/`**. No human
audit of that surface is reliably repeatable, and R45 is the proof.

## PROPOSED

One permanent, mechanical certification layer that proves architectural
invariants from repository-wide evidence, on every test run.

## RATIONALE — why certification is NOT in `lib/`

The specification calls for a "certification layer". It is implemented as a
**test**, not a runtime subsystem, and nothing was added to `lib/` for R46.

Architectural certification is a build-time concern with zero runtime value.
No user benefits from the shipped application scanning its own source code at
runtime. A `lib/certification/` subsystem would add production surface, ship
dead weight to every device, and would itself be precisely the kind of
speculative parallel machinery every milestone since MIS-1 has forbidden. The
enforcement point is therefore `test/r46_architectural_integrity_certification_test.dart`,
which reads the **real** source from disk.

This is itself certified: a test asserts no R46 file exists under `lib/`.

## IMPLEMENTATION

### Two mechanisms

**STATIC.** Every `.dart` file under `lib/` is enumerated from the real
directory tree via `Directory('lib').listSync(recursive: true)`. There is no
hardcoded file list and no filename assumption — a new subsystem in a new
directory is scanned automatically. Comments and string literals are stripped
before matching, then construction sites of each canonical type are collected
and compared against a **pinned allowlist**.

**DYNAMIC.** The real `AppComposition.production()` graph and real widgets are
built, and identity invariants are asserted on live objects.

### Why an explicit allowlist rather than `count == 1`

Reality is not "one construction site" for every canonical type, and pretending
otherwise would force either a false assertion or a dishonest exemption:

- `HomeScreen` legitimately composes a local `ExperienceEntryPipeline`,
  `WorkspaceSchedulingEngine`, `ExperienceActivationManager` and
  `ExperienceOpeningCoordinator` from its own individually-resolved fields, so
  that R32–R44's established per-field test injection keeps taking real effect
  (IS-R45).
- `CertificationRunner` (R23) legitimately builds a second `AnythingKernel`
  **instance** with a fake reasoner and fake provider registry, to compare the
  legacy and compiler pipelines.

Pinning the exact permitted set is both honest about that reality and strictly
**stronger** than a count: it fails on a NEW site even when an old one is
deleted in the same change.

### Scanner self-certification

A certification layer that silently scans nothing reports success forever.
Five tests prove the instrument works before any invariant is trusted:

- the scan really finds >400 real files (it found 462);
- comment stripping really removes doc/line/block comments;
- string stripping really removes type names inside strings — proven on the
  **real** file this guards against, `lib/application_engineering/lifecycle_engineering.dart`,
  which contains the string `'ExperienceOpeningCoordinator (trusted opening)'`
  that a naive grep counts as a construction;
- the matcher does not match `MyExperienceHostScreen(`;
- the matcher **does** match a real construction, so true positives are not
  silently missed.

### Proven to bite — mutation test

A certification that cannot fail is worthless. A temporary probe file was
added to `lib/` containing a rogue `Navigator.push(... ExperienceHostScreen ...)`,
exactly reproducing the R45 bypass class. The certification failed
immediately and named the file:

```
Expected: ['lib/app/experience_entry_pipeline.dart']
  Actual: ['lib/app/experience_entry_pipeline.dart', 'lib/r46_mutation_probe.dart']
```

The probe was then deleted. This is the concrete evidence that R45's
regression would now be caught at CI time rather than by a later audit.

## ARCHITECTURAL CERTIFICATION — what is proven

| Certification | Mechanism | Result |
|---|---|---|
| Exactly one `ExperienceEntryPipeline` (ownership) | static allowlist | CERTIFIED |
| Exactly one `ExperienceHostScreen` construction path | static allowlist | CERTIFIED — the pipeline only |
| Exactly one `WorkspaceRuntimeSupervisor` | static allowlist | CERTIFIED |
| Exactly one `WorkspaceSchedulingEngine` | static allowlist | CERTIFIED |
| Exactly one `ExperienceActivationManager` | static allowlist | CERTIFIED |
| Exactly one `UniversalIntentRouter` | static allowlist | CERTIFIED |
| Exactly one `IntentExecutionPipeline` | static allowlist | CERTIFIED |
| Exactly one `AnythingKernel` production construction | static allowlist | CERTIFIED (+1 fake-reasoner certification instance) |
| Exactly one reasoning boundary | static allowlist of model-invocation files | CERTIFIED |
| Exactly one runtime controller per session | static owner + dynamic supervisor state | CERTIFIED |
| Kaalka behind one adapter boundary | raw-source import scan | CERTIFIED |
| WebWeaveX behind its adapter boundary | raw-source import scan | CERTIFIED |
| No split-brain production graph | dynamic identity assertions | CERTIFIED |

Full detail: `docs/audit/ARCHITECTURE_INVARIANT_MATRIX.md`,
`docs/audit/OWNERSHIP_MATRIX.md`, `docs/audit/CANONICAL_FLOW_MATRIX.md`.

## AI CERTIFICATION — the honest statement of "one reasoning boundary"

The naive invariant ("exactly one `provider.generate(` in `lib/`") is **false**,
and asserting it would have required a dishonest exemption. Reality, verified
by reading every site:

| Site | Nature |
|---|---|
| `lib/synthesis/model_reasoner.dart` | **THE ONE mandatory creation-path boundary** — SemanticApp generation, reached only when `DeterministicReasoner` returns `ReasoningProviderRequired` |
| `lib/kernel/understanding/model_understanding_service.dart` | **Optional and degradable** — falls back to deterministic heuristics when no provider is configured AND when the model call throws |
| `lib/capabilities/adapters/model_provider_ai_adapter.dart` | Runtime AI **capability** offered to generated Experiences |
| `lib/capabilities/builtin/ai_capability.dart` | Runtime AI **capability** offered to generated Experiences |

The certified invariant is therefore precise: **the set of files permitted to
reach a language model is pinned**, exactly one of them is a mandatory
creation-path reasoning boundary, and the optional understanding call is
separately certified to retain **both** of its deterministic fallbacks. Any
new model call anywhere in `lib/` fails CI.

Additionally certified: exactly four `ApplicationReasoner` implementations
exist, and exactly one of them (`ModelApplicationReasoner`) may reach a
provider. `DeterministicReasoner` never does; `CompositeApplicationReasoner`
only delegates; `_FixedReasoner` is a certification fake.

## R46 FINDING — a dead, name-colliding v1 contract

`lib/core/contracts/runtime.dart` declares `abstract class AnythingRuntime`.
The live implementation `lib/runtime/anything_runtime.dart` declares
`class AnythingRuntime`. **These are two different types sharing one name**,
and their shapes do not match:

| | contract | implementation |
|---|---|---|
| `openExperience` | `Future<void> openExperience(ExperienceId id)` | `Future<ExperienceSession> openExperience(ExperiencePackage package)` |

Evidence gathered repository-wide: the contract file is imported by **nothing**
in `lib/` or `test/`, and **nothing** implements or extends it. It is
genuinely dead — orphaned residue of exactly the kind MIS-1 Part 1 documented
in its 50-file dead parallel v1 architecture finding.

**It was deliberately NOT deleted in R46.** R46 is a certification milestone;
deleting production files is outside its stated scope and the stop condition
requires architectural review before further change. Instead the collision is
**pinned** in `knownDuplicateDeclarations` so it is visible in CI rather than
averaged away by a count, and a dedicated test enforces that it **stays**
dead: the moment anything imports or implements it, two live `AnythingRuntime`
types exist and certification fails. Deletion is recommended for R47.

## PERFORMANCE

Real measurements, printed by the test itself:

| Measurement | Value |
|---|---|
| Repository scan (462 files, 2,145 KB stripped source) | ~550 ms |
| Invariant verification (13 types + 3 boundary scans) | ~625 ms |
| **Total certification cost** | **~1.2 s** |

A first implementation took **18.7 s** for the verification pass alone. The
cause was catastrophic regex backtracking in the class-declaration matcher,
whose modifier alternation (`(?:abstract\s+|final\s+|sealed\s+|...)*class`)
backtracked heavily on long files. Matching `\bclass\s+<Type>\b` is both
sufficient (modifiers precede the `class` keyword) and ~30× faster. The test
asserts total cost stays under 30 s — a guard, not a benchmark, so that
certification stays cheap enough that nobody is ever tempted to skip it.

## TEST RESULTS

`test/r46_architectural_integrity_certification_test.dart` — **37 tests**,
all passing:

- 5 scanner self-certification
- 13 static construction-ownership (one per canonical type)
- 2 declaration integrity (including the pinned `AnythingRuntime` collision
  and the dead-contract guard)
- 2 pipeline certification
- 3 AI certification
- 3 external-boundary certification (Kaalka, WebWeaveX, Kernel/UI isolation)
- 6 dynamic certification on the real production graph
- 2 regression / backward compatibility
- 1 performance

Full suite: **1789/1789 passing**, zero regressions. Analyzer: 71 issues,
unchanged baseline, zero in any R46 file.

## KNOWN LIMITATIONS

1. **The static scanner is textual, not an AST analysis.** It strips comments
   and string literals — which defeats the real false positives present in
   this repository — but it is not a resolved-element analyser. A construction
   reached through a type alias, reflection, or a generic factory would not be
   detected. Given Dart's static nature and this codebase's plain constructor
   style, this is a real but small gap. An `analyzer`-package-based custom lint
   would close it and is noted for a future milestone; it was not built here
   because it would add a dev dependency and considerable machinery to catch a
   pattern the codebase does not currently use.

2. **HomeScreen's shared-activation-manager binding is certified structurally,
   not by object identity.** Proving it on live objects requires reading
   `HomeScreen`'s private `_activationManager`, i.e. adding test-only public
   accessors to production code. That was rejected — R46 adds nothing to
   `lib/`. The certification instead asserts the resolution *structure*
   (the `identical(_scheduler, _composition.workspaceSchedulingEngine)` binding
   and the strictly-conditional local-scheduler branch) survives. This is
   weaker than an identity assertion but costs no production surface and fails
   loudly if the binding is removed or inverted.

3. **Allowlists must be maintained deliberately.** A legitimate architectural
   change requires updating both the test and this document. That friction is
   the point: it converts a silent architectural drift into an explicit,
   reviewable decision.

4. **Dynamic certification does not drive a full end-to-end Experience open.**
   It certifies the composed graph's identity invariants and the supervisor's
   initial state; the end-to-end entry behaviour is covered by R45's own suite
   rather than duplicated here.

## IS-R47 — WHAT THE CERTIFICATION LAYER GAINED

R47 acted on this document's own recommendations and extended the layer.
It now runs **41 tests** (was 37).

### New invariants

| # | Invariant | Why |
|---|---|---|
| I-15 (replaced) | The deleted v1 runtime contract is **gone** and cannot reappear — 3 guards | R47 Task 1 deleted it; the debt must not silently return |
| I-15b | `AnythingRuntime` declares exactly once | proves the collision is *resolved*, not tolerated |
| I-15c | The v1 `RuntimeEvent` hierarchy did not return | proves dead **code** was removed, not just a name |
| I-21d | Deterministic serialization reached only via the adapter | R47 Task 4 must not create a second normalization path |
| I-21e | The four closed WebWeaveX surfaces stay closed | enforces R46's deliberate closures instead of merely documenting them |

`knownDuplicateDeclarations` is now **empty**. The map is deliberately kept
rather than deleted with its only entry, so a future collision must be
recorded explicitly instead of silently relaxing the exactly-once rule.

### Two real defects the layer found in itself during R47

Both are reported because they matter more than a clean result.

**1. A "find all references" search that missed a reference.** R47's first
verification searched for the literal text `contracts/runtime.dart` and
concluded the dead file was entirely unreferenced. It was not:
`lib/core/contracts/contracts.dart` re-exported it as
`export 'runtime.dart';` — a **relative** path with no `contracts/` segment,
and an `export` rather than an `import`. The deletion left a dangling
`uri_does_not_exist`, moving the analyzer baseline 71 → 72, which is how it
surfaced. The barrel export was removed and I-15 widened to match
`import|export` on the bare filename.

**2. The widened pattern then over-matched.** `[^'"]*runtime\.dart` also
matches `anything_runtime.dart` — the LIVE implementation, imported across the
codebase — producing a repository-wide false positive. It was caught by the
**full suite**, not by inspection, and fixed by anchoring to
`(?:[^'"]*/)?<basename>['"]`.

The pattern across R46 and R47 is consistent: the dangerous failures of a
certification layer are the silent ones (R46's vacuously-passing import scan,
R47's incomplete reference search), and they are caught by making the
instrument prove itself and by running the whole suite — never by reading the
regex again and feeling confident.

### Mutation certification re-run

Both new invariant families were mutation-proven, not assumed:

- **Probe A** recreated `lib/core/contracts/runtime.dart`. I-15 and I-15b both
  failed and named the file. Re-run again after the anchoring fix, to confirm
  the corrected pattern still bites.
- **Probe B** called `wwx.stableSerialize`/`wwx.normalizeRuntimeValue`
  directly from a rogue file outside the adapter. I-21d failed and named it;
  I-21b failed independently because the probe also imported the package —
  layered defence working as intended.

Both probes were deleted and the tree confirmed clean.

## SUPERSEDED RECOMMENDATIONS (R46 → acted on by R47)

Items 1, 2 and 3 below were **completed by IS-R47**: the dead contract was
deleted, the stale R44 comment corrected, and the `HomeScreen` reactivity gap
fixed. Item 5 (the two production `Fake*` services) and item 4
(`MinimalKernel`) remain open — see `docs/audit/REMAINING_GAP_MATRIX.md`.

## ORIGINAL RECOMMENDATION FOR R47

1. **Delete `lib/core/contracts/runtime.dart`** — dead, unreferenced, and it
   collides with a live canonical type name. One-file deletion, zero
   references, currently held stable by certification.
2. **Correct the stale R44 comment** in
   `lib/app/experience_activation_manager.dart:16-18`, deferred from R45 to
   keep that milestone's unchanged-subsystem proof mechanical. The
   certification layer now enforces mechanically what that comment claims in
   prose, so the comment can be fixed without weakening anything.
3. **Close the `HomeScreen` submit-button reactivity gap** (carried from R45).
4. **Consider retiring `lib/kernel/minimal_kernel.dart`** — `MinimalKernel` is
   declared but never constructed anywhere in `lib/`.
5. **Review the two production `Fake*` services** registered in the real
   composition (`FakeNotificationService`, `FakeFileService`) — see
   `docs/audit/REMAINING_GAP_MATRIX.md`.

**DO NOT START R47 — per this specification's own stop condition, wait for
external architectural review.**
