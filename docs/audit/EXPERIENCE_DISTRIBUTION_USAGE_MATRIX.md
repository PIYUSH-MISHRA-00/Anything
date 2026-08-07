# Experience Distribution Usage Matrix — IS-R53

Where distribution is **wired**, where it is **mechanism only**, and what a
user can actually do today.

## 1. Paths — honest status

| Path | Owner | Status |
|---|---|---|
| Create | `ExperienceCreationCoordinator` | **WIRED** (pre-R53) |
| Export (object) | `ExperienceDistributionFramework.export()` | **WIRED, tested** |
| Import (object) | `ExperienceDistributionFramework.import()` | **WIRED, tested** |
| Verify | `ExperiencePackageVerifier` | **WIRED, tested** |
| Import/export **files** | — | **NOT BUILT** — no file format, no file I/O |
| Installer | — | import IS installation for the only channel that exists |
| Duplicate | — | not built; would be export→import with a fresh id |
| Marketplace | `MarketplaceMetadata` | **ARCHITECTURE ONLY** (Task 7) |
| Enterprise | `EnterpriseDistributionMetadata` | **ARCHITECTURE ONLY** (Task 8) |
| Cloud sync | `DistributionSource.cloudSync` | channel declared; nothing syncs |

**The line that matters: a user still cannot import an Experience.** The
pipeline is complete and proven end to end on package objects; the file layer
on top of it is not built. `RealFileService` (R49) owns file I/O and
`file_picker` is already a dependency, so that is a small, real follow-on —
deliberately deferred so R53 could establish ownership boundaries first.

## 2. Channel → provenance → trust

| Channel | Origin | Trust (R52) | Verified? |
|---|---|---|---|
| `localFile` | imported | imported | no |
| `sharedTransfer` | imported | imported | no |
| `cloudSync` | imported | imported | no |
| `enterprise` | imported | imported | no |
| `marketplace` | marketplace | **imported** | no |

**Nothing is ever assigned `verified`**, because nothing verifies anything. A
marketplace package carries a publisher signature and no code checks it, so
R52's classifier treats it as merely `imported`. Tested for every channel.

## 3. What distribution touches, and what it must not

| Touches | Does NOT touch |
|---|---|
| `SqliteExperienceRepository` (persist) | trust classification (R52) |
| `ExperiencePackageValidator` (delegate) | governance policy (R51) |
| `ExperienceProvenance` (assign origin) | runtime activation (R45) |
| `ExperiencePackage` (transport) | protection / Kaalka |

All four exclusions are certified (I-58).

## 4. The chain, now doing real work

```
import -> provenance -> classifier -> governance -> capability platform
```

Proven by test: an imported Experience is **refused** a capability that a
locally-created one receives, execution counter at zero. R50–R52 built this
machinery; R53 is the first milestone where a non-creation path drives it.

## 5. Unchanged

- **Kaalka:** untouched. Protection state is transported as metadata and
  deliberately NOT restored on import — an imported Experience is not
  protected until this device protects it. One importer, no second path.
- **WebWeaveX:** untouched. No runtime graph, no workflow runtime, no memory
  graph, no duplicate normalization, no new adapter. Importer count still 4.
- **Retention (R50), governance (R51), identity/provenance/trust (R52),
  lifecycle (R39):** unchanged.
- **`ExperienceManifest` and `ExperiencePackageValidator`:** unchanged. R53
  extended both without editing either file.
