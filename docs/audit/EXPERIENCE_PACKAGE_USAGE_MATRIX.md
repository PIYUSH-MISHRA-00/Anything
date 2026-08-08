# Experience Package Usage Matrix — IS-R60

## 1. Ownership

| Verb | Owner | Since |
|---|---|---|
| **MODEL → BYTES** | **`ExperiencePackageWriter`** | **R60** |
| **BYTES → MODEL** | **`ExperiencePackageReader`** | **R60** |
| Defines the container | `ExperiencePackageFormat` | R60 |
| VALIDATES structure | `ExperiencePackageValidator` | canonical — delegated to, not duplicated |
| Describes the Experience | `ExperienceManifest` | canonical — embedded, not duplicated |
| Transports | `ExperienceDistributionManifest` / `…Package` | R53 |
| MOVES | `ExperienceDistributionFramework` | R53 |
| INSTALLS | `ExperienceInstallationFramework` | R54 |
| COMMITS | `ExperienceCommitFramework` | R55 |
| COMPUTES TRUST | `ExperienceTrustClassifier` | R52 |
| FILE I/O | `RealFileService` | R49 — **not wired to the codec** |

## 2. Status by capability

| Capability | Status |
|---|---|
| Write a package to bytes | **WIRED, tested, deterministic** |
| Read a package from bytes | **WIRED, tested** |
| Checksum verification | **WIRED** — against the rebuilt package |
| Structural validation | **WIRED** — delegated to the canonical validator |
| Container version refusal | **WIRED** |
| Distribution envelope round-trip | **WIRED** (`fromJson` added) |
| Signature block | **RESERVED** — carried, never verified |
| Extension area | **RESERVED** — carried verbatim |
| Write bytes to a `.anything` file | **NOT BUILT** — G-25 |
| Read a package a user picked | **NOT BUILT** — no UI |
| Compression | **NOT BUILT** — no dependency |
| Marketplace / cloud / accounts | **NOT BUILT** — explicitly forbidden |

## 3. What R60 did NOT create

`ExperienceManifest`, `ExperiencePackageValidator`,
`ExperienceDistributionManifest`, `PackageIntegrity`, `ExperienceProvenance`.
All pre-existing, all certified, all reused.

**Certified by I-87**, which asserts exactly one manifest and exactly one
validator still declare, from the codec's angle.

## 4. Unchanged

Trust (R52), governance (R51), distribution (R53), installation (R54), commit
(R55), repository composition (R57), runtime reachability (R59), Kaalka and
WebWeaveX. No ownership moved. 2,068 pre-existing tests pass unchanged.

## 5. The honest headline

**A user still cannot import an Experience.** The codec closes the *format*
half of G-25; the *file* half — writing bytes to disk and letting a user pick
one — is not built. The remaining work is small and named: `RealFileService`
owns file I/O and `file_picker` is already a dependency.
