# Security Policy

## Reporting a vulnerability

**Do not open a public issue.**

Use [GitHub's private vulnerability reporting](https://github.com/PIYUSH-MISHRA-00/Anything/security/advisories/new)
(Security → Report a vulnerability), or email **dev@gratefulworldventures.in**
with `SECURITY` in the subject.

Please include: what you found, how to reproduce it, what an attacker gains, and
the affected version or commit.

You will get an acknowledgement. Fixes are released as soon as practical and
credited unless you prefer otherwise. This is a small project — there is no
formal SLA, but security reports are prioritised over everything else.

## Supported versions

Pre-release. Only the `main` and `v2.0.0` branches receive fixes.

## The security model, honestly

Understanding what Anything does and does not protect makes for better reports.

### What is enforced

| Property | Mechanism | Certified |
|---|---|---|
| Generated Experiences cannot execute arbitrary code | An Experience is *data* — a behaviour graph the interpreter executes. There is no code path to `eval` | by design |
| Capabilities are enforced, not honour-system | `CapabilityPlatform` refuses anything unregistered | I-49 |
| Declaring a capability does not grant it | Governance decides; the platform enforces | I-90, I-92 |
| Trust is computed in exactly one place | `ExperienceTrustClassifier` | I-50 |
| Reading a package does not install or run it | The reader never installs, activates or computes trust | I-88 |
| Protection is reachable through one adapter | `KaalkaProtectionProvider` → `package:kaalka` | I-21a/c |
| API keys are not stored in plaintext | `CredentialVault` → `flutter_secure_storage` | — |
| Package integrity is verified on read | Checksum against a rebuilt package, so tampering that leaves valid JSON is still caught | I-87 |

### What is NOT protected — please do not report these as vulnerabilities

They are known, deliberate, and documented.

| Gap | Status |
|---|---|
| **Package signatures are not verified** | The container reserves a `signature` block, carries it verbatim, and verifies nothing. A real verifier needs a key-distribution decision that has not been made. |
| **Exported packages are unencrypted** | The `.anything` container is canonical JSON with a checksum. Not yet exploitable — export is not reachable — but it is a real open decision. |
| **No key rotation** | Nothing re-protects an already-protected Experience under a new seed. |
| **A user-supplied AI key is trusted** | Anything does not validate what your provider returns beyond structural validation. |
| **No device-level lock** | Protection is per-Experience. There is no app-level biometric gate. |

### Threat model

Anything is **local-first**: no server, no account, no sync. The primary threats
are a malicious *Experience package* and a compromised *AI provider response* —
both handled as untrusted input by design.

Out of scope: physical device compromise, a compromised Flutter/Dart toolchain,
and attacks requiring an attacker to already have code execution on the device.

Detail: [`docs/security/`](docs/security/) — trust boundaries, capability
matrix, runtime limits, web-content trust, generated-Experience security.

## Secrets hygiene

The release keystore and `android/key.properties` are gitignored, and **CI fails
the build if any keystore, `key.properties` or `.env` file is ever tracked**
(`.github/workflows/ci.yml` → "Confirm no forbidden files are tracked").

If you believe a secret has been committed, report it privately using the
process above rather than opening an issue.
