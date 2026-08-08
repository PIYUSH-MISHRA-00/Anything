# Kaalka

[`package:kaalka`](https://pub.dev/packages/kaalka) provides Anything's
protection: time-keyed encryption, entirely local.

Full guide:
[KAALKA_GUIDE.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/KAALKA_GUIDE.md).

## One adapter, certified

```
UI → ExperienceProtectionService → ProtectionProvider → KaalkaProtectionProvider
                                                              → package:kaalka
```

Only the adapter imports it. The Kernel and UI cannot, and a test enforces it.

## Protection and recovery

Protection produces a `ProtectedEnvelope` — payload, time seed, timestamp — and
is **deterministic against a supplied seed** rather than reading the wall clock,
which is what makes recovery reproducible and testing possible.

Recovery is **transactional**: the recovered package is persisted through the
commit framework, so a failure part-way cannot leave a half-written Experience.

Protection is reachable from four real places in the app. It is the most
completely wired subsystem in the project.

## Trust is a separate concern

Kaalka protects payloads. It decides nothing about trust.

| Question | Owner |
|---|---|
| Is this payload protected? | `ExperienceProtectionService` → Kaalka |
| How much is this Experience trusted? | `ExperienceTrustClassifier` |
| May it use this capability? | `CapabilityPlatform` |
| May it run in the background? | governance |

The trust classifier deliberately **refuses to treat the presence of a signature
as proof**. Conflating protection with trust would let an attacker earn
authority merely by encrypting something.

## What is NOT protected

Stated plainly, so nobody assumes otherwise:

| Gap | Status |
|---|---|
| Package signatures are not verified | The container reserves the block and checks nothing. A real verifier needs a key-distribution decision |
| Exported `.anything` files are unencrypted | Canonical JSON with a checksum. A real open decision now that export exists |
| No key rotation | Nothing re-protects an Experience under a new seed |
| No device-level lock | Protection is per-Experience; no biometric app gate |

Full security model:
[SECURITY.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/SECURITY.md).
