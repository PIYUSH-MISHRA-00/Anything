# Kaalka Integration Guide

[`package:kaalka`](https://pub.dev/packages/kaalka) provides Anything's
protection: time-keyed encryption for Experiences, entirely local.

Runnable: [`examples/kaalka_protection`](../examples/kaalka_protection).

---

## The boundary

```
UI  →  ExperienceProtectionService  →  ProtectionProvider  (contract)
                                              │
                                    KaalkaProtectionProvider
                                    KaalkaService
                                              │
                                       package:kaalka
```

**Only `lib/security/kaalka_service.dart` and `lib/legacy/kaalka_adapter.dart`
import `package:kaalka`.** This is certified, not conventional:

| Invariant | Enforces |
|---|---|
| **I-21a** | Exactly one crypto importer in `lib/` |
| **I-21c** | The Kernel and UI never import it directly |
| **I-21e** | Kaalka is never routed *through* WebWeaveX — that would create a second protection path |

If you add an import, a test fails and names your file. **Go through
`ExperienceProtectionService`.**

## Protection

```dart
final result = await protectionService.protect(package);

switch (result) {
  case ProtectionSucceeded(:final envelope):
    // ProtectedEnvelope { payload, seed: TimeSeed, protectedAt }
    store(envelope.serialize());
  case ProtectionFailed(:final message):
    report(message);
}
```

Protection is **deterministic against a supplied seed** — `TimeSeedMode.custom`
with an explicit `customTimeSeed`, rather than reading the wall clock. That is
what makes recovery reproducible and testing possible.

## Recovery

```dart
final result = await entryPipeline.activateProtectedExperience(
  navigator,
  experienceId: id,
  timeSeed: seed,
);
```

Recovery is **transactional**: the recovered package is persisted through
`ExperienceCommitFramework`, so a failure mid-recovery does not leave a
half-written Experience.

Four real production call sites reach this — two in `home_screen.dart`, two in
`experiences_screen.dart`. **Protection is the most completely wired subsystem
built after R45**: unlike packaging and installation, a user can actually reach
it.

## Trust is NOT Kaalka's job

A common misreading. Kaalka protects payloads. It decides nothing about trust.

| Question | Owner |
|---|---|
| Is this payload protected? | `ExperienceProtectionService` → Kaalka |
| How much is this Experience trusted? | `ExperienceTrustClassifier` (I-50) |
| May it use this capability? | `CapabilityPlatform` |
| May it run in the background? | `OperatingSystemGovernanceEngine` |

The classifier deliberately **refuses to treat the presence of a signature as
proof**. Protection and trust are separate, and conflating them would let an
attacker earn authority merely by encrypting something.

## What is NOT protected

Honest limits — see [SECURITY.md](../SECURITY.md):

| Gap | Status |
|---|---|
| Package signatures are not verified | The container reserves a `signature` block and verifies nothing. Needs a key-distribution decision. |
| Exported `.anything` files are unencrypted | Canonical JSON with a checksum. Not yet exploitable (export is unreachable), but a real open decision the moment it ships. |
| No key rotation | Nothing re-protects an Experience under a new seed. |
| No device-level lock | Protection is per-Experience; there is no app-level biometric gate. |

## API surface actually used

Four operations, deliberately small:

| Import | Used for |
|---|---|
| `package:kaalka/kaalka.dart` | `encrypt(plaintext, timeKey:)`, `decrypt(ciphertext, timeKey:)` |
| `package:kaalka/kaalka_file.dart` | file-level encrypt / decrypt |
| `package:kaalka/kaalka_protocol.dart` | protocol types |

## Contributing here

- **Never** add a `package:kaalka` import outside the adapter.
- **Never** move a trust decision into protection.
- Changes to `lib/security/` require an owner review ([CODEOWNERS](../.github/CODEOWNERS)).
- Security issues go through [SECURITY.md](../SECURITY.md), not a public issue.

Further reading: [`docs/security/`](security/) — trust boundaries, capability
matrix, runtime limits, generated-Experience security.
