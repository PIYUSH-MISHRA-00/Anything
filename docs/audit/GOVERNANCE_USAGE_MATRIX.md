# Governance Usage Matrix — Implementation Specification IS-R51

Where governance decisions are **made**, where they are **enforced**, and —
just as importantly — which domains are declared but not yet wired.

## 1. Domain coverage — honest status

| Domain | Rules | Enforced at | Status |
|---|---|---|---|
| `experienceTrust` | `CapabilityTrustFloorRule` | `CapabilityPlatform.invoke()` | **WIRED** |
| `privacy` | `PrivacyModeRule` | `CapabilityPlatform.invoke()` | **WIRED** |
| `offline` | `OfflineRule` | `CapabilityPlatform.invoke()` | **WIRED** |
| `modelAccess` | `ModelAccessRule` | `CapabilityPlatform.invoke()` | **WIRED** |
| `backgroundExecution` | `BackgroundExecutionRule` | decision surface only | DECISION ONLY |
| `recovery` | `RecoveryQuarantineRule` | decision surface only | DECISION ONLY |
| `network` | `NetworkHostAllowlistRule` | `HttpCapability` (own allowlist, unchanged) | POLICY MIRRORED |
| `resourceManagement` | `ResourceCeilingRule` | capability-local ceilings, unchanged | POLICY MIRRORED |
| `workspace` | — | `WorkspaceLifecyclePolicyEngine` (R39) | DELEGATED, unchanged |
| `dataGovernance` | — | `RetentionPolicyEngine` (R50) | DELEGATED, unchanged |
| `security` | — | `ExperienceProtectionService` (Kaalka) | HOOK ONLY |
| `permissions` | — | `CapabilityPlatform` declaration check | EXISTING |
| `backup` | — | — | DECLARED, EMPTY |
| `sync` | — | — | DECLARED, EMPTY |

**Read the right-hand column carefully.** Four domains are genuinely wired
into a live enforcement path. Two produce real decisions nothing consumes yet.
Two mirror a policy whose enforcement stayed where it was. Two delegate
wholly to an existing canonical owner. Two have no rules at all.

Declaring an empty domain is deliberate: `rulesFor(backup)` returns empty and
a test asserts it. A domain with no rules yields **no decision** rather than a
fabricated one, which is why an unregistered concern cannot be accidentally
"governed" by a default nobody chose.

## 2. Capability authorization — the wired path

Every `CapabilityPlatform.invoke()` consults governance before executing:

| Capability | Trust floor | Privacy mode | Offline | Notes |
|---|---|---|---|---|
| `clock` | none | allowed | allowed | reveals and consumes nothing |
| `http` | `local` | **DENIED** | **DENIED** | egress + network |
| `ai` | `local` | **DENIED** | allowed | egress; low trust needs approval |
| `knowledge` | `local` | **DENIED** | **DENIED** | egress + network |
| `files` | `local` | allowed | allowed | local only |
| `notifications` | `local` | allowed | allowed | local only |
| *future* camera / contacts / sensors | add a floor entry | — | — | one map entry, no new framework |

Adding a future capability to governance is one entry in
`canonicalCapabilityTrustFloor` — deliberately, so Task 5's "without
introducing duplicate authorization" survives the next capability rather than
only this one.

## 3. Ownership NOT changed

| Subsystem | Still owns | Governance contributes |
|---|---|---|
| `AnythingKernel` | reasoning, provider selection, prompt routing | *whether* model access is permitted |
| `WorkspaceSchedulingEngine` | scheduling | *eligibility* for background work |
| `WorkspaceLifecyclePolicyEngine` | runtime lifecycle transitions | nothing |
| `RetentionPolicyEngine` | retention bounds | nothing |
| `CapabilityPlatform` | registry, budget, execution | the authorization verdict |
| `HttpCapability` | host enforcement, timeouts | the allowlist policy |
| `ExperienceProtectionService` | Kaalka protect/unprotect | nothing yet (`security` is a hook) |

Governance imports **none** of these (certified, I-49). Composition wires
decision to enforcer.

## 4. Kaalka — hook prepared, architecture untouched

IS-R51 asked for governance hooks only, and no protection redesign. That is
exactly what happened:

- the `security` domain exists and can carry a future protection decision;
- **no rule was written for it**, because writing one would have implied
  governance decides protection, which would contradict
  `ExperienceProtectionService`'s ownership;
- `package:kaalka` still has exactly one importer;
- no second protection path exists.

The honest summary: R51 made a *place* for a protection policy without
creating one.

## 5. WebWeaveX — completely unchanged

No new import, no new adapter, no runtime graph, no memory graph, no workflow
runtime. Importer count still 4. Certified by the pre-existing I-21b/c/d/e,
which remain green.

## 6. What is missing, stated plainly

**Trust is decided but not assigned.** `ExperienceTrustLevel` defaults to
`local` and nothing in production computes a different value: there is no
provenance field on `ExperienceMetadataRecord`, no import path that marks an
Experience `imported`, and no UI to mark one `untrusted`.

So today the trust rules allow exactly what was allowed before R51. The model,
the rules and the enforcement are real, tested and end-to-end — a request from
an `untrusted` Experience genuinely does not execute — but **the classifier
that would produce a non-default level is not built**.

That is the single most important line in this matrix, and the natural first
task for R52: give Experiences a provenance, and the governance framework
starts doing visible work immediately.

**`requireApproval` has no consent UI.** Governance can say consent is
required; nothing collects it, so at the capability boundary it currently
behaves as a refusal (`policyDenied`). The distinction is preserved in the
result status so a future UI can act on it without a governance change.
