# Experience Identity, Provenance and Trust — Implementation Specification IS-R52

## REALITY (Task 1 audit)

R51 built a governance framework whose trust model was **dormant**. The audit
found why, precisely:

| Where an Experience is… | Site | Provenance recorded |
|---|---|---|
| created | `creation_coordinator.dart:418` — the ONE production creation site | **none** |
| persisted | `SqliteExperienceRepository.saveMetadata()` | **no column** |
| opened | `ExperienceOpeningCoordinator` | n/a |
| restored | `ExperienceEntryPipeline.activateExperience()` | n/a |
| imported | **no import pipeline exists** | n/a |
| exported | **no export pipeline exists** | n/a |
| duplicated / installed | **do not exist** | n/a |

`ExperienceMetadataRecord` carried id, name, description, category,
timestamps, package version/path and `isProtected` — and **nothing about
origin**. So `ExperienceTrustLevel` defaulted to `local` everywhere, and R51's
trust rules were real, enforced, and never had a reason to fire.

## THE FOUR-VERB OWNERSHIP SPLIT

This is the whole architecture of R52:

```
ExperienceTrustClassifier        COMPUTES trust from provenance
OperatingSystemGovernanceEngine  CONSUMES trust, decides policy
CapabilityPlatform               ENFORCES the decision
SqliteExperienceRepository       STORES provenance
```

Each verb belongs to exactly one owner, and all four boundaries are certified
(I-52…I-55). The one that matters most: **governance must never compute
trust**. If it could, "governance consumes trust" would collapse into
"governance decides everything", and R51's clean split would be gone in a
single commit.

### Dependency direction is one-way, deliberately

`experience_provenance.dart` imports `governance_engine.dart` for the
`ExperienceTrustLevel` vocabulary. Governance imports **nothing** and does not
know the classifier exists.

R51's invariant I-49 (governance's import list must be EMPTY) therefore still
holds unchanged — and R52's certification re-asserts it, so this milestone
cannot have quietly given governance a dependency.

## THE MODEL (Task 3)

```dart
enum ExperienceOrigin     { createdLocally, firstParty, imported,
                            marketplace, unknown }
enum VerificationState    { unverified, verified, revoked, quarantined }

ExperienceFingerprint     { value }          // named wrapper, not a hasher
ExperienceProvenance      { origin, createdAt, importedAt, installationSource,
                            author, signature, verificationState,
                            marketplaceId, cloudId, fingerprint }
ExperienceIdentity        { experienceId, provenance }
ExperienceTrustClassifier { classify(provenance) -> ExperienceTrustLevel }
```

`ExperienceFingerprint` deliberately wraps a **caller-supplied** digest rather
than hashing anything. Hashing already exists
(`ExperiencePackage.computeIntegrityHash`, `KnowledgeResource.computeHash`) and
R52 introduces no second implementation — the type exists to give a digest a
name and a type so it cannot be confused with an id.

`ExperienceOrigin.unknown` is **not** merged with `imported`. "We do not know
where this came from" and "we know it came from elsewhere" are different
facts, and they must classify differently.

## CLASSIFICATION RULES (Tasks 4/6)

| Origin | Verification | Trust |
|---|---|---|
| `firstParty` | any non-quarantined | `trusted` |
| `marketplace` | `verified` | `verified` |
| `marketplace` | unverified | `imported` |
| `createdLocally` | any non-quarantined | `local` |
| `imported` | any non-quarantined | `imported` |
| `unknown` | any non-quarantined | `experimental` |
| *any* | `quarantined` / `revoked` | **`untrusted`** |

Two properties are load-bearing and both are tested:

**Quarantine and revocation outrank origin.** Even a first-party Experience
becomes `untrusted` when quarantined. That is what quarantine means.

**Verification can LOWER trust but never RAISE it.** Marking an imported
Experience `verified` does *not* promote it, because R52 verifies nothing yet:
the `signature` field is a recorded **claim**, and treating an unchecked claim
as proof would be exactly the "assumed rather than computed" failure this
milestone exists to remove.

`unknown` classifies as `experimental`, not `untrusted` — absence of
information is weaker than a decision, and `untrusted` is reserved for an
explicit human or policy act.

## TRANSITIONS (Task 8)

`verified()`, `revoked()`, `quarantined()`, `promoted()`, `demoted()` each
return a **new** provenance. Nothing mutates, so a trust change is always an
explicit, traceable replacement rather than a field write buried in a call
stack.

`promoted()` lifts a quarantine to `unverified`, **not** to `verified` —
promotion restores eligibility; it does not manufacture proof.

## PERSISTENCE (Task 7) — no migration break

Schema version 2 → 3, one statement:

```sql
ALTER TABLE experiences ADD COLUMN provenance TEXT
```

Nullable, no default, no backfill. Every existing row keeps its data and reads
back as **unknown-origin** provenance — which is truthful, because those
Experiences genuinely do predate provenance tracking. No row is rewritten,
nothing is guessed, and an interrupted upgrade cannot corrupt anything.

Provenance is stored as one JSON column carrying the whole value object rather
than ten loose columns, so adding a future field (marketplace id, cloud id,
signature) changes `ExperienceProvenance` and requires no further migration.

A corrupt blob degrades to unknown rather than failing the metadata read: a
record must remain readable even when its provenance is not.

## WHAT IS WIRED, AND WHAT IS NOT

**Wired:**
- the one production creation site now records real `createdLocally`
  provenance with a real fingerprint (reusing the existing integrity hash);
- provenance persists and survives restart;
- `CapabilityPlatform.invoke()` accepts provenance, computes trust through the
  canonical classifier, and enforces the resulting governance verdict;
- provenance **wins over** a caller-asserted `trustLevel`, so a caller cannot
  assert its way past classification.

**Not wired, and honestly so — see KNOWN LIMITATIONS.**

## KNOWN LIMITATIONS — read this section

1. **There is still no import pipeline (Task 6, partial).** The audit found
   Anything has no import, export, install or duplicate path *at all* — so
   there is nowhere to attach "imported Experiences must become IMPORTED".
   What R52 delivers is the complete mechanism: `ExperienceProvenance.imported()`
   exists, classifies to `imported`, persists, survives restart and genuinely
   changes what capabilities run — proven end to end by test. **What does not
   exist is a user-facing way to import an Experience**, because building one
   is a feature milestone, not this one. When an import path is built, it sets
   one field.

   Marketplace (`verified`) and first-party (`trusted`) are the same story:
   modelled, classified, tested — no producer yet, because neither a
   marketplace nor a first-party bundle exists.

2. **Manual quarantine has no UI.** `quarantined()` works and is tested end to
   end; nothing in the interface calls it yet.

3. **Nothing verifies signatures.** The `signature` field is recorded and
   round-trips; no verification is performed, and the classifier deliberately
   refuses to treat it as proof (see above).

4. **Existing Experiences classify as `experimental`, not `local`.** Rows
   written before R52 have unknown origin. This is truthful — the system
   genuinely does not know where they came from — but it is a *behaviour
   change* for pre-existing installs: `experimental` sits below the `local`
   trust floor that guards `http`/`ai`/`knowledge`/`files`/`notifications`.

   **In practice nothing breaks today**, because production call sites do not
   yet pass provenance to `invoke()` and therefore still use the default
   `local` path. But any future work that starts passing stored provenance
   must decide deliberately: either backfill existing rows as
   `createdLocally`, or lower the trust floors. Recorded here so that decision
   is made consciously rather than discovered as a regression.

5. **`ExperienceProtectionService` does not consume provenance yet (Task 10).**
   R52 makes provenance available to it; the protection path is unchanged, has
   no second route, and Kaalka is untouched. Governance would decide,
   protection would enforce — the wiring is future work.

6. **Notification permissions are prepared, not implemented (Task 9).**
   Provenance and trust are available for a future notification-permission
   decision; no OS notification work was done, per instruction.
