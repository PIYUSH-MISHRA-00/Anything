# ADR-R62 — The Orchestrator decides; it is not a second entry pipeline

**Status:** Accepted (IS-R62)
**Supersedes:** nothing
**Related:** ADR-R61, I-02/I-16/I-17 (R45), I-91, I-92

## Context

IS-R62 asked for "ONE canonical Experience Orchestrator" that "decides when,
why, and under what conditions Experiences are executed", with the requirement
that "every execution request flows through it" and "no subsystem may bypass
it" — while forbidding any redesign of the Runtime, Scheduler, Lifecycle,
Execution Contract, Installation, Packaging, Governance, Trust, Commit or
Repository layers.

The Phase 1 audit found that a canonical coordinator **already existed for
entry**: `ExperienceEntryPipeline` (R45) is the ONE entry mechanism, certified
by I-02/I-16/I-17, and every user-initiated open already flows through it and
reaches the scheduler via `ExperienceActivationManager.activate()`.

It also found that reachable `lib/` contained exactly three calls into
`WorkspaceSchedulingEngine`, and that **two of them bypassed that pipeline**:

* `workspace_switcher.dart:105` — the no-live-runtime fallback
* `experience_host_screen.dart:399` — the app-lifecycle notification

And that four of the eight trigger categories the specification names —
scheduled, retained, autonomous, startup — **do not exist in the repository at
all**.

## Decision

**Build the orchestrator as a decision point in front of the scheduler, not as
a second thing that accepts requests and navigates.**

1. `ExperienceOrchestrator` accepts an `ExecutionRequest`, resolves a policy and
   a priority, and forwards an admitted request to the ONE scheduler. It never
   opens a package, constructs a runtime, or pushes a route.

2. `decide()` is separated from `orchestrate()`, so the decision is testable
   without a scheduler and it is provable that deciding executes nothing.

3. All three scheduler call sites route through it, via the repository's
   established `x ?? Default()` seam — additive, optional, no constructor
   signature changed.

4. `ExecutionTrigger` contains only triggers the audit actually found. The four
   non-existent categories are documented as absent rather than declared.

5. The orchestrator **consumes** the IS-R61 execution contract by delegating to
   `ExperienceExecutionValidator`. It declares no validation rule of its own.

6. A contract only ever **narrows**: a `userInitiated` trigger stays
   `userInitiated` regardless of what mode the contract declares.

## Rationale

**A coordinator that can also execute stops being a coordinator.**

R45's I-02/I-16/I-17 exist because four `HomeScreen` call sites once each opened
Experiences their own way, every one bypassing workspace registration and
scheduler participation. Building an orchestrator that accepted requests *and*
navigated would recreate exactly that: a second entry pipeline, reachable in
parallel with the certified one. So the orchestrator sits in front of the
scheduler, where there was genuinely nothing, rather than in front of entry,
where R45 already stands.

**A contract must never widen a decision**, for the reason ADR-R61 records: a
contract travels inside a package, and a package is untrusted input. If
declaring `ExecutionMode.foreground` could take the foreground from a person
who just tapped something, the untrusted artefact would be setting policy. The
narrowing direction is asserted across every `ExecutionMode` value.

**Priority stops at the orchestrator boundary.** Phase 4 says priorities
"influence orchestration only" and "Scheduler retains ownership of scheduling".
Passing a priority into `WorkspaceSchedulingEngine` would mean changing its
API — a redesign R62 forbids. So priority orders batches here and the forwarded
call carries a `sessionId` and nothing else.

## Consequences

**Positive**

* Both pre-R62 bypasses are closed. I-91 fails the moment a fourth direct
  scheduler call appears anywhere in `lib/`.
* **G-56 is closed**: the orchestrator is the first consumer of the R61
  execution contract anywhere in the repository.
* Behaviour is unchanged on every existing path — the R42/R43/R44/R45 suites are
  untouched and green.
* Refusal is now expressible. Before R62 there was no way for anything to
  decline an execution request, because there was no request.

**Negative / accepted**

* **No production call site supplies a contract yet** — all three pass
  `contract: null`, because nothing produces a contract from a real package
  (G-58). The path is real and tested; it is not yet exercised in production.
* `deferred` and `scheduled` forward nothing. No future-execution mechanism
  exists, and faking one with a `Timer` would be inventing a scheduler (G-59).
* The orchestrator does not consult governance; `BackgroundExecutionRule` (R51)
  remains the owner of background eligibility (G-60).

## Alternatives rejected

**Make the orchestrator the new entry point, with the entry pipeline calling
it.** Rejected: it inverts a layering R45 established deliberately and would
put navigation behind a decision object. The pipeline calls the activation
manager, which calls the orchestrator — decisions flow *down*, not up.

**Have the orchestrator own the scheduler's job.** Rejected outright by R62's
own ABSOLUTE RULES, and it would delete a certified owner (R42) to solve a
problem that was about *reaching* the scheduler, not about scheduling.

**Declare the missing trigger categories anyway (scheduled, retained,
autonomous, startup) for completeness.** Rejected for `scheduled`, `retained`
and `startup`: nothing produces them, and an enum value no code path can create
is not architecture, it is a claim. `autonomous` is the one exception —
declared and *refused*, following R61's precedent for reserved modes, because
the specification explicitly names it reserved.
