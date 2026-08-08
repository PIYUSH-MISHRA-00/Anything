# Experience Orchestration — IS-R62

The ONE place an execution request is decided before it reaches the scheduler.

Source: `lib/app/experience_orchestrator.dart`
Tests: `test/r62_experience_orchestrator_test.dart` (21)
Certified by: **I-91**, **I-92**

---

## 1. Execution Trigger Matrix (Phase 1)

IS-R62 Phase 1 asks for an inventory of every execution trigger. This is what
the repository actually contains — not the specification's list restated.

| Spec category | Real trigger | Where | Path | Reached scheduler |
|---|---|---|---|---|
| user initiated | Recent-list tap | `home_screen.dart:475` | `ExperienceEntryPipeline.activateExperience` | via pipeline |
| user initiated | Experiences-list tap | `experiences_screen.dart:111` | same | via pipeline |
| user initiated | protection resume ×4 | `home_screen.dart:559,603`, `experiences_screen.dart:192,236` | `activateProtectedExperience` | via pipeline |
| user initiated | create new Experience | `home_screen` → `submitIntent` | `IntentExecutionPipeline` (R37) → Kernel | not an execution of an existing Experience |
| user initiated | workspace switch, live runtime | `workspace_switcher.dart:124` | `activateRunningSession` | via pipeline |
| user initiated | **workspace switch, NO live runtime** | `workspace_switcher.dart:105` | **direct `scheduleForeground()`** | **BYPASS** |
| lifecycle initiated | **app lifecycle transition** | `experience_host_screen.dart:399` | **direct `scheduleActiveTransition()`** | **BYPASS** |
| restored | — | — | folded into `activateExperience`, as R45 documents | — |
| scheduled | **none exists** | — | `WorkspaceSchedulingEngine` moves ALREADY-OPEN runtimes between foreground and background; nothing schedules a future execution | — |
| retained | **none exists** | — | `RetentionPolicyEngine` (R50) decides DATA retention, not execution | — |
| autonomous | **none exists** | — | `BackgroundCoordinator` is DORMANT — zero `lib/` importers (IS-R59) | — |
| background | **not a trigger** | — | an OUTCOME of the lifecycle trigger, not a source of one | — |
| startup | **none exists** | — | `main()` → `AnythingApp` → `HomeScreen` executes no Experience | — |

### The finding

`ExperienceEntryPipeline` (R45) was already the ONE canonical ENTRY mechanism,
certified by I-02/I-16/I-17. Every *user-initiated open* already flowed through
it and reached the scheduler via `ExperienceActivationManager.activate()`.

Reachable `lib/` contained exactly **three** calls into
`WorkspaceSchedulingEngine`, and **two of them bypassed the pipeline entirely**.
Between them there was no single point where an execution request could be
represented, refused, or reasoned about — which is also why nothing had ever
consumed the IS-R61 execution contract (gap G-56).

Four of the eight trigger categories the specification names **do not exist in
the repository**. They are absent from `ExecutionTrigger` rather than
fabricated.

---

## 2. Orchestration Architecture (Phase 2)

`ExperienceOrchestrator` accepts an `ExecutionRequest`, validates the execution
contract when one is present, resolves a policy and a priority, and forwards an
admitted request to the scheduler.

```
trigger ──▶ decide() ──▶ OrchestrationDecision ──▶ orchestrate() ──▶ scheduler
                │                                                       │
      contract validated                                     scheduleForeground()
      (delegated to R61)                                 scheduleActiveTransition()
```

`decide()` is separated from `orchestrate()` deliberately: the decision is
testable without a scheduler, and it is *provable* that deciding executes
nothing.

| Type | Purpose |
|---|---|
| `ExecutionRequest` | trigger, `sessionId?`, `experienceId?`, `contract?` |
| `OrchestrationDecision` | `admitted`, `policy`, `priority`, `refusal?`, `findings`, `forwarded` |
| `OrchestrationRefusal` | `reserved`, `invalidContract`, `noSchedulableSession` |

`forwarded` exists so a caller can distinguish *declined* from *admitted, but
there is nothing to schedule yet* — the difference between a refusal and a
`deferred` policy.

### What it never does

It opens no package, constructs no runtime, pushes no route, touches no
`AnythingRuntime`, computes no trust, enforces no capability, and holds no
repository. It reaches exactly one collaborator — the scheduler — through that
scheduler's existing public API. Certified by **I-92**.

---

## 3. Execution Policy Specification (Phase 3)

| Policy | Meaning | Forwards | Status |
|---|---|---|---|
| `userInitiated` | a person is waiting | `scheduleForeground(sessionId)` | implemented |
| `foreground` | should be the active runtime | `scheduleForeground(sessionId)` | implemented |
| `background` | continues, but not active | `scheduleActiveTransition()` | implemented |
| `deferred` | admitted, not scheduled now | nothing | no defer mechanism exists (**G-59**) |
| `scheduled` | asked to run at a time | nothing | no future-execution mechanism exists (**G-59**) |
| `autonomous` | RESERVED | nothing | **refused** |

**No policy executes work.** A policy is a decision *about* execution.

### Trigger + declared mode → policy

| Trigger | Contract mode | Policy |
|---|---|---|
| `userInitiated` | any declarable | `userInitiated` |
| `workspaceSwitch` | any declarable | `userInitiated` |
| `lifecycle` | *(none)* | `background` |
| `lifecycle` | `background` / `persistent` | `background` |
| `lifecycle` | `scheduled` | `scheduled` |
| `lifecycle` | `foreground` / `transient` | `background` |
| `autonomous` | — | `autonomous` → **refused** |

**A contract only ever narrows.** A person waiting always outranks what an
Experience asked for, because the alternative is a package deciding it gets the
foreground — and a package is untrusted input. This direction is asserted over
every `ExecutionMode` value in the R62 suite.

Reserved modes (`headless`, `autonomous`) are refused **twice, independently**:
once by `ExperienceExecutionValidator` (R61) before policy is consulted, and
again by the `autonomous` policy branch.

---

## 4. Priority Model (Phase 4)

| Priority | Assigned to |
|---|---|
| `interactive` | `userInitiated` |
| `normal` | `foreground` |
| `background` | `background` |
| `idle` | `deferred`, `scheduled`, `autonomous` |

**Priority influences orchestration only.** It orders a batch through
`orchestrateAll()` and is reported on every decision. It is deliberately *not*
passed to the scheduler: scheduling remains `WorkspaceSchedulingEngine`'s, and
adding a priority parameter to it would be redesigning the scheduler, which R62
forbids. Certified by a test asserting the forwarded call carries a `sessionId`
and nothing else.

`orchestrateAll()` sorts **stably** — `List.sort` is not stable, so
equal-priority decisions would otherwise reorder arbitrarily and the result
would not be reproducible.

---

## 5. What R62 changed, and what it did not

Three call sites now state an execution request instead of calling the
scheduler directly:

| File | Before | After |
|---|---|---|
| `experience_activation_manager.dart` | `scheduler.scheduleForeground(sessionId)` | `orchestrator.orchestrate(userInitiated, sessionId)` |
| `workspace_switcher.dart` | `scheduler.scheduleForeground(sessionId)` — **bypass** | `orchestrator.orchestrate(workspaceSwitch, sessionId)` |
| `experience_host_screen.dart` | `scheduler.scheduleActiveTransition()` — **bypass** | `orchestrator.orchestrate(lifecycle)` |

Each uses the repository's established `x ?? Default()` injection seam (in use
since R32): the orchestrator parameter is **additive and optional**, and the
default wraps the site's own existing scheduler. No constructor signature
changed, and every pre-R62 test passes untouched.

For the paths these sites take, the resulting behaviour is the identical single
scheduler call as before — which is why the R42/R43/R44/R45 suites are
unmodified and green.

**Unchanged:** `WorkspaceSchedulingEngine`, `WorkspaceRuntimeSupervisor`,
`WorkspaceLifecyclePolicyEngine`, `ExperienceEntryPipeline`, `AnythingRuntime`,
`ExperienceExecutionContract`, `CapabilityPlatform`,
`OperatingSystemGovernanceEngine`, `ExperienceTrustClassifier`, the
installation / packaging / commit / repository layers, **WebWeaveX** and
**Kaalka**.

---

## 6. Known limitations

* **No production call site supplies a contract yet.** All three pass
  `contract: null`, because nothing produces a contract from a real package
  (G-25 → G-58). The contract path is real, tested and reachable; it is not yet
  *exercised in production*. Stated rather than implied.
* **`deferred` and `scheduled` forward nothing** — there is no future-execution
  mechanism in this repository, and faking one with a `Timer` would be
  inventing a scheduler R62 is forbidden from redesigning (G-59).
* **The orchestrator does not consult governance.** `BackgroundExecutionRule`
  (R51) remains the owner of background eligibility; wiring the orchestrator to
  it would move a decision out of governance, which R62 forbids (G-60).
