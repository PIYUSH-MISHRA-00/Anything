# Governance Architecture — Implementation Specification IS-R51

## REALITY (Task 1 audit)

Governance decisions were real but scattered across whichever file happened to
need them — and the most important one did not exist at all.

| Decision | Owner before R51 | Kind |
|---|---|---|
| HTTP allowed hosts | `AppComposition._defaultHttpAllowedHosts` → `HttpCapability` | network |
| Invocation budget | `CapabilityPlatform._maxInvocationsPerCapability` | resource |
| File size ceiling | `FileCapability._maxFileSize` | resource |
| Knowledge size ceiling | `RuntimeSecurityLimits.maxKnowledgeBytes` | resource |
| Capability declaration check | `CapabilityPlatform.invoke()` | permissions |
| Protection (Kaalka) | `ExperienceProtectionService`, opt-in per Experience | security |
| Retention | `RetentionPolicyEngine` (R50) — already canonical | data |
| Runtime lifecycle | `WorkspaceLifecyclePolicyEngine` (R39) — already canonical | workspace |
| **Experience trust** | **nothing — did not exist** | trust |

That last row is the finding that mattered. **Every Experience — however it
arrived — was treated identically by the capability platform**, because there
was no notion of trust to treat it by. A locally-authored Experience and one
imported from elsewhere had exactly the same authority.

## WHAT GOVERNANCE IS

Governance owns **decisions**. It owns no implementation, no storage, no
registry, no scheduler, no execution path. It answers *"is this allowed, and
why"* and nothing else.

```
GOVERNANCE DECIDES            EXISTING OWNERS ENFORCE
OperatingSystemGovernanceEngine
                              CapabilityPlatform        capability access + registry
                              RetentionPolicyEngine     data retention        (R50)
                              WorkspaceLifecyclePolicyEngine  runtime lifecycle (R39)
                              AnythingKernel            reasoning
                              ExperienceProtectionService  protection (Kaalka)
                              HttpCapability            host allowlist
```

The engine **imports nothing**. Not the retention engine, not the scheduler,
not the Kernel, not the capability platform. A governance engine that reached
into any of them would be exactly the parallel ownership IS-R51 forbids.
Composition wires the decision to the enforcer; governance never reaches
across. Certified (I-49): its import list must be **empty**.

### Why purity is the whole design

R50's retention engine could be trusted with every retention decision in the
application precisely because it *cannot delete, cannot reach storage, cannot
schedule itself*. R51 extends the same bargain: governance is trusted with
every policy decision because it cannot enforce anything.

That is not a stylistic preference. If governance could execute a capability,
it would become a second capability platform. If it could reach a provider, it
would become a second AI boundary. Every "cannot" is certified.

### Why a third engine is not a third owner

R50 established two policy engines with disjoint domains. R51 adds a third
whose domain is disjoint from both:

| Engine | Domain | Vocabulary |
|---|---|---|
| `WorkspaceLifecyclePolicyEngine` (R39) | runtime lifecycle | pause/resume/terminate/restore |
| `RetentionPolicyEngine` (R50) | data retention | retain/evict/expire |
| `OperatingSystemGovernanceEngine` (R51) | system governance | allow/deny/requireApproval |

None of those vocabularies overlaps. A **fourth** engine, or any of the three
reaching into another's vocabulary, fails certification (I-48).

## THE MODEL (Task 3)

```dart
enum GovernanceDomain   { security, privacy, permissions, resourceManagement,
                          backgroundExecution, network, offline, modelAccess,
                          workspace, experienceTrust, dataGovernance,
                          recovery, backup, sync }          // 14 domains
enum ExperienceTrustLevel { untrusted, experimental, imported,
                            local, verified, trusted }      // ordered
enum GovernanceOutcome  { allow, deny, requireApproval }

GovernanceContext    { trustLevel, experienceId, sessionId, capabilityId,
                       operation, isOffline, privacyMode, host, requestedBytes }
GovernanceRule       { domain, id, description, evaluate(context) -> decision? }
GovernancePolicy     { domain, rules }
GovernanceDecision   { domain, outcome, reason, ruleId }
GovernanceEvaluation { context, decisions, outcome, decisive, reason }
```

`GovernanceContext` is a plain value object with no behaviour and no reference
to a live subsystem — a rule that could reach a repository would no longer be
a policy.

### Two semantics that carry the safety

**A silent rule is not an approving rule.** `evaluate()` returns `null` when a
rule has no opinion. A rule that returned `allow` when it simply did not apply
would mask a later denial.

**Deny wins.** `GovernanceEvaluation.outcome` is deny → requireApproval →
allow. If *any* rule refuses, the request is refused, regardless of how many
others permitted it. Fail-closed on conflict is the only safe precedence, and
it is tested directly: a request that one rule explicitly allowed and another
denied comes back denied.

## THE TRUST MODEL (Task 6)

Ordered least-to-most privileged, so `atLeast()` comparisons are meaningful:

```
untrusted < experimental < imported < local < verified < trusted
```

| Level | Meaning |
|---|---|
| `untrusted` | explicitly distrusted; quarantined |
| `experimental` | under development or evaluation; may misbehave |
| `imported` | arrived from outside this device, unverified |
| `local` | created locally by this user — **the default** |
| `verified` | verified provenance (future marketplace) |
| `trusted` | first-party, shipped with Anything |

Governance decides using it; **`CapabilityPlatform` enforces**. There is
exactly one trust model for Experiences (I-50).

> **Not a duplicate:** `lib/knowledge/knowledge_resource.dart` also declares a
> `TrustLevel`, grading how reliable a *retrieved web source* is
> (official/community/unknown…). That feeds ranking, never authority.
> Collapsing the two would be worse than leaving them separate — an
> Experience's privileges and a web page's credibility are not the same scale,
> and one enum serving both would inevitably be misapplied. Both are pinned in
> certification so the distinction is visible rather than rediscovered.

## CAPABILITY AUTHORIZATION (Task 5)

`CapabilityPlatform.invoke()` now asks governance and obeys the answer:

```
invoke()
  1. declared-capability check      (pre-existing, unchanged)
  2. registration check             (pre-existing, unchanged)
  3. session budget check           (pre-existing, unchanged)
  4. supported-operation check      (pre-existing, unchanged)
  5. GOVERNANCE  <- new
  6. execute
```

Governance is asked **last**, after the cheap structural checks, so a
governance denial is never reported for a request that was malformed anyway —
the caller gets the most specific reason available. Tested directly: an
unsupported operation from an untrusted Experience reports `unsupported`, not
a trust failure.

**No new result status was added.** A denial maps to the existing
`permissionDenied`, an approval requirement to the existing `policyDenied`, so
no caller's `switch` became incomplete. The platform gained **no** permission
manager, **no** second registry and **no** second authorization path — it
receives a verdict and enforces it.

With no engine supplied — the default — behaviour is byte-identical to
pre-R51.

## CANONICAL RULES

| Rule | Domain | Decision |
|---|---|---|
| `CapabilityTrustFloorRule` | experienceTrust | deny capabilities above an Experience's trust level |
| `PrivacyModeRule` | privacy | deny `http`/`ai`/`knowledge` in privacy mode |
| `OfflineRule` | offline | deny `http`/`knowledge` while offline |
| `NetworkHostAllowlistRule` | network | deny non-allowlisted hosts |
| `ModelAccessRule` | modelAccess | low-trust cloud model access requires approval |
| `ResourceCeilingRule` | resourceManagement | deny oversized requests |
| `BackgroundExecutionRule` | backgroundExecution | background work needs local trust |
| `RecoveryQuarantineRule` | recovery | untrusted Experiences are not auto-restored |

## OWNERSHIP LEFT UNCHANGED

- **Kernel (Task 8):** governance decides whether model access is *permitted*;
  `AnythingKernel` still owns reasoning entirely. Governance does not select
  providers, route prompts or touch `ModelProvider`.
- **Scheduler (Task 7):** governance decides *eligibility* for background
  work; `WorkspaceSchedulingEngine` still owns scheduling.
- **HTTP (Task 9):** governance owns the allowlist *policy*; `HttpCapability`
  still enforces it, unchanged.
- **Retention (R50) and runtime lifecycle (R39):** untouched.
- **WebWeaveX:** unchanged — no new import, no new adapter.
- **Kaalka:** unchanged — no second protection path. Governance now has a
  `security` domain where a future protection *decision* can live, but the
  protection architecture itself was not redesigned, as instructed.

## KNOWN LIMITATIONS — read this section

1. **Trust is decided but not yet *assigned*.** `ExperienceTrustLevel`
   defaults to `local` and nothing in production yet computes a different
   value per Experience: there is no provenance field on `ExperienceMetadataRecord`,
   no import path that marks an Experience `imported`, and no UI to mark one
   `untrusted`. The model, the rules and the enforcement are real and tested
   end-to-end; **the classifier that would assign a non-default level is not
   built**. Until it is, every Experience is `local` and the trust rules
   allow what they allowed before. This is the honest state, not a
   half-claimed feature.

2. **Four domains have no rules yet** — `security`, `permissions`,
   `dataGovernance`, `backup`, `sync`. They are declared because IS-R51 names
   them and because a domain with no rules returns *no decision* rather than a
   fabricated one. `rulesFor(backup)` returns empty, and a test asserts that.
   Declaring an empty domain is honest; inventing rules for it would not be.

3. **Governance is consulted at the capability boundary only.** Retention,
   scheduling and reasoning do not yet call it — they keep their own R39/R50
   ownership, exactly as Task 2 requires ("coordinates them", not replaces).
   The decision surface exists for those subsystems to adopt; the adoption is
   future work and is deliberately not claimed here.

4. **`requireApproval` has no consent UI.** Governance can say consent is
   required; nothing yet collects it, so in practice an approval requirement
   behaves as a refusal at the capability boundary (`policyDenied`). The
   distinction is preserved in the result status so a future UI can act on it.
