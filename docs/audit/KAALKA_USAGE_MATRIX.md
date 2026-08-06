# Kaalka Usage Matrix — IS-R46

Repository-wide audit of every persistence path: where Kaalka protection is
already used, where it is missing, and where it is intentionally deferred.

**Kaalka was not modified, and no existing architecture was replaced.** This
is an audit, per the specification.

## 1. The single crypto boundary — certified

`package:kaalka` is imported by exactly ONE file in `lib/`
(certified I-21a), and no Kernel or UI file imports it directly (I-21c):

| File | Role |
|---|---|
| `lib/security/kaalka_service.dart` | **sole importer** of `package:kaalka`, `kaalka_protocol`, `kaalka_file` |

## 2. Two consumers of that boundary — a real finding

| # | Path | Consumers | Contract-mediated? |
|---|---|---|---|
| K-A | `ExperienceProtectionService` → `KaalkaProtectionProvider` (`legacy/kaalka_adapter.dart`) → `KaalkaService` | `ExperienceOpeningCoordinator` (unprotect), `ExperienceHostScreen` (protect) | **YES** — via the `ProtectionProvider` contract |
| K-B | `EncryptionManager` (`security/encryption_manager.dart`) → `KaalkaService` **directly** | `MemoryManager` (`memory/memory_manager.dart`), `KaalkaSecurityScreen` (`screens/`) | **NO** — bypasses `ProtectionProvider` |

**K-B is a second, parallel route to the crypto boundary.** It does not
violate I-21a (it still goes through `KaalkaService`, so there is exactly one
importer and exactly one crypto implementation), but it does bypass the
`ProtectionProvider` abstraction that `docs/security/TRUST_BOUNDARIES.md` and
`lib/security/protection_service.dart` both describe as the canonical route.

Mitigating reality, verified: K-B's consumers are Riverpod-based
(`encryptionManagerProvider`, `memory_manager.dart`, `screens/kaalka_security_screen.dart`).
`lib/screens/*` is the dead parallel v1 UI set documented by MIS-1 Part 1 and
is **not** reachable from `AnythingAppShell`, which builds only
`lib/features/*`. So K-B is largely v1-era residue rather than a live second
production protection path — but it is not certified dead, and
`MemoryManager` is not obviously v1-only.

**Not "fixed" in R46**: collapsing K-B into the `ProtectionProvider` contract
is a real architectural change, and R46 is a certification milestone with an
explicit stop condition. Recorded here and in the gap matrix for review.

## 3. Persistence path audit — every write in the repository

`SqliteExperienceRepository` (`lib/storage/sqlite_experience_repository.dart`)
is the canonical persistence owner. Every write method, and its protection
state:

| Method | What it stores | Kaalka-protected? | Assessment |
|---|---|---|---|
| `saveMetadata()` | Experience name, category, timestamps | **NO** | Intentional — metadata must be listable in My Apps/Recent **without** a time seed. Encrypting it would make the library unusable while locked. |
| `savePackage()` | The full `ExperiencePackage` (interface, behaviour, state schema) | **NO by default** | **The real gap.** Package content sits in plaintext SQLite unless the user opts into protection for that Experience. |
| `saveProtectedEnvelope()` | Kaalka ciphertext envelope | **YES** | The canonical protected path (K-A). |
| `getProtectedEnvelope()` | reads ciphertext | **YES** | Unprotect via `ExperienceProtectionService`. |
| `deleteProtectedEnvelope()` | removes ciphertext | n/a | — |
| `updateProtectionState()` | protection flags | **NO** | Metadata about protection, not secret material. |
| `touchLastUsed()` | timestamp | **NO** | Not sensitive. |
| `delete()` / `deletePackage()` | removal | n/a | — |

### Other persistence surfaces

| Surface | Kaalka-protected? | Assessment |
|---|---|---|
| `MemoryManager` (chat/memory rows) | **YES**, via K-B | Encrypts role, content and values through `EncryptionManager` |
| `EngineeringMemoryRepository` | **NO** | Engineering history/evolution records — not currently classified as secret |
| `ActivityRepository` | **NO** | Activity feed entries |
| `IntentRepository` | **NO** | Raw intent expressions — **worth review**: these are user-authored natural language and can be sensitive |
| `CredentialVault` | separate mechanism | Provider API keys; uses secure storage, not Kaalka |

## 4. Where Kaalka is used / missing / deferred — summary

| State | Paths |
|---|---|
| **Already used** | Experience package protection (opt-in, K-A); memory rows (K-B) |
| **Intentionally deferred** | Experience metadata (must stay listable while locked); protection-state flags; activity feed; `touchLastUsed` |
| **Missing / worth review** | Default-plaintext `savePackage()`; `IntentRepository` raw intent text; `EngineeringMemoryRepository` |

## 5. Design intent, confirmed in source (not assumed)

Kaalka protection is **opt-in per Experience** by deliberate design. Confirmed
in three independent places in `lib/`:

- `feature_discovery/feature_priority_analyzer.dart:93` — *"Kaalka protection is available but always opt-in."*
- `feature_discovery/feature_discovery_engine.dart:204` — *"Kaalka-based time-protection is available for any generated Experience, opt-in."*
- `application_engineering/accessibility_performance_security_engineering.dart:161` — *"package:kaalka remains the sole, canonical protection mechanism (via KaalkaProtectionProvider); not duplicated here or anywhere."*

There is also a real, pre-existing regression guard for this in
`design_review/reviewers/security_reviewer.dart:88-102`: if the generated
security decision stops citing `package:kaalka` as canonical, the design
review **fails**. That is a genuine, pre-R46 mechanical enforcement of the
same principle this milestone generalises.

So default-plaintext `savePackage()` is a **known, deliberate product
decision**, not an oversight — but it is worth restating plainly, because
"Kaalka is the canonical protection mechanism" can easily be misread as "all
persisted content is protected". It is not.

## 6. Certified constraints

| Constraint | Enforcement |
|---|---|
| Exactly one `package:kaalka` importer | I-21a — CERTIFIED |
| Kernel / UI never import Kaalka directly | I-21c — CERTIFIED |
| Kaalka is the sole protection mechanism | I-21a + pre-existing `security_reviewer` guard |
| No second protection mechanism introduced | I-21a (a new crypto package import would fail) |

Before R46, the first two were prose. They are now enforced on every run.
