# Anything v2.0.0 — Security Audit

**M2 Security & Runtime Coverage Closure — updated 2026-08-01.**

Scope: close every security-relevant UNKNOWN left by the prior audit pass
(see git history for the original, pre-M2 version of this file, which was
written under an account-level session cutoff and is superseded by this
version). Every row below was independently re-verified by direct source
inspection this pass, backed by either pre-existing tests (cited) or new
adversarial tests added under `test/security/` this milestone. See
`docs/security/TRUST_BOUNDARIES.md`, `docs/security/CAPABILITY_SECURITY_MATRIX.md`,
and `docs/security/RUNTIME_LIMITS.md` for the detailed supporting documents
this audit produced.

**Master finding (read this first):** the `CapabilityPlatform` and all
five builtin capabilities are fully implemented and well-tested in
isolation, but are **not yet wired into the live `AnythingRuntime` /
`BehaviorInterpreter` execution path**. `ExperienceServiceResolver` — the
only capability dispatch mechanism actually reachable from a running
Experience's behavior graph today — implements only `clock`'s `now`/`date`
operations; HTTP/database/notifications/file/knowledge/AI all return
`not_implemented` or fall through to a safe "unknown service" error. This
materially narrows today's live attack surface for network/file/
notification/AI/knowledge concerns (they are not currently reachable from
a generated Experience) while the capability code itself has still been
hardened per M2, in anticipation of the wiring work being sequenced later
(explicitly out of M2 scope — M2 audits and hardens what exists, it does
not integrate new runtime plumbing). See `TRUST_BOUNDARIES.md` for the full
account.

## 1. Arbitrary Execution — VERIFIED SAFE

Zero hits across all of `lib/` for `Process.run`, `Process.start`,
`dart:mirrors`, `dart:ffi`, `eval(`, `Isolate.spawn`, JS-evaluation APIs
(`evaluateJavascript`/`runJavaScript`/`package:js`), or native-code loading
(`dlopen`). The one JS-capable surface in the repo (`webview_flutter`, used
by `lib/screens/groq_webview_screen.dart`) is a legacy v1 settings screen
instantiated only with a hardcoded default URL (`const GroqWebViewScreen()`,
no `url` argument ever passed) — no `ExperiencePackage`, behavior graph, or
capability declaration has a data path into it. Generated Experiences
remain 100% declarative, interpreted only through `ExperienceRenderer`'s
closed widget registry and `BehaviorInterpreter`'s closed operation set.
Regression test: `test/security/behavior_cycle_safety_test.dart` (behavior
side) plus the pre-existing `stage11_security_certification_test.dart`
"Forbidden Executable Components" group (component side, asserts `shell`,
`terminal`, `javascript`, `dartCode`, `eval`, `exec`, `process` are all
unregistered types).

## 2. Component Security — VERIFIED

- Depth/children/count budgets (20 / 50 / 500) confirmed enforced by
  `ComponentTreeValidator` against the actual production validator (not a
  test-local reimplementation) — `stage11_security_certification_test.dart`.
- **New this pass:** max screens per package (100), max behavior nodes per
  package (5000), max component property text length (20,000 chars), max
  manifest field length (500 chars), and max serialized package size
  (5 MB, checked first, before any structural walk) — all added to
  `ExperiencePackageValidator`/`ComponentTreeValidator` and centralized in
  `RuntimeSecurityLimits`. Adversarial tests:
  `test/security/package_and_query_limits_test.dart`.
- Unknown component types: `RuntimeComponentRegistry.buildComponent`
  returns `null` for unregistered types; `ExperienceRenderer` renders
  nothing for a `null` builder rather than crashing (no dynamic class
  lookup, no package-controlled import) —
  `stage11_security_certification_test.dart` "Unknown Component" group.

## 3. Behavior Security — VERIFIED (previously the audit's flagged UNKNOWN)

Traced `BehaviorInterpreter._executeNode` directly: a single `visited`
`Set<String>` is created once per `execute()` call (i.e. per dispatched
event, not per session or globally) and threaded through the entire
recursive walk. The budget check (`visited.length >=
_maxNodesPerExecution`, 100) runs **before** a node is added to `visited`
or executed, and `visited.add(node.id)` returning `false` (already
present) short-circuits any re-visit — this is what makes cycles
terminate: `A→A`, `A→B→A`, and `A→B→C→A` each execute every distinct node
exactly once, regardless of how many edges point back. Because the budget
check happens before recursing deeper, a malicious 5000-node or 100,000-
node chain only ever recurses to a depth bounded by the budget (100) —
no stack-overflow risk, and no partially-executed dangerous tail past the
budget boundary (verified with a `dataMutation: delete` node deliberately
wired past the 100th slot — it never executes, target record survives).
Event re-entrancy: `dispatchEvent` (`AnythingRuntime`) is the only call
site for `BehaviorInterpreter.execute`, and no behavior node type
(`stateWrite` included) calls `dispatchEvent`/`execute` from within
`_executeByType` — a generated behavior graph cannot construct an
onTap→setState→event→setState→event feedback loop because nothing in the
interpreter re-enters itself; state writes only broadcast to `Stream`
watchers used for widget rebuilds, never to re-fire an event. All of the
above is now backed by adversarial tests, not just code reading:
`test/security/behavior_cycle_safety_test.dart` (10 tests: direct cycles,
per-event budget at limit−1/limit/limit+1/5000-node malicious graph,
dangerous-tail rejection, re-entrancy).

## 4. Query Security — VERIFIED (previously UNKNOWN)

- SQL injection: **structurally eliminated**, not just parameterized.
  `ExperienceDatabase` uses a single generic `records` table
  (`id, entity, data, created_at, updated_at`) where `entity` is always a
  bound `whereArgs` value and record content is an opaque JSON blob in the
  `data` column — there are no per-entity dynamic tables or columns in the
  live runtime, so a malicious entity/field name literally cannot become a
  SQL identifier through this path (there's no identifier derived from
  package content at all). The one `rawQuery` (`COUNT(*)`) is parameterized.
  Confirmed with malicious identifiers (`"person'; DROP TABLE records; --"`)
  in `stage11_security_certification_test.dart` "Malicious Query" group.
- **New this pass — unbounded fetch fixed:** `ExperienceDataRuntime.query()`
  and `ExperienceDatabase.query()` previously fetched **every** row for an
  entity with no limit at all, before any client-side `DataQuery`
  filter/sort/limit was applied — a real resource-exhaustion vector for a
  large or malicious table. Fixed: both now accept an optional `limit`,
  clamped to `RuntimeSecurityLimits.maxFetchRowsPerQuery` (1000, same as
  `DataQuery.maxResultLimit`) via `min(requested, trusted)`, enforced at
  the SQLite layer (`db.query(..., limit: effectiveLimit)`), never
  silently raised. Certified against real SQLite with 1050 inserted rows
  in `test/security/package_and_query_limits_test.dart`. Documented,
  intentional scalability trade-off: search/filter/sort only sees the
  oldest `maxFetchRowsPerQuery` rows (see `RUNTIME_LIMITS.md` "Search
  scalability") — a real indexed SQL search is out of M2 scope by design
  (§15 of the M2 charter: "a fully indexed search engine is NOT required").
- `DataQuery` already enforced `maxResultLimit` (1000, rejects rather than
  clamps if a caller requests more), `maxFilters` (20), `maxSorts` (5) —
  `stage11_security_certification_test.dart` "Query Limit Enforcement".

## 5. Capability Inventory — VERIFIED

Full inventory in `docs/security/CAPABILITY_SECURITY_MATRIX.md`. All five
builtins (Clock, Notifications, HTTP, AI, Knowledge) plus File read in
full. Declaration enforcement tested for every capability, not just Clock
(`test/stage81`, `test/stage82`, `test/stage83` "Capability Escalation"
groups). Per-session, per-capability invocation budget (100) verified
isolated across sessions (`test/stage84` "Session Isolation").
`CredentialVault` is fully implemented (FlutterSecureStorage-backed,
purpose-scoped key prefix, no enumeration API) but is **not instantiated
anywhere in production code** — no capability currently resolves
credentials from it, so purpose-scoping/cross-Experience-collision is a
design constraint for whoever wires it up next, not a live exploit path
today (documented in `TRUST_BOUNDARIES.md`).

## 6. HTTP Capability / SSRF — VERIFIED, hardened this pass

Pre-existing: HTTPS-only, `localhost`/`127.0.0.1`/`::1`/`0.0.0.0` blocked,
full `10.0.0.0/8` + all of `172.16.0.0/12` + `192.168.0.0/16` +
`169.254.0.0/16` blocked, undeclared-host denial
(`test/stage81`, `test/stage82`).

**New this pass:**
- IPv6 coverage completed: unique-local (`fc00::/7`), link-local
  (`fe80::/10` — via Dart's `InternetAddress.isLinkLocal`), and IPv4-mapped
  IPv6 (`::ffff:0:0/96`, decoded back to its embedded IPv4 and re-checked)
  are all now blocked, using `dart:io`'s own address parser rather than a
  hand-rolled one (per M2 §34).
- DNS-rebinding re-validation: before connecting, the resolved host's
  addresses are checked against the same private/reserved-range logic —
  a declared, allowed hostname that resolves to a private IP is denied;
  resolution failure fails closed (denied, not proceed-unresolved).
  Resolver is injectable (`HostResolver` typedef) so tests never touch
  live DNS (M2 §66).
- Response body size bound (`maxHttpResponseBytes`, 5 MB) and request body
  size bound (`maxHttpRequestBytes`, 1 MB) enforced in `HttpCapability`
  itself, independent of whatever a future real transport does.
- Redirects: `HttpCapability` does **not** auto-follow redirects (a 3xx
  response passes through to the caller as-is); since no real
  `HttpTransport` implementation exists in production yet either, there is
  no redirect-following code path today, so the "public URL redirects to
  private IP" vector is not currently exploitable. Documented as a hard
  requirement for any future real transport: it must not auto-follow
  redirects internally — `HttpCapability` must own manual, re-validated
  redirect following bounded by `maxHttpRedirects` (5).
- Timeout: `HttpRequest.timeout` defaults to 30s; no caller-supplied
  override path exists today (nothing reads a timeout param from
  `params`), so there is currently nothing for a package to raise.

All new behavior backed by
`test/security/http_capability_hardening_test.dart` (10 tests, no live
network).

## 7. Kaalka — VERIFIED, tamper tests added this pass

- Exact locked version `5.0.0` (pubspec.lock). Single canonical adapter
  chain: `lib/legacy/kaalka_adapter.dart` (`KaalkaProtectionProvider`,
  implements the `ProtectionProvider` contract) wraps
  `lib/security/kaalka_service.dart` (the only file that imports
  `package:kaalka/...` directly, per its own docstring convention) — this
  is a clean two-layer wrapper, not a duplicate parallel crypto
  implementation. `lib/security/encryption_manager.dart` reuses the same
  `kaalkaServiceProvider`, so there is exactly one path to Kaalka.
- 18/18 Stage 9.4 tests pass against the real package (protect/unprotect
  roundtrip, wrong-time rejection, trusted-opening status codes,
  Activity-independence, restart persistence).
- **New this pass:** `test/security/kaalka_tamper_test.dart` — a
  bit-flipped persisted ciphertext fails closed via the existing generic
  decrypt-exception handler (`UnprotectionFailed`, message contains
  neither the word "exception" nor the corrupted ciphertext itself); a
  protection-flag-set-but-envelope-missing partial-write state (simulated
  crash mid-`_protect()`) correctly recovers the still-present plaintext
  rather than crashing or losing data when the plaintext row is present,
  and fails safely (`UnprotectionFailed`) when it is not.
- Naming caveat (carried over, not urgent): `lib/legacy/kaalka_adapter.dart`
  is the live, canonical implementation despite the `legacy/` directory
  name — recommend renaming in a later cleanup milestone (M6).

## 8. WebWeaveX — VERIFIED (import boundary), stub confirmed (retrieval)

- Exact locked version `3.0.0`. Single import site:
  `lib/knowledge/webweavex_adapter.dart`.
- **Resolved this pass (was UNKNOWN):** `WebWeaveXAdapter.retrieve()` does
  not perform any real web extraction today — it returns a synthetic
  `KnowledgeResource` whose content is a templated echo of the query
  string (explicit code comment acknowledges this: "For now, return the
  query as a knowledge resource"). Despite this, the prompt-injection
  defense at the consumption point (`ModelApplicationReasoner` in
  `lib/synthesis/model_reasoner.dart`) is already implemented and matches
  M2 §50 exactly: knowledge is delimited with explicit untrusted-data
  markers, the model is explicitly instructed not to follow instructions
  or execute code found in it, `_sanitizeContent()` strips common
  injection phrases as defense-in-depth, and content is size-bounded
  (`_maxKnowledgeContextSize`, 4000 chars) with rank-ordered truncation.
  This defense already applies to whatever content real WebWeaveX
  extraction eventually returns, without further changes needed. See
  `TRUST_BOUNDARIES.md` "Current retrieval status."

## 9. Secrets / Repo Hygiene — VERIFIED

- No `.env`, no committed keystores/`.jks`/`.keystore`, no credential
  files found in the tracked tree (re-confirmed this pass).
- `android/.gitignore` correctly excludes `local.properties`,
  `key.properties`, `**/*.keystore`, `**/*.jks`.
- `.mimocode/` (untracked local automation config, contains a plaintext
  Google API key) remains untracked/ignored; not committed. **Recommend
  the user rotate this key** — out of scope for automated remediation.
- `CredentialVault` correctly uses `FlutterSecureStorage`, never
  `SharedPreferences` or plaintext SQLite/JSON (confirmed by direct source
  read, not just grep).

## 10. Cross-Experience Isolation — VERIFIED (previously UNKNOWN)

- **Data:** each Experience gets its own SQLite file
  (`experience_<id>.db`); `test/stage81/persistence_test.dart` "Experience
  Isolation — different Experiences have isolated data" proves this
  through real SQLite, not by inspection alone.
- **Capabilities:** ownership enforced per capability instance via
  constructor-supplied `experienceId` (File, Notifications); cross-
  Experience file delete/notification-cancel attempts fail safely
  (`deleted: false` / no-op) rather than erroring loudly — verified in
  `test/stage82`, `test/stage83`, `test/stage84`.
- **Capability budgets:** per-session invocation counts, independently
  resettable per session (`test/stage84` "Session Isolation").
- **Kaalka envelopes:** keyed by `experienceId` in
  `SqliteExperienceRepository`; no shared/global envelope storage.

## 11. Android Permissions — UNKNOWN (unchanged — explicitly out of M2 scope)

Not part of M2's security/runtime charter (M2 explicitly excludes M5
Android/Play Store work). Remains flagged for M5.

## 12. Relationships / Referential Integrity — VERIFIED, one crash bug fixed

`referenceEntityId` is presentation metadata only (drives a reference-
picker dropdown); there is no cascade/restrict/set-null policy enforced
on delete anywhere in the codebase — deleting a referenced parent record
leaves a dangling ID in the child. **Found and fixed this pass:** the
reference-field dropdown (`ExperienceRenderer._buildReferenceField`)
passed a possibly-dangling ID straight to `DropdownButtonFormField`'s
`initialValue`, which asserts/throws if the value doesn't match one of
the currently-available items — a parent delete followed by opening an
editor for an orphaned child would have crashed the render. Fixed:
`initialValue` now falls back to `null` (unselected) when the stored
value isn't among the currently-queried records, rather than passing the
dangling ID through. This is now the documented, deterministic policy:
**no cascade or restrict is enforced; dangling references render as
unselected rather than crashing.** A real restrict/cascade policy is a
data-model feature for a future milestone, not a v2.0.0 security
requirement (no cross-Experience boundary is at stake — this is single-
Experience data-model correctness).

## 13. Modification Engine — VERIFIED

Traced the full path: scoped modification intent → `ModificationEngine.modify()`
(pure/immutable — every stage builds a new object from the existing
package's fields; the existing package instance is never mutated in
place) → candidate `ExperiencePackage` → `ExperiencePackageValidator.validate()`
→ only on success does `ExperienceModificationCoordinator` call
`_repository.savePackage()`. On validation failure, `savePackage` is never
called, so the old package row is untouched — verified structurally (the
engine's immutability) and behaviorally: `test/security/modification_rollback_test.dart`
constructs a modification spec that blows the behavior-node-count budget,
confirms the validator rejects the candidate, and confirms the original
in-memory package object is byte-for-byte unchanged. Experience ID is
preserved across modification (`existingPackage.manifest.experienceId`
carried through unchanged); version is bumped
(`ModificationEngine._bumpVersion`). Pre-existing coverage
(`test/stage81/modification_test.dart`) further proves UI-node addition,
behavior-node addition, schema/entity addition with `schemaVersion` bump,
and data preservation across a capability-adding modification, all
through the real `ModificationEngine`.

## 14. Migration System — VERIFIED, hardened this pass, confirmed not on the live path

`MigrationExecutor`/`SchemaStorageMapper`/`migration.dart`
(`lib/storage/`) are **not called anywhere in production code** outside
their own `test/stage83`/`test/stage84` tests — grepped and confirmed zero
call sites in `lib/app/` or `lib/creation/modification/`. This is
architecturally sound, not an oversight: the live storage layer
(`ExperienceDatabase`) stores every record as an opaque JSON blob in one
generic table, so adding a field/entity to a `DataSchema` needs no SQL
DDL migration at all — old JSON blobs simply lack the new field until
next written. `ModificationEngine._applyDataOps` only edits the in-memory
`DataSchema`, confirming it never touches this migration module.

**Found and fixed anyway (defense-in-depth for if this module is ever
wired up):** `SchemaStorageMapper.buildFromSchema` interpolated the raw
`experienceId` parameter directly into a SQL table name
(`'exp_${experienceId}_e$i'`), later used inside `[...]`-bracket-quoted
DDL identifiers in `MigrationExecutor`. `experienceId` can originate from
model-generated JSON (`AppBlueprint.fromJson`'s `id` field is untrusted
LLM output, per `BlueprintToSpecConverter.convert`), and SQLite's
`[...]` quoting does not escape an embedded `]` character — a crafted
`experienceId` could theoretically break out of the identifier. Fixed:
`experienceId` is now sanitized to a bounded `[a-zA-Z0-9_]` token before
being folded into a table name, so it cannot contain any quoting/
terminator character of any SQL identifier-quoting style. Existing
adversarial coverage already confirmed unregistered/malicious *entity*
names never become table names at all
(`test/stage83`: "malicious entity name is rejected";
`test/stage84`: "malicious entity name fails and data survives",
"rollback after partial mutation" — transactional rollback verified
against real SQLite).

## 15. AI Capability / Model Output — VERIFIED

- `AiCapability`/`KnowledgeCapability` correctly use a `ModelProvider`/
  `AiProvider`/`KnowledgeProvider` abstraction — no hardcoded vendor, no
  arbitrary local-secret selection.
- **New this pass:** prompt length bound (`maxAiPromptBytes`, 20,000
  chars, `invalidArguments` if exceeded) and response length bound
  (`maxAiResponseBytes`, 100,000 chars, truncated rather than rejected —
  preserves a successful generation's utility while still bounding
  memory) added to `AiCapability.execute`.
- Model output (the actual LLM JSON, not just the AI capability) is
  thoroughly defended in `ModelApplicationReasoner._parseResponse`/
  `_extractJson`/`_parseSemanticApp`: direct JSON parse, fenced-code-block
  extraction, and bare-`{...}`-regex extraction are all tried in order;
  missing fields fall back to safe defaults (`?? ''`, `?? []`, `?? true`);
  malformed types (`as String` on a non-string) throw `TypeError`, caught
  by a generic `catch` and converted to `ReasoningFailed` with a redacted,
  generic message — never a raw exception or partially-built package.
  Composite/deterministic-reasoner fallback (`composite_reasoner.dart`)
  does not attempt to "guess" a structure from malformed model output; it
  fails to the deterministic path instead.

## 16. Error Redaction / Logging — VERIFIED, one residual noted

Grepped all of `lib/` for `print`/`debugPrint`. Real logging is confined
to `lib/services/analytics_service.dart` (a dev-diagnostic wrapper for
analytics/crash/performance events — no evidence of credential/secret
logging) and one benign webview-error log in the legacy v1
`groq_webview_screen.dart`. No stack traces, file paths, SQL, or crypto
internals found routed to user-facing UI text — capability/reasoner
failure paths consistently return short, generic messages
(`ReasoningFailed(error: 'Unable to create this type of app...')`,
`UnprotectionFailed(message: 'Wrong protection key — try a different
time')`). **Residual, low-risk note:** several capability `catch` blocks
(`HttpCapability`, `AiCapability`, `KnowledgeCapability`) surface
`e.toString()` directly in `CapabilityInvocationResult.error`; Dart
exception `toString()` is typically a short message (not a full stack
trace), but this is not a hardened allowlist — acceptable for M2 given
these capabilities are not yet reachable from a live Experience (see
master finding), worth a dedicated redaction pass once they are wired up.

## 17. Package Integrity / Version / Size — VERIFIED

- SHA-256 integrity hash computed over the canonical JSON before Kaalka
  protection and re-verified after decryption
  (`ExperienceProtectionService._protect`/`unprotect`); mismatch →
  `UnprotectionFailed`, never a silently-accepted tampered package.
- Unsupported future `packageVersion` rejected by
  `ExperiencePackageValidator.validate` (`packageVersion > experiencePackageVersion`
  → error) — fails closed, no blind execution of an unknown schema
  version.
- **New this pass:** trusted maximum serialized package size (5 MB),
  checked first in `validate()`, before any structural tree walk — an
  oversized package is rejected cheaply rather than forcing expensive
  processing.

## Summary

Every UNKNOWN row from the pre-M2 audit is now VERIFIED (or, where
genuinely out of scope — Android permissions, design parity — explicitly
deferred to its own milestone, not silently assumed safe). The dominant
theme of this pass was discovering that the codebase's actual security
posture is considerably better-tested than the prior audit credited (a
large amount of `test/stage81`-`test/stage84` coverage already exercised
exactly what M2 asked for), combined with one architecturally significant
finding — the capability platform is not yet wired to the live runtime —
that meaningfully narrows today's real attack surface while still being
worth hardening ahead of that integration. Concrete fixes made this pass:
unbounded-SQLite-fetch DoS, a dangling-reference render crash, a latent
DDL-identifier-injection path in an unused migration module, HTTP
IPv6/DNS-rebinding/response-size gaps, AI capability input/output bounds,
and new package-level structural budgets (screens, behavior-node count,
property text length, package size). Zero critical, currently-exploitable
vulnerability was found in the live generated-Experience runtime.
