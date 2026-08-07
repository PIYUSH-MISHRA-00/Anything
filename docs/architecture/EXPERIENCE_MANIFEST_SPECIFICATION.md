# Experience Manifest Specification — IS-R53

## THE CANONICAL MANIFEST IS NOT NEW

`ExperienceManifest` (`lib/creation/experience_package.dart:137`) predates R53
and is unchanged by it. R53 added **no** manifest.

| Field | Type | Meaning |
|---|---|---|
| `experienceId` | String | canonical identity |
| `name`, `description`, `category`, `tags` | — | descriptive metadata |
| `version` | String | Experience version |
| `minimumRuntimeVersion` | String? | **compatibility version** |
| `createdAt`, `updatedAt` | DateTime | creation metadata |
| `entryPoint` | String | first screen |
| `requiredCapabilities` | List<String> | **capabilities** |
| `optionalCapabilities` | List<String> | capabilities |
| `networkMode`, `storageMode` | enum | **required permissions**, as access modes |

Task 3 asked for identity, version, compatibility version, creation metadata,
capabilities and required permissions. **All six already existed.**

## THE TRANSPORT ENVELOPE

`ExperienceDistributionManifest` carries the canonical manifest and adds only
what did not exist anywhere:

| Field | Why it is new |
|---|---|
| `manifest` | the canonical `ExperienceManifest`, EMBEDDED not copied |
| `envelopeVersion` | so a future format change is detectable, not a mystery parse failure |
| `provenance` | R52 provenance, transported with the package |
| `fingerprint` | package digest, recomputed and compared on import |
| `wasProtected` | transport-only record of source protection state |
| `marketplace` | Task 7 preparation — listing, publisher, signature placeholder |
| `enterprise` | Task 8 preparation — organisation, deployment, policy id |
| `dependencies` | declared so dependencies need no future version bump |

**Zero canonical fields are re-declared.** Certification enforces this two
ways: exactly one class named `ExperienceManifest` may exist in `lib/`, and
the envelope must hold a field of that exact type.

## SERIALISED FORM

```json
{
  "envelopeVersion": 1,
  "manifest":     { ... canonical ExperienceManifest.toJson() ... },
  "provenance":   { "origin": "...", "importedAt": "...", "fingerprint": "..." },
  "fingerprint":  "<digest>",
  "wasProtected": false,
  "marketplace":  { "listingId": "...", "publisherSignature": "..." } | null,
  "enterprise":   { "organizationId": "...", "policyId": "..." } | null,
  "dependencies": []
}
```

The complete transportable unit is `{ "envelope": ..., "package": ... }`.

## MANIFEST vs METADATA RECORD — NOT DUPLICATES

Task 3 warns: *"Do NOT duplicate ExperienceMetadataRecord."*

| | `ExperienceManifest` | `ExperienceMetadataRecord` |
|---|---|---|
| Lives in | the package | the database |
| Describes | what the Experience IS | what this DEVICE knows about it |
| Travels | yes, with the package | no, per-device |
| Carries | entry point, capabilities, modes | lastUsedAt, isProtected, packagePath, provenance |

They overlap on name/description/category by nature — one is the authored
description, the other the local record — and R53 introduced no new overlap.
Import READS the manifest and WRITES a metadata record; it never
copies one into the other wholesale.

## FINGERPRINT

`ExperienceFingerprint` (R52) wrapping `ExperiencePackage.computeIntegrityHash`
— the existing hash. R53 introduced no second hashing implementation.

Verification rule: an **absent** fingerprint is not a failure (older envelopes
may lack one); a **present and wrong** one is.

## COMPATIBILITY

`envelopeVersion` is checked before anything else. A version above
`currentEnvelopeVersion`, or zero/negative, is rejected as
`unsupportedEnvelopeVersion` rather than parsed hopefully.

`minimumRuntimeVersion` already exists on the canonical manifest and is
carried unchanged; R53 does not evaluate it — that would be a policy decision,
and policy belongs to governance.
