# Repository Ownership Matrix — IS-R57

The canonical record of every repository in `lib/`. Produced from a
repository-wide scan, not from documentation.

## 1. Every repository

| Repository | Declared in | Backend | Composition owner | Construction sites (non-seam) |
|---|---|---|---|---|
| `SqliteExperienceRepository` | `storage/sqlite_experience_repository.dart:128` | SQLite | **`AppComposition:238`** | 0 |
| `ActivityRepository` | `storage/activity_repository.dart:64` | SharedPreferences | **`AppComposition` (R57)** | 0 *(was 9)* |
| `IntentRepository` | `storage/intent_repository.dart:124` | SharedPreferences | **`AppComposition` (R57)** | 0 *(was 1)* |
| `KnowledgeRepository` | `storage/knowledge_repository.dart:84` | SQLite | **`AppComposition:256`** | 0 |
| `WorldModelRepository` | `storage/world_model_repository.dart:94` | SQLite | **`AppComposition:242`** | 0 |
| `EngineeringMemoryRepository` | `storage/engineering_memory_repository.dart:71` | SQLite | **`AppComposition:371`** | 0 |
| `ExperienceDatabase` | `storage/experience_database.dart:13` | SQLite (per Experience) | **none — by design** | 1 (`data_runtime.dart:25`) |
| `CredentialVault` | `security/credential_vault.dart:22` | FlutterSecureStorage | **`AppComposition:239`** | 0 |
| `DurableCollectionStore` | `storage/durable_collection_store.dart:70` | SharedPreferences | **none — stateless `const`** | n/a |

**`ExperienceDatabase` is deliberately not composed.** It is *per Experience*,
created on demand by `DataRuntime` with the Experience's own id, and its
lifetime is the runtime session's. Composing it would require a factory keyed
by id — an abstraction with one implementation, which this milestone forbids.

**`DurableCollectionStore` is deliberately not composed.** It is stateless and
`const`-constructible (IS-R56), so instances are interchangeable; composing a
value object would be ceremony. Certified by R56's I-75 that only one exists.

## 2. Per-verb ownership

| Repository | Read | Write | Commit | Rollback | Retention | Transactions | Protection |
|---|---|---|---|---|---|---|---|
| `SqliteExperienceRepository` | itself | **`ExperienceCommitFramework` only** (R55, I-69) | R55 | R55 | R50 | `RepositoryTransactionCoordinator` (R55) | `ExperienceProtectionService` |
| `ActivityRepository` | itself | itself, via `DurableCollectionStore` (R56) | n/a | n/a | **R50 engine** | none | none |
| `IntentRepository` | itself | itself, via `DurableCollectionStore` (R56) | n/a | n/a | **R50 engine** | none | none |
| `KnowledgeRepository` | itself | `KnowledgeCache` | n/a | n/a | **R50 engine** (R48/R50) | none | none |
| `WorldModelRepository` | itself | `WorldModelCoordinator` | n/a | n/a | none | none | none |
| `EngineeringMemoryRepository` | itself | coordinators, best-effort | n/a | n/a | none | none | none |
| `ExperienceDatabase` | `DataRuntime` | `DataRuntime` | n/a | n/a | none | own | none |
| `CredentialVault` | itself | itself | n/a | n/a | none | none | OS keystore |

## 3. Injection and certification

| Repository | Injectable | Seam | Certified by |
|---|---|---|---|
| `SqliteExperienceRepository` | yes | constructor `?? default` + widget params | I-69 (write ownership), I-78 |
| `ActivityRepository` | **yes (R57)** | constructor `?? default`; widget params on host/activity screens | **I-78, I-79** |
| `IntentRepository` | **yes (R57)** | composition field | **I-78** |
| `KnowledgeRepository` | yes | constructor param | I-47 |
| `WorldModelRepository` | yes | constructor param | — |
| `EngineeringMemoryRepository` | yes | constructor param | — |
| `ExperienceDatabase` | via `DataRuntime` | `customPath` | — |
| `CredentialVault` | yes | constructor `?? default` | I-21a (crypto boundary) |
| `DurableCollectionStore` | yes | constructor `const` default | I-75, I-76 |

## 4. What R57 changed

**Ownership only. No behaviour, no API break, no persistence change.**

| Site | Before | After |
|---|---|---|
| `creation_coordinator:147` | `activity ?? ActivityRepository()` | seam kept; **composition now passes its instance** |
| `experience_modification_coordinator:84` | same | same |
| `experience_opening_coordinator:76` | same | same; composition + HomeScreen pass it |
| `experience_workspace_manager:55` | same | same; composition passes it |
| `intent_session_manager:128` | same | same; composition passes it |
| `evolution_coordinator:44` | same | seam kept (not composed — see §5) |
| `activity_screen:19` | **bare construction, no seam** | optional widget param, defaulted |
| `experiences_screen:81` | **bare construction** | `_composition.activityRepository` |
| `experience_host_screen:240` | **bare construction, no seam** | optional widget param, defaulted |
| `home_screen:321` | **own `SqliteExperienceRepository()`** | `_composition.experienceRepository` |
| `home_screen:322` | **own `IntentRepository()`** | `_composition.intentRepository` |

## 5. Honest remainder

**`EvolutionCoordinator` is not built by the composition at all** — nothing
constructs it in `lib/` outside its own file. Its `?? ActivityRepository()`
default therefore never fires in production. Left alone: composing a
coordinator nothing constructs would be speculative.

**The `x ?? Repository()` default is retained everywhere it existed.** It is
the optional-injection seam this codebase has used since R32; removing it would
be an API change this milestone forbids, and would break every test that relies
on defaults. Certification distinguishes a *defaulted seam* (allowed) from a
*bare construction* (forbidden) — the latter is what nine ActivityRepository
sites had.

**Multiple `SqliteExperienceRepository` instances can still exist** through
those defaults when a caller injects nothing. All point at the same database
file. R57 removed the two rogue UI constructions; the constructor defaults
remain by design.
