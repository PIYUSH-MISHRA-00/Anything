# Experience Commit Usage Matrix — IS-R55

Who writes Experience state, who used to, and what is still true.

## 1. Every commit path — before and after

| Path | Before R55 | After R55 |
|---|---|---|
| Creation | `savePackage` + `saveMetadata` directly | **commit framework** — and it no longer holds a repository at all |
| Modification (apply) | `savePackage` directly | **commit framework** |
| Modification (evolution plan) | `savePackage` directly | **commit framework** |
| Modification (rollback) | `savePackage` directly | **commit framework `rollback`** |
| Evolution | `savePackage` directly | **commit framework** |
| Protection | envelope + flag + `deletePackage`, 3 sequential writes | **commit framework `commitProtection`, ONE transaction** |
| Unprotection | `savePackage` directly | **commit framework** |
| Installation | `savePackage`/`saveMetadata`/`delete` via a compensating transaction | **commit framework, real transaction** |
| Distribution | (rerouted to the installer in R54) | unchanged — still via installer → commit framework |
| **UI deletion** | **`repository.delete` from a screen** | **commit framework `remove`** |
| `touchLastUsed` | direct | **still direct** — pinned exclusion, G-34 |

## 2. Ownership

| Verb | Owner | Since |
|---|---|---|
| **COMMITS / ROLLS BACK / REPAIRS** | **`ExperienceCommitFramework`** | **R55** |
| RUNS TRANSACTIONS | `RepositoryTransactionCoordinator` | R55 |
| STORES | `SqliteExperienceRepository` | canonical |
| INSTALLS | `ExperienceInstallationFramework` | R54 |
| MOVES | `ExperienceDistributionFramework` | R53 |
| COMPUTES TRUST | `ExperienceTrustClassifier` | R52 |
| DECIDES | `OperatingSystemGovernanceEngine` | R51 |
| RETAINS | `RetentionPolicyEngine` | R50 |
| ENFORCES | `CapabilityPlatform` | R49/R51 |
| ACTIVATES | `ExperienceEntryPipeline` | R45 |
| ENCRYPTS | `ExperienceProtectionService` (Kaalka) | canonical |
| MIGRATES | `MigrationExecutor` | canonical |
| CREATES / MODIFIES / EVOLVES | their coordinators | canonical |

## 3. What the commit framework touches, and what it must not

| Touches | Does NOT touch |
|---|---|
| `SqliteExperienceRepository` (the only writer) | creation, modification, evolution engines |
| `RepositoryTransactionCoordinator` | installation, distribution |
| `ExperiencePackage` / `ExperienceMetadataRecord` (data) | trust, governance, capability enforcement |
| | compatibility evaluation, dependency planning |
| | crypto — Kaalka, `ProtectionProvider`, `encrypt(`/`decrypt(` |
| | migration execution |
| | activation — entry pipeline, host screen, `Navigator`, runtime |

All exclusions certified (I-71).

## 4. Atomicity — honest status

| Scope | Atomic? |
|---|---|
| package + metadata in one commit | **YES** (R55) |
| envelope + protection flag + plaintext removal | **YES** (R55) — the security-relevant one |
| removal across all three tables | **YES** (R55) |
| rollback restore | **YES** (R55) |
| repository write + World Model ingestion | **NO** — separate and best-effort, deliberately, unchanged since before R55 |
| repository write + engineering-memory persistence | **NO** — same, documented in `ENGINEERING_MEMORY.md` |
| repository write + activity record | **NO** — same |

**G-28 is closed for repository commits and only for repository commits.** The
non-atomic pairs above are cross-store and were never in scope; saying "commits
are atomic" without this table would overclaim.

## 5. Scope — what "commit framework" does and does not mean

It owns **Experience state**: the `experiences`, `experience_packages` and
`protected_envelopes` tables.

It does NOT own the other five persistence subjects — `KnowledgeRepository`,
`WorldModelRepository`, `EngineeringMemoryRepository`, `ActivityRepository`,
`CredentialVault`, and the per-Experience `ExperienceDatabase` that holds user
data. Those have their own owners and are untouched. Calling this "the one
persistence layer" would be false.

## 6. Unchanged

- **Kaalka:** untouched. Protection still performs every byte of the crypto; it
  simply no longer writes. Still exactly one crypto importer.
- **WebWeaveX:** untouched. No runtime graph, workflow runtime, memory graph,
  normalization path or serialization duplication. Importer count still 4.
- **Repository:** no schema change, no migration, no new table, no behaviour
  change. Seven write methods gained one optional parameter each; every
  existing caller is unaffected, and a test asserts a bare write still works.
- **R45 entry pipeline, R49 platform, R50 retention, R51 governance, R52 trust,
  R53 distribution, R54 installation:** ownership unchanged. Installation gave
  up persistence, rollback and repair — it kept everything that makes it an
  installer.

## 7. Still not true

- A user **still cannot install or import an Experience** — no file format, no
  file I/O, no UI (R53 G-25). R55 changes who writes, not what a user can do.
- `ExperienceProtectionService` still holds a repository **for reads**.
  Certification forbids it from writing, not from reading.
