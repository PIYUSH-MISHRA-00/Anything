# IS-R62 — Canonical Experience Orchestration Framework

**Milestone report.** Branch `v2.0.0`.

---

## 1. Executive summary

IS-R62 asked for ONE Experience Orchestrator that every execution request flows
through, with no subsystem permitted to bypass it — while forbidding any
redesign of the Runtime, Scheduler, Lifecycle, Execution Contract, Installation,
Packaging, Governance, Trust, Commit or Repository layers.

**The Phase 1 audit found that a canonical coordinator already existed for
entry.** `ExperienceEntryPipeline` (R45) is the ONE entry mechanism, certified
by I-02/I-16/I-17, and every user-initiated open already flowed through it.
Building a second thing that accepts requests *and* navigates would have
recreated exactly the defect those invariants exist to prevent.

What did **not** exist was any point where an execution *request* could be
represented, refused, or reasoned about. Reachable `lib/` contained exactly
three calls into `WorkspaceSchedulingEngine`, and **two of them bypassed the
entry pipeline entirely**:

```
experience_activation_manager.dart:105   scheduleForeground()      via pipeline
workspace_switcher.dart:105              scheduleForeground()      BYPASS
experience_host_screen.dart:399          scheduleActiveTransition()  BYPASS
```

So R62 placed the orchestrator **in front of the scheduler, not in front of
entry** — where there was genuinely nothing. All three call sites now state an
execution request; I-91 fails the moment a fourth direct scheduler call appears.

It also made the orchestrator the **first consumer of the IS-R61 execution
contract anywhere in the repository**, closing G-56 one milestone after it
opened.

| | |
|---|---|
| Files added to `lib/` | **1** (`app/experience_orchestrator.dart`) |
| Files modified in `lib/` | **3** (all additive, optional seams) |
| New tests | 21 (R62 suite) + 2 certification invariants |
| Certification suite | 99 → **101** |
| Full suite | 2,104 → **2,127**, all green |
| Analyzer | 0 errors / 27 warnings / 43 infos — **unchanged, at baseline** |
| Mutation probes | 5 written, 5 failed as required — **3 rewritten after failing for the wrong reason** |
| WebWeaveX / Kaalka | **untouched** |

---

## 2. Phase 1 — the execution trigger inventory

Full matrix in `docs/architecture/EXPERIENCE_ORCHESTRATION.md` §1. The headline:

**Four of the eight trigger categories IS-R62 Phase 1 names do not exist in
this repository.**

| Category | Reality |
|---|---|
| scheduled | No future-execution mechanism exists. `WorkspaceSchedulingEngine` moves ALREADY-OPEN runtimes between foreground and background — it does not schedule a future execution. |
| retained | `RetentionPolicyEngine` (R50) decides DATA retention, not execution. |
| autonomous | `BackgroundCoordinator` is **DORMANT** — zero `lib/` importers, per IS-R59's reachability report. |
| startup | `main()` → `AnythingApp` → `HomeScreen` executes no Experience. |

They are absent from `ExecutionTrigger` rather than fabricated. `autonomous` is
the single exception: declared and **refused**, following R61's precedent for
reserved modes, because the specification explicitly names it reserved.

The categories that *do* exist — user initiated (7 call sites), workspace switch
(2 paths), lifecycle (1) — are enumerated with file and line in the architecture
document.

---

## 3. What was built

`ExperienceOrchestrator` accepts an `ExecutionRequest`, validates the contract
when one is present, resolves a policy and a priority, and forwards an admitted
request to the scheduler.

`decide()` is separated from `orchestrate()` so the decision is testable without
a scheduler and it is *provable* that deciding executes nothing — asserted
directly, by running `decide()` across every trigger against a recording
scheduler and requiring zero calls.

Six policies (Phase 3), four priorities (Phase 4). Priority orders a batch
through `orchestrateAll()` and is **never passed to the scheduler** — adding a
priority parameter to `WorkspaceSchedulingEngine` would be redesigning it.
`orchestrateAll()` sorts stably, because `List.sort` is not and equal-priority
decisions would otherwise reorder arbitrarily.

**A contract only ever narrows.** A `userInitiated` trigger stays
`userInitiated` regardless of what `ExecutionMode` a contract declares —
asserted across every enum value. A package is untrusted input; a contract that
could claim the foreground from a waiting person would be the artefact setting
policy.

Full specification: `docs/architecture/EXPERIENCE_ORCHESTRATION.md`.
Decision record: `docs/architecture/ADR_R62_CANONICAL_EXPERIENCE_ORCHESTRATION.md`.

---

## 4. Validation report

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | 657 files, **0 changed** |
| `tool/analyze_gate.sh` | `0 error(s), 27 warning(s), 43 info(s)` — **at baseline, PASS** |
| `flutter test test/r62_experience_orchestrator_test.dart` | **21/21** |
| `flutter test test/r46_..._certification_test.dart` | **101/101** |
| R42 / R43 / R44 / R45 suites (the rewired paths) | **all pass, unmodified** |
| `flutter test` (full) | **2,127 / 2,127** |

### The one failure, and what it was

The first full run reported `+2126 -1`: an R43 test
(*HomeScreen forwards its resolved scheduler into ExperienceHostScreen*).

* the same file in isolation: **14/14 pass**
* a clean full re-run: **2,127/2,127 pass**

Non-deterministic under contention, absent on re-run — the **G-40** family.
Reported rather than omitted, because a full run that failed once is not a full
run that passed.

**G-40 has now surfaced in four milestones (R56, R59, R61, R62), naming a
different test each time.** See §8.

### Mutation certification

| Probe | Invariant | Result |
|---|---|---|
| a second class `ExperienceOrchestrator2` | I-91 | **FAILED as required** |
| the host screen restored to calling `scheduleActiveTransition()` directly | I-91 | **FAILED as required, naming the file** |
| the orchestrator given an `AnythingRuntime?` field | I-92 | **FAILED as required** |
| the orchestrator given a `NavigatorState?` field | I-92 | **FAILED as required** |
| a second `ExperienceExecutionValidator` elsewhere in `lib/` | I-92 | **FAILED as required** |

**THREE OF THESE FAILED FOR THE WRONG REASON ON THE FIRST ATTEMPT.** The initial
versions of the last three used undeclared types, so `flutter test` failed at
**compilation** before the certification suite ever ran — printing "Some tests
failed" while proving nothing about I-92. Caught by inspecting the full output
instead of the exit status, then rewritten with real imports and real field
types, after which each failed on the invariant itself with the correct reason
text.

This is the second consecutive milestone where a mutation probe was worthless on
first write (R61: a whitespace change that `\s+` still matched). The check that
caught both is the same: **verify why a probe failed, not merely that it did.**

---

## 5. Integration report

| File | Change |
|---|---|
| `lib/app/experience_orchestrator.dart` | **new** |
| `lib/app/experience_activation_manager.dart` | additive optional `orchestrator` seam; the one `scheduleForeground()` call becomes an orchestrated request |
| `lib/features/workspace/workspace_switcher.dart` | same, for the no-live-runtime **bypass** |
| `lib/runtime/experience_host_screen.dart` | same, for the app-lifecycle **bypass** |

All three use the repository's established `x ?? Default()` seam (in use since
R32). **No constructor signature changed**; the default wraps each site's own
existing scheduler, so behaviour on every existing path is the identical single
scheduler call as before. That is why the R42/R43/R44/R45 suites are unmodified
and green.

**Unchanged:** `WorkspaceSchedulingEngine` (R42), `WorkspaceRuntimeSupervisor`
(R40/R41), `WorkspaceLifecyclePolicyEngine` (R39), `ExperienceEntryPipeline`
(R45), `AnythingRuntime`, `ExperienceExecutionContract` (R61),
`CapabilityPlatform` (R49/R51), `OperatingSystemGovernanceEngine` (R51),
`ExperienceTrustClassifier` (R52), and the installation / packaging / commit /
repository layers. **WebWeaveX** and **Kaalka** untouched.

---

## 6. Gap movement

**Closed:** **G-56** — the execution contract now has a consumer. Closed
*honestly, not completely*: the path is real, tested and reachable, but no
production call site supplies a contract yet. That residue is recorded as G-58
rather than folded into a claim of full closure.

**Opened:**

* **G-58 (MED)** — all three call sites pass `contract: null`. Downstream of
  G-25: nothing produces a contract because nothing reads a package from a file.
* **G-59 (LOW)** — `deferred` and `scheduled` forward nothing; no
  future-execution mechanism exists, and faking one with a `Timer` would be
  inventing a scheduler.
* **G-60 (LOW)** — the orchestrator does not consult governance;
  `BackgroundExecutionRule` (R51) remains the owner of background eligibility.

**Unchanged:** **G-25** (a user still cannot import an Experience) and **G-53**
(no file I/O for packages) remain exactly where R60 left them.

**Traceability:** I-84 refused the first version of R62's certification because
its comments cite I-02/I-16/I-17, which were among the 68 unregistered pre-R58
IDs. Those three are now registered — not as a retro-tagging effort, but because
the milestone actually touched them. The unregistered count drops 68 → 65.

---

## 7. Lessons learned

**1. The right answer was to build somewhere the specification did not point.**
IS-R62 said "every execution request flows through the Orchestrator", which
reads as *put it in front of entry*. Entry already had a certified owner. The
real gap was one layer down — between a request and the scheduler — and it was
invisible until the audit counted scheduler call sites rather than reading the
specification's framing. Two bypasses had been live since R42/R43.

**2. Four of eight named trigger categories did not exist.** Declaring them
would have produced an enum whose values no code path can construct. An enum
value nothing can create is not architecture; it is a claim. Only `autonomous`
was declared, and only because refusing it is itself a behaviour.

**3. A mutation probe failed for the wrong reason — again.** Three of five
probes initially failed at compilation rather than on the invariant. R61 caught
the same class of error and its report said to check *why* a probe failed. That
instruction is now load-bearing, and it has paid twice.

**4. Closing a gap half-way is worth recording as half.** G-56 has a real
consumer and no real producer. Writing it as "closed" would have been defensible
and wrong; the residue is G-58, and it points at G-25 as the actual blocker.

**5. The additive-seam idiom keeps paying.** Three call sites were rewired with
zero constructor changes and zero test changes, because R32's `x ?? Default()`
pattern was already the house style. The alternative — making `orchestrator`
required — would have touched six construction sites and four test files to
achieve the same runtime behaviour.

---

## 8. Recommendation for IS-R63

**Close G-25 — a user still cannot import an Experience.**

This was R61's recommendation too, and R62 strengthened rather than weakened
the case:

* G-25 is the **only severity-A gap** in the matrix and has been open since
  **R53**, now five milestones.
* R60 closed the FORMAT half (container, deterministic writer, reader,
  checksum). The FILE half is **small and named**: `RealFileService` (R49)
  already owns file I/O and `file_picker` is already a dependency. No new
  dependency, no new subsystem.
* It is now the **direct blocker on two further gaps**. G-58 (no call site
  supplies a contract) and, behind it, the whole R61/R62 contract path exist
  because nothing produces a package from bytes a user chose. Closing G-25
  turns G-58 from a design question into a wiring step.

Every milestone since R53 has added architecture above a pipeline whose first
step is missing. R63 should build that step.

**Second priority: G-40.** It has now been observed in four milestones and
named a different test each time. It is the only HIGH-severity defect that
undermines the evidence *every other milestone* relies on — a full run that
fails once and passes on re-run weakens every "all tests pass" claim in this
repository. It deserves a milestone of its own rather than another footnote.
