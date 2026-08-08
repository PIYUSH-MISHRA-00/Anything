# IS-R61 — Canonical Experience Execution Contract Framework

**Milestone report.** Branch `v2.0.0`.

---

## 1. Executive summary

IS-R61 asked for "EXACTLY ONE execution contract" and stated that "no subsystem
may define its own execution semantics".

**The Phase 1 audit found that eight of the nine concepts Phase 2 listed already
existed, were owned, and in four cases were already certified exactly-once.**
Creating them would have produced a second manifest, a second compatibility
evaluator and a second governance surface — forbidden by this specification's
own ABSOLUTE RULES and contradicted by its own success criteria.

Exactly one concept was absent from `lib/` entirely: an execution **mode**.

So R61 built the contract as a **derivation**: `ExperienceExecutionContract`
embeds the canonical `ExperienceManifest` and reads identity and capabilities
*through* it, re-declaring no capability field, and adds only what was missing —
`ExecutionMode`, `ExecutionRequirements`, `InterruptionPolicy`,
`IsolationPolicy` and `recoverable`.

The load-bearing property is that the contract is **declarative only**. A
contract travels inside a package, and a package is untrusted input; a contract
that could decide its own eligibility would be a governance engine reachable by
anyone able to write a manifest.

| | |
|---|---|
| Files added to `lib/` | **1** (`app/experience_execution_contract.dart`) |
| Files modified in `lib/` | **0** |
| New tests | 17 (R61 suite) + 2 certification invariants |
| Certification suite | 97 → **99** |
| Full suite | 2,085 → **2,104**, all green (2,104 measured; 2,085 is 2,104 less the 19 tests R61 added) |
| Analyzer | 0 errors / 27 warnings / 43 infos — **unchanged, at baseline** |
| Mutation probes | 5 written, 5 failed as required (plus 1 discarded as invalid) |
| WebWeaveX / Kaalka | **untouched** |

---

## 2. Phase 1 — what the audit actually found

| Phase 2 asked for | Already owned by | Since | Certified |
|---|---|---|---|
| required / optional capabilities | `ExperienceManifest` | R53 | I-60 |
| compatibility requirements | `ExperienceCompatibilityEvaluator` | R54 | I-61 |
| suspension / resume / termination | `RuntimePolicyAction` + `WorkspaceLifecyclePolicyEngine` | R39 | — |
| background ELIGIBILITY | `BackgroundExecutionRule` (`GovernanceRule`, trust floor `local`) | R51 | — |
| capability ENFORCEMENT | `CapabilityPlatform` | R49/R51 | I-49 |
| activation | `ExperienceEntryPipeline` | R45 | I-02/I-16/I-17 |
| scheduling | `WorkspaceSchedulingEngine` | R38 | — |
| identity / provenance | `ExperienceTrustClassifier` | R52 | — |
| **execution mode** | **nothing** | — | — |

The mode finding is evidence-backed, not an impression:

```
grep -rnE "enum \w*(Mode|ExecutionMode)\b" lib
  → ProtectionTimeSeedMode, TimeSeedMode, NetworkMode (×2),
    StorageMode, AnythingThemeMode, FormMode, CompilationMode
```

None describes execution. `ExperienceRuntimeType`
(`lib/core/contracts/experience.dart`) is not a counterexample: its values are
`auil` / `flutter` / `web` / `hybrid`, which describe RENDERING, and it sits in
the unreachable v1 contracts set IS-R59 classified EXPERIMENTAL.

---

## 3. What was built

See `docs/architecture/EXPERIENCE_EXECUTION_CONTRACT.md` for the full
specification (contract, modes, validator, capability matrix, lifecycle
mapping) and `docs/architecture/ADR_R61_CANONICAL_EXECUTION_CONTRACT.md` for
the decision record.

In brief:

* `ExecutionMode` — 5 declarable, 2 RESERVED and **refused** by the validator.
* `ExecutionRequirements` — all fields optional; `null` means *not declared*,
  never *no limit*.
* `InterruptionPolicy` — mirrors `RuntimePolicyAction`'s vocabulary **without
  importing it**. Shared vocabulary, separate authority.
* `IsolationPolicy` — `standard` (real, via per-Experience `ExperienceDatabase`)
  and `strict` (reserved, inert).
* `ExperienceExecutionContract` — embeds the manifest; `contractVersion = 1`;
  JSON round-trip with unknown-enum degradation.
* `ExperienceExecutionValidator` — `const`, zero dependencies, six fault kinds,
  internal consistency only.

`defaultFor()` gives an Experience that declares nothing a truthful
`foreground` contract — which is every Experience in this repository today.
That is what makes the contract adoptable without touching creation.

---

## 4. Validation report

Every command run against the final tree.

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | 655 files, **0 changed** |
| `tool/analyze_gate.sh` | `0 error(s), 27 warning(s), 43 info(s)` — **at baseline, PASS** |
| `flutter test test/r61_experience_execution_contract_test.dart` | **17/17** |
| `flutter test test/r46_architectural_integrity_certification_test.dart` | **99/99** |
| `flutter test` (full) | **2,104 / 2,104** |

### The one failure, and what it was

The first full run reported `+2103 -1`: one R34 notification test
(`no notification is ever generated for the ACTIVE session`).

* the same file in isolation: **15/15 pass**
* a clean full re-run: **2,104/2,104 pass**

Non-deterministic under contention, absent on re-run — the **G-40** family
already recorded as HIGH since R58. R61 changed nothing it touches. It is
reported here rather than omitted, because a full run that failed once is not a
full run that passed.

### Mutation certification

An invariant that has never been made to fail is a claim, not a check.

| Probe | Invariant | Result |
|---|---|---|
| second class `ExperienceExecutionContract2` | I-89 | **FAILED as required** |
| manifest field replaced with copied `_copiedId` / `_copiedRequired` | I-89 | **FAILED as required** |
| second `ExperienceManifest` declared in the file | I-89 | **FAILED as required** |
| `CapabilityPlatform?` field added to the contract | I-90 | **FAILED as required** |
| reference to `ExperienceCompatibilityEvaluator` added | I-90 | **FAILED as required** |

A sixth probe was **discarded as invalid**: it changed only whitespace in the
field declaration, which `\s+` still matched, so its "pass" proved nothing about
the invariant. Recorded because a probe that passes for the wrong reason is
indistinguishable from an invariant that does not work — and R60 shipped one
such probe before the fix.

**I-89 was written whole-identifier from the start**, specifically because R60's
equivalent invariant anchored the suffix at the END of the class name and a
probe called `ExperiencePackageReader2` escaped it. The R61 probe
`ExperienceExecutionContract2` failed on the first run.

---

## 5. Integration report

**R61 modified no existing file in `lib/`.** It added one.

| Subsystem | Change |
|---|---|
| `ExperienceManifest` | none — embedded, not extended |
| `ExperienceEntryPipeline` (R45) | none |
| `WorkspaceSchedulingEngine` (R38) | none |
| `WorkspaceLifecyclePolicyEngine` (R39) | none |
| `WorkspaceRuntimeSupervisor` | none |
| `CapabilityPlatform` (R49/R51) | none |
| `OperatingSystemGovernanceEngine` (R51) | none |
| `ExperienceTrustClassifier` (R52) | none |
| `ExperienceDistributionFramework` (R53) | none |
| `ExperienceInstallationFramework` (R54) | none |
| `ExperienceCommitFramework` (R55) | none |
| `ExperiencePackageWriter`/`Reader` (R60) | none |
| **WebWeaveX** | **unchanged** |
| **Kaalka** | **unchanged** |

Verification that no second owner appeared:

```
grep -rlnE "ExecutionMode|IsolationPolicy|InterruptionPolicy|ExecutionRequirements" lib/
  → lib/app/experience_execution_contract.dart      (only)
```

`RuntimePolicyAction` and `BackgroundExecutionRule` appear in the contract file
**only inside doc comments** that explain who owns them. I-90 scans the
comment-stripped source, so the explanation is possible without the coupling.

Backward compatibility: nothing imports the new file, so no existing caller,
constructor signature or serialised format changed. All 2,085 pre-R61 tests pass
untouched.

---

## 6. Gap movement

**Opened:**

* **G-56 (MED)** — nothing consumes the execution contract. No package carries
  one, no pipeline reads one. Deliberate: every subsystem a consumer would have
  to touch is on R61's forbidden list.
* **G-57 (LOW)** — `headless`, `autonomous`, `IsolationPolicy.strict` and
  `recoverable` are architecture with no implementation. Refused or inert, by
  design.

**Not closed:** G-25 (a user still cannot import an Experience) and G-53 (no
file I/O for packages) remain exactly where R60 left them. R61 was a different
subject and made no attempt on them. **G-40** (test DB lock flakiness under
contention) remains HIGH and reproduced once during this milestone.

---

## 7. Lessons learned

**1. The specification asked for eight things that already had owners. Again.**
This is the sixth consecutive milestone where that was true (R53, R54, R55,
R57, R60, R61). The audit-first phase is not ceremony — without it, R61 would
have shipped a second manifest and a second compatibility evaluator, each
forbidden by an invariant written in an earlier milestone for exactly this
reason.

**2. The one genuinely missing concept was small.** Execution *mode*. Everything
else was framing. A milestone that adds one file and modifies none is the
correct outcome when the audit says so; measuring the milestone by output volume
would have produced parallel architecture.

**3. The R60 regex defect transferred, and the transfer worked.** R60's I-87
anchored a suffix at the end of an identifier and a `…Reader2` probe walked
through it. I-89 was written whole-identifier from the start and its
`…Contract2` probe failed immediately. A defect recorded with its mechanism —
not just its symptom — is a defect that does not recur.

**4. A probe can pass for the wrong reason.** The whitespace probe "passed" I-89
while proving nothing, because `\s+` matched two spaces as happily as one. It is
recorded rather than quietly replaced: the failure mode of mutation testing is a
probe that does not mutate what you think it mutates.

**5. Untrusted input decides the architecture.** The whole declarative-only
design follows from one fact — a contract arrives inside a package, and a
package is untrusted. Once that is stated, every "should the contract decide X"
question answers itself, and I-90 became a list rather than a judgement call.

---

## 8. Recommendation for IS-R62

**Close G-25: wire the package codec to the file system.**

The reasons this is the right next milestone, and R61 was not:

* G-25 ("a user still cannot import an Experience") has been open since **R53**
  and is the only severity-**A** gap in the matrix.
* R60 closed the FORMAT half — container, deterministic writer, reader,
  checksum, `ExperienceDistributionPackage.fromJson`. The FILE half is missing
  and is **small and named**: `RealFileService` (R49) already owns file I/O and
  `file_picker` is already a dependency. No new dependency, no new subsystem.
* It is the shortest remaining path from "architecturally complete" to "a user
  can do the thing".

Second priority, if R62 has room: **G-40**. It is the only HIGH-severity defect
that affects the trustworthiness of every other milestone's evidence, and it has
now been observed in three separate milestones (R56, R59, R61). It should be
diagnosed on its own rather than as a footnote to a feature milestone.

**G-56 (wiring the execution contract) should wait.** Nothing consumes a
contract because nothing yet produces one from a real package, and building the
consumer before the producer would mean designing against a hypothetical input.
Close G-25 first; the contract then has a real path to arrive on.
