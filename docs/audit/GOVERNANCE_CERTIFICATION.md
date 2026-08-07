# Governance Certification — Implementation Specification IS-R51

How canonical governance ownership is enforced mechanically, on every
`flutter test` run, by
`test/r46_architectural_integrity_certification_test.dart`.

## The four governance invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-48 | Exactly **three** policy engines — runtime lifecycle, retention, governance — mutually **disjoint** | STATIC | CERTIFIED |
| I-49 | The governance engine **decides but never enforces** — no I/O, no storage, no `Timer`, no provider, **and an empty import list** | STATIC | CERTIFIED |
| I-50 | Exactly **one** Experience trust model; **no** duplicate permission/authorization framework | STATIC | CERTIFIED |
| I-51 | The **Kernel** and the **repositories** never own or evaluate governance | STATIC | CERTIFIED |

### I-48 — three engines, three disjoint vocabularies

Scans every `class *Retention*Engine` / `*Lifecycle*Engine` /
`*Governance*Engine` in `lib/` and pins the result to exactly three. A
**fourth** is a parallel policy manager and fails outright.

Disjointness is checked in every direction. Governance may not reference
`RetentionClass`, `LifecycleCandidate`, `RetentionPolicyEngine`,
`RuntimePolicyAction`, `ExperienceRuntimeController`, `AppLifecycleState`,
`AnythingKernel` or `CapabilityPlatform`; the retention and lifecycle engines
may not reference `GovernanceDomain`, `GovernanceDecision` or
`ExperienceTrustLevel`.

That governance may not name `CapabilityPlatform` is deliberate and load-
bearing: the platform asks governance, never the reverse. A dependency in the
other direction would make governance a second capability platform.

### I-49 — the empty import list

The strongest clause in this file: `lib/app/governance_engine.dart` must
import **nothing at all**.

```dart
final imports = RegExp(r'''^import\s+['"]([^'"]+)''', multiLine: true)
    .allMatches(governance.raw).map((m) => m.group(1)!).toList();
expect(imports, isEmpty);
```

A policy that depends on a subsystem is not a policy — it is that subsystem's
extension. Forbidding every import is a cheap, absolute way to keep governance
a pure decision layer, and it makes the "governance owns policy only" claim
structural rather than aspirational.

Also forbidden by name: `sqflite`, `Database`, `SharedPreferences`,
`dart:io`, `File(`, `Directory(`, `Timer`, `http.`, `ModelProvider`.

### I-50 — one trust model, no shadow permission framework

Two enums in `lib/` carry "Trust" in their name and are **pinned together**,
because they are not duplicates:

| Enum | Grades | Feeds |
|---|---|---|
| `ExperienceTrustLevel` (R51) | how much authority an **Experience** has | capability access |
| `TrustLevel` (`knowledge_resource.dart`) | how reliable a **retrieved web source** is | ranking |

Collapsing them would be worse than leaving them separate: an Experience's
privileges and a web page's credibility are not the same scale, and one enum
serving both would inevitably be misapplied. Pinning both makes the
distinction visible in CI while still failing on a genuine duplicate
Experience-trust model.

The same test separately forbids any `class *Permission*(Manager|Engine|Service)`
or `*Authorization*` — the shadow permission framework that a governance
milestone is most likely to grow by accident.

### I-51 — governance stays out of reasoning and storage

`anything_kernel.dart` and the four repositories may not reference
`OperatingSystemGovernanceEngine`, `GovernanceDecision`, `GovernanceDomain` or
`ExperienceTrustLevel`.

Governance is policy; the Kernel is reasoning; repositories are storage. The
tempting shortcut in a governance milestone is to let the Kernel "just check"
a policy inline, which is how the single reasoning boundary would quietly
acquire a second job.

## Mutation evidence

**Probe A — a parallel governance engine, a duplicate permission manager and a
duplicate trust model, all at once.** Two invariants fired:

```
I-48  A parallel governance/policy engine appeared:
      [... , lib/r51_mutation_probe.dart:ParallelGovernanceEngine]

I-50  a second trust model appeared:
      [... , lib/r51_mutation_probe.dart:WorkspaceTrustLevel]
```

**Probe B — a duplicate permission manager ALONE**, so the permission clause is
proven to bite independently rather than being masked by the trust assertion
that precedes it in the same test:

```
I-50  Expected: empty
      Actual:   ['lib/r51_mutation_probe.dart:PermissionManager']
      a duplicate permission/authorization framework appeared
```

Both probes were removed and the tree confirmed clean.

## A certification that had to be corrected on first run

I-50's first draft asserted exactly **one** `*Trust*` enum. It failed
immediately against `knowledge_resource.dart`'s pre-existing `TrustLevel`.

The fix was **not** to narrow the regex until the failure disappeared — that
would have removed the invariant's ability to catch a genuine duplicate. Both
enums are pinned explicitly, with the reason recorded, exactly as R47 handled
the `AnythingRuntime` name collision: make the exception visible rather than
pretend it is not there.

## What governance certification cannot catch

Stated plainly, because the boundary matters:

- **It cannot verify a trust level is correct.** Certification proves there is
  one trust model and that low trust denies capabilities. It cannot tell you
  whether a particular Experience *should* be `imported` rather than `local` —
  and today nothing assigns anything but the default (see limitation 1 in
  `GOVERNANCE_ARCHITECTURE.md`).
- **It cannot verify a policy is wise.** That `PrivacyModeRule` denies `http`
  is certified; that denying `http` is the right privacy answer is a product
  judgement.
- **It cannot catch API breaks.** R50 proved this: static shape checks miss a
  removed named parameter. The analyzer baseline covers that gap.

The certification layer is one mechanical check among several. Across
R46–R51 the analyzer baseline, the full suite and mutation probes have each
independently caught a defect this layer could not.
