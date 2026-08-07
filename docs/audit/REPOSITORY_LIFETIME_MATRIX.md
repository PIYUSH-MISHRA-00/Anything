# Repository Lifetime Matrix — IS-R57

Every repository classified by lifetime and mutability. Evidence-based: each
row was read from the declaration, not inferred.

## 1. Classification

| Repository | Lifetime | Stateful? | `const`? | Disposable | Notes |
|---|---|---|---|---|---|
| `SqliteExperienceRepository` | **singleton** (composition) | **stateful** — caches an open `Database?` | no | **yes** — `close()` | The only repository holding an OS resource |
| `ActivityRepository` | **singleton** (composition, R57) | **stateless** | **yes** | no | Instances interchangeable; R56 proved no data defect from the previous nine |
| `IntentRepository` | **singleton** (composition, R57) | **stateless** | **yes** | no | Same |
| `KnowledgeRepository` | **singleton** (composition) | stateful — open `Database?` | no | yes | |
| `WorldModelRepository` | **singleton** (composition) | stateful | no | yes | Holds a `SqliteExperienceRepository` |
| `EngineeringMemoryRepository` | **singleton** (composition) | stateful | no | yes | Holds a `SqliteExperienceRepository` |
| `ExperienceDatabase` | **per Experience** | stateful — open `Database?` | no | **yes** — `close()` | Created by `DataRuntime` per runtime session |
| `CredentialVault` | **singleton** (composition) | stateless wrapper | no | no | Delegates to `FlutterSecureStorage` |
| `DurableCollectionStore` | **transient / value** | **stateless** | **yes** | no | Deliberately uncomposed (R56) |

## 2. Why the stateless ones can be `const` singletons

`ActivityRepository`, `IntentRepository` and `DurableCollectionStore` hold no
mutable field. Every method resolves `SharedPreferences.getInstance()` — a
process singleton — on each call.

That is why R56 could prove nine `ActivityRepository` instances were harmless,
and why R57's composition change is **ownership canonicalisation, not a bug
fix**. It is also what let R57 keep every existing `const` call site compiling.

## 3. Disposal

| Disposed by | What |
|---|---|
| `AppComposition` consumer (tests: `addTearDown`) | `experienceRepository.close()` |
| `DataRuntime.dispose()` | its per-Experience `ExperienceDatabase` |
| nothing | the stateless repositories — nothing to release |

**No screen disposes a repository it did not create.** Verified repository-wide
before R57 moved `HomeScreen` onto the composition's instance, so sharing it
introduced no double-close hazard.

## 4. Lifetime hazards found by the audit

| Hazard | Status |
|---|---|
| `HomeScreen` built its own `SqliteExperienceRepository` — a second open connection to the same file | **FIXED** (R57): uses the composition's |
| `ExperienceOpeningCoordinator()` default-constructs a repository when built by `HomeScreen` | Seam kept; HomeScreen now passes the shared activity repository. The experience-repository default remains. |
| Parallel test files each open `anything_experiences.db` | **STILL OPEN (G-40)**. R57 tested whether the `HomeScreen` fix helped: measured 3 failures / 11 runs, versus 3/11 before. **No improvement — hypothesis disproved.** |
