# Capability Security Matrix — Anything v2.0.0

M2 closure document. See `TRUST_BOUNDARIES.md` for the overarching finding
that the capability platform below is fully built and tested but **not
yet wired into the live `AnythingRuntime`/`BehaviorInterpreter` dispatch
path** — `ExperienceServiceResolver` is the only mechanism a running
Experience can actually reach today, and it only implements `clock`.
Everything in this matrix describes the `CapabilityPlatform` layer as it
exists and is tested in isolation.

| Capability | Declaration required | Trusted limit | Experience-scoped | Session-scoped | Credential access | Network access | Ownership enforcement | Failure mode | Tests |
|---|---|---|---|---|---|---|---|---|---|
| **Clock** (`clock`) | Yes — `CapabilityPlatform.invoke` denies if not in `declaredCapabilities` | 100 invocations/session (`CapabilityPlatform._maxInvocationsPerCapability`) | N/A (no state) | Yes, per `sessionId` | None | None | N/A | Unknown op → `unsupported`; budget exceeded → `policyDenied` | `test/stage81/capability_test.dart`, `test/stage83`, `test/stage84` |
| **Notifications** (`notifications`) | Yes | 100 invocations/session (platform-level); no dedicated schedule-count cap | Yes — constructor `experienceId`, `cancelAll` only cancels own | Yes | None | None | Yes — `FakeNotificationService` ownership map; real service TBD | Empty title → `invalidArguments`; cross-Experience cancel is a silent no-op (correct — not an error) | `test/stage81`, `test/stage82`, `test/stage83`, `test/stage84` ("Notification Ownership") |
| **HTTP** (`http`) | Yes | Host allow-list (exact match, package-declared); HTTPS-only; response ≤ `maxHttpResponseBytes` (5 MB); request body ≤ `maxHttpRequestBytes` (1 MB, no production caller populates a body yet) | Via `allowedHosts` passed at construction, not currently tied to a specific `experienceId` (no cross-Experience host-list sharing risk since each Experience's `HttpCapability` instance is constructed with its own package's declared hosts) | Yes (via `CapabilityPlatform` budget) | None (no credential resolution implemented) | HTTPS only, private/loopback/link-local IPv4+IPv6 blocked, DNS-rebinding re-validated via injectable resolver, redirects NOT auto-followed (returned as a plain 3xx response to the caller) | Scheme/host/DNS/size checks all `policyDenied`; DNS resolution failure fails closed | `test/stage81`, `test/stage82`, `test/security/http_capability_hardening_test.dart` |
| **AI** (`ai`) | Yes | Prompt ≤ `maxAiPromptBytes` (20,000 chars); response truncated to `maxAiResponseBytes` (100,000 chars) | `experienceId` accepted by constructor but not yet used to scope provider/credential selection (no credential integration exists) | Yes | None (provider passed in directly; no vault lookup) | Delegates to injected `AiProvider` | N/A today | Empty/oversized prompt → `invalidArguments`; provider exception → `failed` with `e.toString()` (see Error Redaction note) | `test/stage81/capability_test.dart` |
| **Knowledge** (`knowledge`) | Yes | None dedicated (relies on caller-provided `KnowledgeProvider`); prompt-injection defense lives in `model_reasoner.dart`, not this capability | No (no `experienceId` param at all) | Yes | None | Delegates to injected `KnowledgeProvider` (currently a stub — see `TRUST_BOUNDARIES.md`) | N/A | Empty query → `invalidArguments`; provider exception → `failed` | `test/stage81/capability_test.dart` |
| **File** (`files`) | Yes | `min(requested, trusted)` size (`FileCapability._effectiveMaxSize`, default 5 MB); trusted max cannot be raised by a package-requested `maxSizeBytes` | Yes — constructor `experienceId`; `adoptFile`/`deleteFile` ownership map | Yes | None | None (no path escapes possible — capability only returns opaque `FileReference`s from the injected `FileService`, never a raw path to the Experience) | Yes — cross-Experience `deleteFile` returns `{'deleted': false}` rather than an error (fails safe, not loud) | Oversized file → `policyDenied`; unregistered/foreign file → `deleted: false` | `test/stage81`, `test/stage82`, `test/stage83`, `test/stage84` |

## Cross-cutting platform behavior (`CapabilityPlatform`)

- Unknown capability ID → `CapabilityResultStatus.unsupported`.
- Undeclared capability (not in `declaredCapabilities`) → `policyDenied`,
  checked **before** the budget/operation checks.
- Unsupported operation for a known capability → `unsupported`.
- Budget is `_maxInvocationsPerCapability = 100`, keyed per `(sessionId,
  capabilityId)`; `resetSession(id)` clears one session without affecting
  others (`test/stage84`: "Session Isolation — resetSession does not
  affect other sessions").
- Any exception thrown inside `execute()` is caught at the platform level
  and converted to `CapabilityInvocationResult.failure(e.toString())` —
  never propagates as an unhandled exception.

## Declaration escalation tests

Every builtin capability has at least one "undeclared capability is
denied" test exercised through `CapabilityPlatform.invoke` (not just
Clock, per M2 §27): see `test/stage81/capability_test.dart` ("Cross-
Experience Security — Experience A cannot use undeclared capabilities"),
`test/stage82/security_test.dart` and `test/stage83/final_gate_test.dart`
("Capability Escalation — undeclared capability denied").

## What is NOT yet true (tracked, not silently assumed)

- No real (non-fake) `HttpTransport`, `FileService`, `NotificationService`,
  `AiProvider`, or `KnowledgeProvider` exists in production code.
- No credential-vault integration exists in any capability — `AiCapability`
  and `HttpCapability` do not resolve credentials by purpose; there is
  nothing to leak or enumerate today because nothing reads from the vault.
- `NotificationCapability` has no dedicated per-Experience *schedule*
  count budget beyond the shared platform-level 100/session invocation
  cap — acceptable given the capability isn't reachable from the live
  runtime yet, but worth a dedicated budget when it is wired up.
