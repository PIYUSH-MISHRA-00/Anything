# Experience Provenance Usage Matrix — Implementation Specification IS-R52

Where provenance is **produced**, **stored**, **consumed** — and, just as
importantly, where it is not yet produced at all.

## 1. Producers — honest status

| Path | Origin produced | Status |
|---|---|---|
| Creation (`ExperienceCreationCoordinator`) | `createdLocally` + real fingerprint | **WIRED — the one production producer** |
| Import | `imported` | **MECHANISM ONLY — no import pipeline exists** |
| Marketplace | `marketplace` → `verified` | **MECHANISM ONLY — no marketplace exists** |
| First-party bundle | `firstParty` → `trusted` | **MECHANISM ONLY — no bundle exists** |
| Manual quarantine | `quarantined` → `untrusted` | **MECHANISM ONLY — no UI** |
| Rows predating R52 | `unknown` → `experimental` | **REAL — truthful, not fabricated** |

**Read that column carefully.** Exactly one producer is wired: creation. The
Task 1 audit established that Anything has **no import, export, install or
duplicate path at all**, so there was nowhere to attach the other origins.

What R52 delivers for those is the complete mechanism — each origin exists,
classifies correctly, persists, survives restart and genuinely changes which
capabilities run, all proven by test. What does not exist is a user-facing way
to reach them. When an import path is built, it sets one field.

## 2. Storage

| Field | Column | Migration |
|---|---|---|
| whole `ExperienceProvenance` | `experiences.provenance` (TEXT, JSON) | v2 → v3, `ADD COLUMN`, nullable, no backfill |

One JSON column rather than ten loose ones, so future fields (marketplace id,
cloud id, signature) need no further migration. A missing or corrupt blob
reads back as unknown origin without failing the metadata read.

## 3. Consumers

| Consumer | Uses provenance for | Status |
|---|---|---|
| `ExperienceTrustClassifier` | computing `ExperienceTrustLevel` | **WIRED** |
| `CapabilityPlatform.invoke()` | `provenance:` → computed trust → governance verdict → enforcement | **WIRED** |
| `OperatingSystemGovernanceEngine` | consumes the computed level only — **never computes it** | **WIRED** (I-53) |
| `ExperienceProtectionService` | future protection decisions | **PREPARED — Task 10, not wired** |
| Notification permissions | future permission decisions | **PREPARED — Task 9, not implemented** |
| Workspace restoration | trust-aware restore | decision surface exists (R51 `RecoveryQuarantineRule`); not wired |

## 4. The end-to-end path that genuinely works today

```
ExperienceCreationCoordinator
  -> ExperienceProvenance.createdLocally(fingerprint: integrityHash)
  -> SqliteExperienceRepository.saveMetadata()      [persists]
  -> ... restart ...
  -> getMetadata() / listAll()                      [restores]
  -> ExperienceTrustClassifier.classify()           [COMPUTES local]
  -> OperatingSystemGovernanceEngine                [CONSUMES]
  -> CapabilityPlatform.invoke()                    [ENFORCES]
```

And the same path with `imported` provenance ends in `permissionDenied` with
the capability's execution counter at zero — tested directly.

## 5. Provenance WINS over asserted trust

`invoke()` accepts both `trustLevel:` (pre-R52, retained for compatibility)
and `provenance:`. When both are supplied, **provenance wins**.

A test asserts exactly this: a caller claiming `trusted` while handing in
imported provenance is refused. Trust must be *computed*, not claimed — a
caller that could assert its way past classification would make R52
decorative.

## 6. A behaviour change worth flagging

Rows written before R52 have unknown origin and therefore classify as
`experimental`, which sits **below** the `local` trust floor guarding
`http`/`ai`/`knowledge`/`files`/`notifications`.

Nothing breaks today, because production call sites do not yet pass stored
provenance to `invoke()` and still use the default `local` path. But any
future work that starts passing it must decide deliberately:

- backfill pre-R52 rows as `createdLocally` (they almost certainly were), or
- lower the trust floors.

Recorded here so that choice is made consciously rather than discovered as a
regression.

## 7. Unchanged

- **Kaalka:** untouched. One importer. No second protection path. Provenance
  is available to `ExperienceProtectionService`; nothing consumes it yet.
- **WebWeaveX:** untouched. No runtime graph, no memory graph, no workflow
  runtime, no duplicate normalization. Importer count still 4.
- **Retention (R50), runtime lifecycle (R39), governance (R51):** unchanged.
  Governance gained no dependency — re-certified.
- **`CapabilityResultStatus`:** unchanged, 9 values.
