# Experience Distribution Architecture — Implementation Specification IS-R53

## THE DECISION THAT SHAPED THIS MILESTONE

IS-R53 Task 3 says *"Introduce ExperienceManifest"* and Task 6 says
*"Introduce ExperiencePackageVerifier"*.

**Both already exist and are canonical.**

| Type | Location | Already carries |
|---|---|---|
| `ExperienceManifest` | `lib/creation/experience_package.dart:137` | identity, version, `minimumRuntimeVersion`, created/updated, `entryPoint`, required + optional capabilities, network/storage mode, category, tags |
| `ExperiencePackageValidator` | `lib/creation/package_validator.dart:31` | size, version, manifest fields, structure, references, limits, integrity |

Introducing either under those names would have produced a **second manifest**
and a **second verifier** — which the same specification forbids three times
over:

- ABSOLUTE RULES: *"DO NOT create … Second verifier … Second package manager"*
- SUCCESS CRITERIA: *"Exactly one Experience Manifest"*
- CONTEXT: *"Treat every implementation already present as canonical. Do NOT
  replace architecture."*

**The rules win.** R53 extends both rather than duplicating either, and
certifies the result so neither can silently become a duplicate later.

### How each was extended

**`ExperienceDistributionManifest`** *embeds* the canonical
`ExperienceManifest` as a field and adds **only** what exists nowhere else:
provenance (R52), package fingerprint, protection state, and
marketplace/enterprise/dependency metadata. It re-declares not one canonical
field. It is a **transport envelope**, exactly as Task 3 itself specifies
("Manifest is transport metadata") — never a second identity record.

Certification proves both halves: exactly one class named `ExperienceManifest`
exists in `lib/`, and the envelope holds a field *of that type*.

**`ExperiencePackageVerifier`** *delegates* every structural and integrity
check to `ExperiencePackageValidator.validate()` and adds only what genuinely
did not exist:

- envelope version support,
- envelope ↔ package identity agreement,
- **fingerprint agreement** — the one real new check.

Certification requires the literal delegation call to be present, so
"no second verifier" is enforced rather than intended.

## OWNERSHIP

```
ExperienceDistributionFramework  MOVES experiences (import/export/package)
ExperiencePackageVerifier        VERIFIES packages
ExperienceTrustClassifier        COMPUTES trust        (R52)
OperatingSystemGovernanceEngine  CONSUMES trust        (R51)
CapabilityPlatform               ENFORCES              (R49/R51)
SqliteExperienceRepository       STORES                (canonical)
ExperienceEntryPipeline          ACTIVATES             (R45)
ExperienceProtectionService      PROTECTS              (Kaalka)
```

Distribution **never** classifies trust, **never** enforces policy, **never**
activates a runtime and **never** protects anything. Certified: the file may
not reference `ExperienceTrustClassifier`, `ExperienceTrustLevel`, `classify(`,
the governance engine, `ExperienceEntryPipeline`, `ExperienceHostScreen`,
`Navigator`, `ExperienceProtectionService` or `KaalkaService`.

That list is long on purpose. A distribution layer is the most tempting place
in the system to "just also" do the next step, because it already holds the
package.

## THE CHAIN R53 COMPLETES

```
import
  -> verify              (delegating to the canonical validator)
  -> assign PROVENANCE   (channel -> origin, one mapping, one place)
  -> persist             (repository)
  -> [later] classify    (R52 classifier)
  -> [later] decide      (R51 governance)
  -> [later] enforce     (R49 capability platform)
```

Tested end to end: an **imported** Experience is refused a capability that a
**locally-created** one receives, with the capability's execution counter at
zero. Three milestones of trust machinery now do visible work.

## IMPORT NEVER ACTIVATES

`import()` returns a persisted, provenance-bearing Experience and **stops**.
Activation remains with `ExperienceEntryPipeline` (R45) and requires a
deliberate user action.

This is a safety property, not an oversight: **importing something must not
run it.** A distribution framework that activated on import would turn "open
this file" into "execute this file", which is the single worst thing a
distribution layer can do.

## PROVENANCE ASSIGNMENT — ONE MAPPING, ONE PLACE

`DistributionSource` (the transport **channel**) is mapped to
`ExperienceOrigin` (the provenance **fact**) in exactly one function,
`provenanceFor()`, so the mapping is reviewable rather than scattered across
import call sites.

| Channel | Origin | Resulting trust (R52 classifier) |
|---|---|---|
| `localFile` | `imported` | `imported` |
| `sharedTransfer` | `imported` | `imported` |
| `cloudSync` | `imported` | `imported` |
| `enterprise` | `imported` | `imported` |
| `marketplace` | `marketplace` (unverified) | `imported` |

**Nothing is ever assigned `verified`.** A marketplace package carries a
publisher signature, and nothing checks it — so R52's classifier treats an
unverified marketplace origin as merely `imported`. Assigning `verified`
because a field was present would be exactly the "assumed rather than
computed" failure R52 removed. A test asserts every channel produces
`VerificationState.unverified`.

## EXPORT

Reads current metadata, provenance, and a **live** fingerprint recomputed from
the package at export time. Changes no persistence, mutates nothing.

An export→import round-trip is tested: an Experience created locally on the
source device arrives as **`imported`** on the target, which is exactly right
— it did not originate there.

## PROTECTION STATE IS NOT CARRIED ACROSS

The envelope records whether the source was protected (transport metadata),
but an imported Experience is persisted with `isProtected: false`.

Distribution must not fabricate a protected state it cannot honour — the
ciphertext envelope is not transported, and `ExperienceProtectionService`
remains the sole owner of protection. Tested directly.

## FUTURE PREPARATION (Tasks 7 and 8) — architecture only

`MarketplaceMetadata` (listing, publisher, signature placeholder) and
`EnterpriseDistributionMetadata` (organisation, deployment, policy id) exist,
round-trip through JSON, and are transported.

**Nothing consumes them.** No marketplace, no UI, no networking, no cloud, no
policy evaluation — `policyId` is recorded as a *name*, and governance (R51)
remains the sole owner of policy decisions. Exactly as instructed:
architecture only.

## KNOWN LIMITATIONS — read this section

1. **There is no file format and no file I/O.** Distribution moves
   `ExperienceDistributionPackage` objects and serialises them to JSON. It
   does not read or write `.anything` files, does not zip anything, and has no
   share-sheet integration. `RealFileService` (R49) owns file I/O and
   `file_picker` is already a dependency — wiring them is a small, real
   follow-on, deliberately not done here so that this milestone's ownership
   boundaries could be established first.

   **Consequence, stated plainly: a user still cannot import an Experience.**
   The pipeline is complete and tested end to end; the file layer on top of it
   is not built.

2. **Nothing verifies publisher signatures.** The field is transported and the
   classifier refuses to treat it as proof. A real verifier is future work.

3. **No installer, no duplicate path.** Task 1 listed both. Import *is* the
   installation path for the only distribution channel that exists (a package
   object), and "duplicate" would be import of an export with a fresh id —
   both are one small function away once (1) exists, and neither was
   fabricated.

4. **Protection state is transported but never restored.** See above. An
   imported Experience must be re-protected on the receiving device.

5. **`dependencies` is declared and transported but never resolved.** Declared
   so the envelope format needs no version bump when dependencies arrive.
