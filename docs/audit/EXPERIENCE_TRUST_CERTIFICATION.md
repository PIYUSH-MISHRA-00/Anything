# Experience Trust Certification — Implementation Specification IS-R52

How the four-verb ownership split is enforced mechanically, on every
`flutter test` run.

## The five invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-52 | Exactly **one** trust classifier and **one** Experience provenance model | STATIC | CERTIFIED |
| I-53 | **Governance never computes trust** — and still imports nothing | STATIC | CERTIFIED |
| I-54 | **The classifier never enforces policy** — its only import is the trust vocabulary | STATIC | CERTIFIED |
| I-55 | `ExperienceRepository` **stores** provenance and never computes trust from it | STATIC | CERTIFIED |
| I-56 | The two "identity" libraries remain distinct subjects, both pinned | STATIC | CERTIFIED |

### I-53 — the load-bearing one

Governance may not reference `ExperienceTrustClassifier`,
`ExperienceProvenance`, `ExperienceOrigin`, `VerificationState` or `classify`.

If it could classify, "governance consumes trust" would collapse into
"governance decides everything" and R51's split would be gone in one commit.

The same test **re-asserts R51's I-49** (governance's import list is empty), so
R52 cannot have quietly given governance a dependency while adding a feature
on top of it. A milestone that extends a subsystem is exactly when its
purity invariant is most likely to erode silently.

### I-54 — the mirror image

The classifier may not reference `CapabilityPlatform`,
`CapabilityInvocationResult`, `GovernanceDecision`, `GovernanceEvaluation`,
`GovernanceRule`, `sqflite`, `Database`, `SharedPreferences`, `dart:io` or
`Timer` — and its import list must be **exactly** `['governance_engine.dart']`.

A classifier that could also enforce would be a second governance engine; a
governance engine that could also classify would make provenance decorative.
Both directions are forbidden, which is why I-53 and I-54 exist as a pair.

### I-55 — storage stays storage

The repository **must** reference `ExperienceProvenance` (it has to store it)
and **must not** reference `ExperienceTrustClassifier`, `ExperienceTrustLevel`
or `classify(`.

Both halves matter, for the same reason as R50's I-47: the tempting fix for a
store that must not decide is to make it blind, and a blind store cannot
persist what governance needs.

### I-52 and I-56 — pinning real near-collisions rather than pretending

Two invariants pin **sets** rather than singletons, because the repository
genuinely contains sibling types that are not duplicates:

**Four `*Provenance*` types**, each recording the origin of a different
subject:

| Type | Records | Feeds |
|---|---|---|
| `ExperienceProvenance` (R52) | where an **Experience** came from | trust classification |
| `PackageProvenance` | how a **package** was generated (engine/spec version) | build metadata |
| `ResourceProvenance` | where a **knowledge resource** was fetched | ranking/citation |
| `SoftwareProvenance` | how a **software analysis** was produced | cognition |

**Six `*Identity*` types**, each identifying a different kind of thing:
`ExperienceIdentity` (an Experience itself), `ScreenIdentity`/`ActionIdentity`
(parts *inside* an Experience — R22, compiler equivalence),
`EntityIdentity`/`RelationshipIdentity` (world-model graph nodes),
`SoftwareIdentity` (analysed software).

Only the first of each set participates in trust. Collapsing them would be
worse than leaving them separate — a package's build metadata and an
Experience's origin are not the same fact.

## A pattern now seen three times

Both of these invariants **failed on first run** against pre-existing types,
and both were fixed the same way: by pinning the real set with the reason
recorded, **not** by narrowing the regex until the failure disappeared.

That is the third occurrence:

| Milestone | Invariant | Pre-existing sibling | Resolution |
|---|---|---|---|
| R47 | canonical type declared once | `AnythingRuntime` v1 contract | pinned, then deleted |
| R51 | one trust model | `TrustLevel` (web source reliability) | pinned with rationale |
| R52 | one provenance / identity model | 3 provenance + 5 identity siblings | pinned with rationale |

Narrowing the pattern is always the faster fix and always the wrong one: it
leaves an invariant that looks green and checks nothing. Worth stating
explicitly, because the pressure to take that shortcut recurs every time.

## Mutation evidence

**Probe A — a duplicate classifier and a parallel provenance engine.** One
file declaring `WorkspaceTrustClassifier` and `ProvenanceEngine`:

```
I-52  Expected: ['lib/app/experience_provenance.dart:ExperienceTrustClassifier']
      Actual:   [..., 'lib/r52_mutation_probe.dart:ProvenanceEngine',
                      'lib/r52_mutation_probe.dart:WorkspaceTrustClassifier']
      a duplicate trust classifier or provenance engine appeared
```

**Probe B — governance computing trust.** A `static classify()` added to
`ExperienceTrustLevel` inside the governance engine:

```
I-53  Expected: false / Actual: <true>
      the governance engine must not compute trust (classify)
      — it consumes ExperienceTrustLevel only
```

Probe B is the important one: it is the exact shortcut a future change is most
likely to take, because putting a two-line helper next to the enum feels
harmless. It is not — it is the moment classification leaves its owner.

Both probes were reverted and the tree confirmed clean.

## What this certification cannot catch

- **Whether a classification is correct for a given Experience.** It proves
  imported ≠ local and that quarantine outranks origin. It cannot tell you
  whether a particular Experience *should* be imported — and today nothing
  produces a non-default origin outside of tests (see limitation 1 in
  `EXPERIENCE_IDENTITY_ARCHITECTURE.md`).
- **Whether the trust ladder is set at the right height.** That `imported`
  sits below the `http` floor is certified; whether that is the right product
  answer is a judgement.
- **API compatibility.** R50 established that static shape checks miss a
  removed named parameter; the analyzer baseline covers that gap.
