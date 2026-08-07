# Experience Installation Usage Matrix — IS-R54

Where installation is **wired**, where it is **mechanism only**, and what a user
can actually do today.

## 1. Paths — honest status

| Path | Owner | Status |
|---|---|---|
| Install (fresh) | `ExperienceInstallationFramework.install()` | **WIRED, tested** |
| Upgrade / downgrade / reinstall | same — kind DERIVED from versions | **WIRED, tested** |
| Repair | `.repair()` | **WIRED, tested** |
| Rollback | `.rollback()` (caller holds the prior package) | **WIRED, tested** |
| Compatibility evaluation | `ExperienceCompatibilityEvaluator` | **WIRED, tested** |
| Dependency planning | `ExperienceDependencyPlanner` | **WIRED, tested** |
| Transaction | `InstallationTransaction` | **WIRED, tested** |
| Protection after commit | requests `ExperienceProtectionService` | **WIRED** (composed with the shared repository) |
| Migration | `MigrationRequirement` records; `MigrationExecutor` executes | **RECORDING ONLY** — nothing runs a migration |
| Install from a FILE | — | **NOT BUILT** — no file format, no file I/O (R53 gap G-25) |
| Install from a UI | — | **NOT BUILT** — no screen calls the installer |
| Dependency fetching | — | **NOT BUILT** — nothing can supply a missing dependency |

**The line that matters: a user still cannot install an Experience from outside
this device.** The pipeline is complete and proven end to end on package
objects; the file layer beneath it does not exist. R53 said the same thing about
import and it is still true.

## 2. The commit paths — what R54 did and did NOT unify

| Site | Commits via | Status |
|---|---|---|
| `experience_distribution.dart` (import) | **the installer** | **rerouted by R54 (Task 8)** |
| `creation_coordinator.dart:442` | `repository.savePackage` directly | unchanged |
| `experience_modification_coordinator.dart:136, 295, 379` | directly | unchanged |
| `evolution_coordinator.dart:79` | directly | unchanged |
| `security/protection_service.dart:289` | directly | unchanged |

R54 established the owner and moved the ONE path Task 8 names. **Four sites
still commit directly** — rerouting them would have redesigned four coordinators
in a milestone forbidden from replacing architecture, and each has genuinely
different pre-conditions. Recorded as gap **G-30** rather than described as
"installation is now unified", which would be false.

## 3. What the installer touches, and what it must not

| Touches | Does NOT touch |
|---|---|
| `SqliteExperienceRepository` (commit) | trust classification (R52) |
| `ExperiencePackageValidator` (delegate) | governance policy (R51) |
| `ExperienceProtectionService` (**request** only) | capability enforcement (R49/R51) |
| `ExperienceProvenance` (store) | distribution / transport (R53) |
| `ExperienceManifest` (read) | activation — pipeline, host screen, Navigator, runtime (R45) |
| | crypto — Kaalka, `ProtectionProvider`, `TimeSeed` |
| | migration execution — `MigrationExecutor`, `ALTER TABLE` |

All exclusions certified (I-62, I-64, I-66, Task 7 boundary).

## 4. Compatibility axes — what is really checked

| Axis | Real? | Notes |
|---|---|---|
| Runtime version | **YES** | first ever consumer of `minimumRuntimeVersion` |
| Manifest completeness | **YES** | id, entryPoint, parseable version |
| Package format | **YES** | against `experiencePackageVersion` |
| Required capabilities | **YES, blocking** | only when the caller supplies the available set |
| Optional capabilities | **YES, warning** | degrades, does not block |
| Platform (network/storage mode) | **NOT CHECKED** | the enum exists; no device policy exists to check it against, so no fabricated check was added |
| Future SDK | **existing axis only** | `supportsPackageFormat()` — no invented second version axis |

## 5. The chain

```
distribution MOVES -> installer COMMITS -> repository STORES
                          |
                          +-> classifier COMPUTES trust   (R52, later)
                          +-> governance DECIDES          (R51, later)
                          +-> platform ENFORCES           (R49, later)
                          +-> entry pipeline ACTIVATES    (R45, user action)
```

Install stops at COMMITS. Everything to the right happens later, on someone
else's call.

## 6. Unchanged

- **Kaalka:** untouched. The installer requests protection; the service
  performs it. Still exactly one crypto importer.
- **WebWeaveX:** untouched. No runtime graph, no workflow runtime, no memory
  graph, no duplicate normalization, no new adapter. Importer count still 4.
- **Distribution (R53):** API, signatures and observable behaviour unchanged —
  only the commit moved out.
- **Retention (R50), governance (R51), identity/trust (R52), lifecycle (R39),
  entry pipeline (R45):** unchanged.
- **`ExperienceManifest`, `ExperiencePackageValidator`, `MigrationExecutor`,
  `SqliteExperienceRepository`:** unchanged. R54 extended or delegated to all
  four without editing any of them.
- **`package_validator.dart`:** one deletion — a duplicate
  `experiencePackageVersion` constant that shadowed the canonical one. No
  consumer imported it from there.
