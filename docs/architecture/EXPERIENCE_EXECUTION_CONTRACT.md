# Experience Execution Contract — IS-R61

The canonical declaration of what executing an Experience means.

Source: `lib/app/experience_execution_contract.dart`
Tests: `test/r61_experience_execution_contract_test.dart` (17)
Certified by: **I-89**, **I-90** (`test/r46_architectural_integrity_certification_test.dart`)

---

## 1. What the Phase 1 audit found

IS-R61 Phase 2 listed nine things to "create". Eight of them already existed,
were owned elsewhere, and were already certified. Re-declaring any of them
would have produced exactly the parallel ownership the specification's own
ABSOLUTE RULES forbid.

| Phase 2 asked for | Already owned by | Since | Certified by |
|---|---|---|---|
| required / optional capabilities | `ExperienceManifest` | R53 | I-60 |
| compatibility requirements | `ExperienceCompatibilityEvaluator` | R54 | I-61 |
| suspension / resume / termination | `RuntimePolicyAction` + `WorkspaceLifecyclePolicyEngine` | R39 | — |
| background ELIGIBILITY (the decision) | `BackgroundExecutionRule` (a `GovernanceRule`, trust floor `local`) | R51 | — |
| capability ENFORCEMENT | `CapabilityPlatform` | R49/R51 | I-49 |
| activation | `ExperienceEntryPipeline` | R45 | — |
| scheduling | `WorkspaceSchedulingEngine` | R38 | — |
| identity / provenance | `ExperienceTrustClassifier` | R52 | — |

**Exactly one thing was missing from `lib/` entirely: an execution MODE.**

Verified by `grep -rnE "enum \w*(Mode|ExecutionMode)\b" lib`, which returned
only `ProtectionTimeSeedMode`, `TimeSeedMode`, `NetworkMode` (×2),
`StorageMode`, `AnythingThemeMode`, `FormMode` and `CompilationMode` — none of
which describes execution.

`ExperienceRuntimeType` (`lib/core/contracts/experience.dart`) is *not* an
execution mode: its values are `auil` / `flutter` / `web` / `hybrid`, which
describe RENDERING, and it lives in the unreachable v1 contracts set that
IS-R59 classified EXPERIMENTAL.

So R61 **derives rather than duplicates**.

---

## 2. Execution Contract Specification

`ExperienceExecutionContract` **embeds** the canonical `ExperienceManifest` and
reads identity and capabilities *through* it. It re-declares not one capability
field — the same relationship the R53 distribution envelope has with the
manifest.

| Field | Type | Meaning |
|---|---|---|
| `manifest` | `ExperienceManifest` | The canonical manifest, embedded unchanged |
| `contractVersion` | `int` (current: `1`) | Schema version, so a future field addition is detectable rather than a silent parse difference |
| `mode` | `ExecutionMode` | How the Experience asks to run |
| `requirements` | `ExecutionRequirements` | What it needs before it can run |
| `onInterruption` | `InterruptionPolicy` | What it prefers when interrupted |
| `isolation` | `IsolationPolicy` | How much separation it asks for |
| `recoverable` | `bool` | Whether it asks to be restored after an unclean shutdown |
| `extensions` | `Map<String, dynamic>` | Reserved area, carried verbatim |

Derived, never stored:

```dart
String get experienceId          => manifest.experienceId;
List<String> get requiredCapabilities => manifest.requiredCapabilities;
List<String> get optionalCapabilities => manifest.optionalCapabilities;
```

`ExperienceExecutionContract.defaultFor(manifest)` yields
`foreground` / `standard` / `unspecified` / `recoverable: false` / all
requirements **null**. That default is what makes the contract adoptable
without touching creation: every Experience in this repository today declares
no execution preferences, and each gets a *truthful* contract rather than a
fabricated one. **Undeclared means undeclared, never a fabricated ceiling.**

`fromJson` degrades an unknown `mode`, `onInterruption` or `isolation` to the
implemented default rather than throwing, so a contract written by a future
build is readable by this one.

---

## 3. Execution Mode Specification

```dart
enum ExecutionMode { foreground, background, scheduled, transient, persistent,
                     headless, autonomous }
```

| Mode | Meaning | Status | Who actually decides |
|---|---|---|---|
| `foreground` | Runs while the user is looking at it | **Implemented** — the only mode any Experience uses today | — |
| `background` | Asks to continue while not in the foreground | Declarable | `BackgroundExecutionRule` (R51) requires `local` trust or above |
| `scheduled` | Asks to be run at a time rather than on demand | Declarable | `WorkspaceSchedulingEngine` remains the only scheduler |
| `transient` | Runs once, torn down, keeps nothing across sessions | Declarable | `WorkspaceLifecyclePolicyEngine` (R39) |
| `persistent` | Expects its session to survive being backgrounded | Declarable | `WorkspaceLifecyclePolicyEngine` (R39) |
| `headless` | No UI surface | **RESERVED** — refused by the validator | nothing implements it |
| `autonomous` | Acts without a user present | **RESERVED** — refused by the validator | nothing implements it |

Reserved modes are **refused, not accepted-and-ignored**. Accepting one
silently would promise execution semantics no runtime implements.

### `ExecutionRequirements`

Every field optional, because a manifest that declares nothing is making the
honest statement that it asks for nothing special.

| Field | Note |
|---|---|
| `memoryBytes` | `null` means *not declared*, never *no limit* — different claims |
| `storageBytes` | same |
| `requiredExperiences` | EXECUTION preconditions — distinct from the R53 envelope's `dependencies`, which are a TRANSPORT concern |
| `requiresProtection` | A request. `ExperienceProtectionService` remains the sole owner of protection; nothing here can turn it on |

### `InterruptionPolicy` and `IsolationPolicy`

`InterruptionPolicy { suspend, terminate, unspecified }` deliberately mirrors
the existing `RuntimePolicyAction` vocabulary that
`WorkspaceLifecyclePolicyEngine` has owned since R39 — **without importing it**.
The vocabulary is shared; the authority is not.

`IsolationPolicy { standard, strict }`. `standard` is the only behaviour
implemented: per-Experience data isolation is already real via
`ExperienceDatabase` (one database per Experience) and capability sessions.
`strict` is reserved; declaring it changes nothing today.

---

## 4. Execution Validator Architecture

`ExperienceExecutionValidator` is `const`-constructible with **no dependencies
at all**. It holds no repository, no platform, no scheduler and no runtime, so
it *cannot* execute, schedule or persist even by accident — the type system
enforces "validate only" before certification does.

It checks the contract's **internal consistency and nothing else**:

| Fault | Condition |
|---|---|
| `unsupportedContractVersion` | version `<= 0` or above `currentContractVersion` |
| `manifestIncomplete` | empty `experienceId`, or empty `entryPoint` — there is nothing to execute |
| `contradictoryCapabilities` | a capability declared both required *and* optional |
| `circularRequirement` | `requiredExperiences` names the Experience itself |
| `reservedModeNotImplemented` | `headless` or `autonomous` |
| `invalidRequirement` | a declared `memoryBytes` / `storageBytes` that is not positive |

**It never computes trust and never evaluates build compatibility.**
Compatibility against this build is `ExperienceCompatibilityEvaluator`'s job
(IS-R54), and a second compatibility evaluator is forbidden by R54's own I-61 —
this validator would have been the obvious place to grow one. I-90 certifies it
did not.

---

## 5. Execution Capability Matrix

Who does what, after R61:

| Question | Answered by | Milestone |
|---|---|---|
| what does this Experience ASK FOR | `ExperienceExecutionContract` | **R61** |
| is that request internally coherent | `ExperienceExecutionValidator` | **R61** |
| what capabilities does it need | `ExperienceManifest` | R53 |
| may it use a capability | `CapabilityPlatform.invoke()` | R49/R51 |
| may it run in the background | `BackgroundExecutionRule` → `OperatingSystemGovernanceEngine` | R51 |
| how much is it trusted | `ExperienceTrustClassifier` | R52 |
| does it run on this build | `ExperienceCompatibilityEvaluator` | R54 |
| when does it run | `WorkspaceSchedulingEngine` | R38 |
| pause / resume / terminate / restore | `WorkspaceLifecyclePolicyEngine` | R39 |
| how does it get on screen | `ExperienceEntryPipeline` | R45 |
| how is it stored | `ExperienceCommitFramework` | R55 |
| how does it travel | `ExperiencePackageWriter` / `Reader` | R60 |

**The contract answers only the first two rows.**

---

## 6. Execution Lifecycle Mapping

A contract states a preference at each stage; an existing owner decides.

| Stage | Contract DECLARES | Existing owner DECIDES |
|---|---|---|
| packaged | the whole contract, carried in the package | `ExperiencePackageWriter`/`Reader` (R60) |
| installed | `requirements.requiredExperiences` | `ExperienceDependencyPlanner` (R54) |
| compatible | *(nothing — deliberately)* | `ExperienceCompatibilityEvaluator` (R54) |
| trusted | *(nothing — deliberately)* | `ExperienceTrustClassifier` (R52) |
| eligible | `mode` | `BackgroundExecutionRule` / governance (R51) |
| activated | `isolation` | `ExperienceEntryPipeline` (R45) |
| running | `requirements`, `requiresProtection` | `CapabilityPlatform` (R49/R51), `ExperienceProtectionService` |
| scheduled | `mode: scheduled` | `WorkspaceSchedulingEngine` (R38) |
| interrupted | `onInterruption` | `WorkspaceLifecyclePolicyEngine` (R39) → `RuntimePolicyAction` |
| recovered | `recoverable` | nothing implements recovery today — declarative only |

---

## 7. Why declarative-only is load-bearing

**A contract travels inside a package, and a package is untrusted input.**

If a contract could decide its own eligibility, it would be a governance engine
reachable by anything able to write a manifest — exactly backwards. So:

* Declaring `background` does not grant background. `BackgroundExecutionRule`
  still refuses it below `local` trust.
* Declaring a capability does not grant it. `CapabilityPlatform` still refuses
  an unregistered one.
* Declaring `requiresProtection` does not enable protection.
* Declaring `suspend` does not suspend anything.

This file computes no schedule, starts no runtime, and performs no I/O.
Certified by **I-90**, which fails if the contract source so much as *names*
`OperatingSystemGovernanceEngine`, `GovernanceDecision`,
`ExperienceTrustClassifier`, `CapabilityPlatform`, `WorkspaceSchedulingEngine`,
`WorkspaceLifecyclePolicyEngine`, `RuntimePolicyAction`,
`WorkspaceRuntimeSupervisor`, `AnythingRuntime`, `ExperienceEntryPipeline`,
`SqliteExperienceRepository`, `ExperienceCommitFramework`,
`ExperienceCompatibilityEvaluator`, `dart:io` or `File(`.

---

## 8. What R61 did NOT change

`WorkspaceSchedulingEngine`, `WorkspaceLifecyclePolicyEngine`,
`WorkspaceRuntimeSupervisor`, `ExperienceEntryPipeline`, `CapabilityPlatform`,
`OperatingSystemGovernanceEngine`, `ExperienceTrustClassifier`,
`ExperienceInstallationFramework`, `ExperienceCommitFramework`,
`ExperiencePackageWriter`/`Reader`, `ExperienceManifest`, the repository layer,
**WebWeaveX** and **Kaalka** — all unchanged. R61 added one file to `lib/` and
modified none.
