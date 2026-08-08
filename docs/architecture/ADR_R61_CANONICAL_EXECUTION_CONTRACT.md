# ADR-R61 — The execution contract DECLARES; existing owners DECIDE

**Status:** Accepted (IS-R61)
**Supersedes:** nothing
**Related:** ADR-R60, I-89, I-90

## Context

IS-R61 asked for "EXACTLY ONE execution contract" and stated that "no subsystem
may define its own execution semantics".

The Phase 1 audit found that eight of the nine things Phase 2 listed already
existed and were owned: capabilities by `ExperienceManifest` (R53, certified
exactly-one by I-60), compatibility by `ExperienceCompatibilityEvaluator`
(R54, certified by I-61), suspend/resume/terminate by `RuntimePolicyAction` and
`WorkspaceLifecyclePolicyEngine` (R39), background *eligibility* by
`BackgroundExecutionRule` (R51 governance, trust floor `local`), enforcement by
`CapabilityPlatform` (R49/R51), activation by `ExperienceEntryPipeline` (R45),
and scheduling by `WorkspaceSchedulingEngine` (R38).

Only one concept was absent from `lib/` entirely: an execution **mode**.

Creating a contract that re-declared the other eight would have produced a
second manifest, a second compatibility evaluator and a second governance
surface — which the same specification forbids in its ABSOLUTE RULES and
contradicts in its own success criteria.

## Decision

**Build the contract as a derivation, not a duplication, and make it
declarative-only.**

1. `ExperienceExecutionContract` **embeds** the canonical `ExperienceManifest`
   and exposes `experienceId`, `requiredCapabilities` and
   `optionalCapabilities` as getters that read *through* it. No capability field
   is re-declared. There is still exactly one manifest.

2. It adds only what was genuinely missing: `ExecutionMode`,
   `ExecutionRequirements`, `InterruptionPolicy`, `IsolationPolicy`,
   `recoverable`.

3. `InterruptionPolicy` mirrors the existing `RuntimePolicyAction` vocabulary
   *without importing it*. The vocabulary is shared; the authority is not.

4. `headless` and `autonomous` are declared but **refused** by the validator.
   Declaring the vocabulary now means no widening later; accepting them would
   promise execution semantics no runtime implements.

5. `ExperienceExecutionValidator` is `const` with **no dependencies at all**, so
   it cannot schedule, execute or persist even by accident, and it checks
   internal consistency only — it never computes trust and never evaluates
   build compatibility.

## Rationale

**A contract travels inside a package, and a package is untrusted input.**

That single fact settles the design. If a contract could decide its own
eligibility, then anyone able to write a manifest could reach a governance
decision — the authority would flow from the untrusted artefact instead of from
the platform. So a contract states what an Experience *asks for*, and every
existing owner keeps its decision:

* declaring `background` does not grant background — `BackgroundExecutionRule`
  still refuses it below `local` trust;
* declaring a capability does not grant it — `CapabilityPlatform` still refuses
  an unregistered one;
* declaring `requiresProtection` does not enable protection;
* declaring `suspend` does not suspend anything.

The truthful default matters for the same reason: `defaultFor()` leaves every
requirement `null`, because *undeclared* and *unlimited* are different claims
and only one of them is true.

## Consequences

**Positive**

* One execution contract and one validator, certified by I-89.
* No second manifest, no second compatibility evaluator, no second governance
  surface — certified by I-90, which fails if the contract source so much as
  *names* any of fourteen decision-owning symbols.
* Adoptable without touching creation: every Experience today declares nothing
  and gets a truthful `foreground` contract.
* Forward-readable: unknown modes degrade to `foreground`, and `contractVersion`
  makes a future schema change detectable rather than a silent parse difference.

**Negative / accepted**

* Nothing consumes the contract yet. R61 was explicitly forbidden from
  redesigning the runtime, scheduler, lifecycle, installation, packaging,
  governance, trust, commit or repository layers, so wiring it into the entry
  pipeline is left to a later milestone (see **G-56**).
* `headless`, `autonomous` and `IsolationPolicy.strict` are architecture with
  no implementation. They are refused or inert, and labelled RESERVED in source.
* `recoverable` is declarative; nothing implements recovery today.

## Alternatives rejected

**Extend `ExperienceManifest` with the execution fields.** Rejected: the
manifest is the *creation-time* description of an Experience and is already
carried by the R53 envelope and the R60 container. Adding runtime policy to it
would couple every packaging and validation path to execution semantics, and
would mean a manifest change for every future execution field.

**Reuse `ExperienceRuntimeType`.** Rejected: its values (`auil` / `flutter` /
`web` / `hybrid`) describe *rendering*, not execution, and it lives in the
unreachable v1 contracts set IS-R59 classified EXPERIMENTAL.

**Let the contract evaluate its own eligibility.** Rejected for the reason
above; this is the decision the ADR exists to record.
