# Durable Collection Usage Matrix — IS-R56

## 1. Every durable-collection path — before and after

| Path | Before R56 | After R56 |
|---|---|---|
| `RealNotificationService.schedule` | unserialised read-modify-write | **store**, serialised |
| `RealNotificationService.cancel` | unserialised | **store**, serialised |
| `RealNotificationService.cancelAllForExperience` | unserialised | **store**, serialised |
| `RealNotificationService.deliverDue` | present, THEN persist | **claim inside, present outside** |
| `RealNotificationService.pending` / `dueAt` | direct read | store read (unserialised, deliberately) |
| `ActivityRepository.record` | unserialised | **store**, serialised |
| `ActivityRepository.list` / `clearAll` | direct | store |
| `IntentRepository.save` | unserialised | **store**, serialised |
| `IntentRepository.updateStatus` | unserialised **+ truncated to 50** | **store**, serialised, full list |
| `IntentRepository.delete` | unserialised **+ truncated to 50** | **store**, serialised, full list |
| `IntentRepository.list` / `clearAll` | direct | store |
| `ThemeProvider` | direct scalar write | **still direct** — pinned, G-39 |
| `AnythingPreferences` (dead duplicate of theme persistence) | existed | **DELETED** |

## 2. Measured before/after

| Scenario | Before R56 | After R56 |
|---|---|---|
| 10 concurrent `schedule()` | **1 stored, 9 lost** | 10 stored |
| 2 concurrent `deliverDue()`, 1 due | **presented twice** | presented once |
| 3 concurrent `deliverDue()`, 3 due | (untested) | each once |
| 10 concurrent `record()` | 10 stored (not defective) | 10 stored |
| `updateStatus` with 80 intents | **80 → 50 (30 discarded)** | 80 |

## 3. Ownership

| Verb | Owner | Since |
|---|---|---|
| **READ-MODIFY-WRITE on a durable key, with no yield between** | **`DurableCollectionStore`** | **R56** |
| Notification scheduling / delivery semantics | `RealNotificationService` | R49 |
| Activity history semantics | `ActivityRepository` | canonical |
| Intent history semantics | `IntentRepository` | canonical |
| Retention bounds | `RetentionPolicyEngine` | R50, unchanged |
| Experience state commits | `ExperienceCommitFramework` | R55, unchanged |
| Theme preference | `ThemeProvider` | canonical, pinned |

The store owns the critical section. Each repository keeps its own types, JSON
and semantics — the store knows nothing about what any collection means.

## 4. What is NOT covered

| Not covered | Why |
|---|---|
| Cross-key atomicity | The store makes ONE key's read-modify-write uninterruptible. Two keys cannot be made atomic together. Nothing needs it; inventing it would be speculative. Sibling of G-35. |
| SQLite-backed state | R55's commit framework owns that, with real transactions. |
| Knowledge / world model / engineering memory | Separate repositories, separate backends, out of subject. |
| `ThemeProvider` | One scalar key, no read-modify-write. Pinned, G-39. |
| Delivery retry after a crash | Delivery is at-most-once by design. G-38. |

## 5. Unchanged

- **Retention:** bounds still 200 activity / 100 intents / 200 notifications,
  still owned by R50's engine. Asserted by test — ownership moved, policy did
  not.
- **Kaalka / WebWeaveX:** untouched. Importer counts unchanged.
- **R55 commit framework, R54 installer, R53 distribution, R52 trust, R51
  governance, R45 entry pipeline:** untouched.
- **Public APIs:** every new parameter optional; no signature changed.
