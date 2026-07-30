# Anything v2.0.0 — Security Audit

Scope note: the dedicated security research agent for this audit was terminated mid-task by an account-level session rate limit. The findings below that are marked VERIFIED were independently re-confirmed by direct source inspection after that cutoff; items marked UNKNOWN were not re-checked in this pass and must not be read as "presumed safe."

## 1. Arbitrary Execution — VERIFIED SAFE

`grep` across all of `lib/` for `Process.run`, `Process.start`, `dart:mirrors`, `eval(` returned **zero hits**. Generated Experiences are interpreted declaratively through `ExperienceRenderer` (component tree → widgets) and `BehaviorInterpreter` (behavior graph → data/navigation operations); there is no path from a generated package to executing arbitrary Dart, shell commands, or downloaded code.

## 2. Component Security — PARTIAL VERIFICATION

- `RuntimeComponentRegistry` (lib/runtime/component_registry.dart) maps a fixed, closed set of component `type` strings to Flutter widget builders (verified: `entityList`, `entityGrid`, `entityDetail`, `entityForm`, `referenceSelector`, `button`, `search`, `dashboardMetrics`, and others present in the file). Unknown component types were reported by `stage11_security_certification_test.dart`'s "Unknown component type renders safely (no crash)" test, which passed in this audit's `flutter test test/stage11` run — a real, executed positive signal.
- Max-depth / max-children / total-component-count enforcement was **not independently re-verified** this pass (UNKNOWN). `stage11_security_certification_test.dart` is described (not re-read in full) as covering "component budgets" — should be confirmed to run against the production validator, not a test-local reimplementation, before being cited as a control.

## 3. Behavior Security — PARTIAL VERIFICATION

`BehaviorInterpreter` (lib/runtime/behavior_interpreter.dart, including this session's working-tree state):
- `_maxNodesPerExecution = 100` constant present — a real execution budget exists.
- Execution walks a `BehaviorGraph` starting from an event-matched node; unknown/unmatched event IDs return early (`if (startNode == null) return;`) rather than failing open.
- The new generic-event resolution (`_resolveGenericEvent`) maps renderer-level event IDs (`submitForm`, `deleteRecord`) to entity/action-specific graph nodes by string matching on `entityId` and a fixed set of prefixes (`create_`/`add_`, `update_`/`edit_`, `delete_`/`remove_`) — this is data-driven matching against the package's own declared graph, not arbitrary code, so it does not weaken the trust boundary.
- Cycle handling: the `execute`/`_executeNode` signature carries a visited-node `Set<String>` parameter (seen in the diff, `<String>{}` initial call) suggesting cycle guarding exists; not independently traced to confirm it actually prevents infinite loops in a maliciously-constructed graph — UNKNOWN, worth a dedicated check before release.
- No arithmetic/eval escape hatch found in the reviewed portions.

## 4. Query Security — NOT INDEPENDENTLY VERIFIED (UNKNOWN)

`ExperienceDatabase` queries use `sqflite`'s parameterized `db.query(where: 'entity = ?', whereArgs: [...])` (verified in lib/storage/experience_database.dart) — **no raw string-concatenated SQL was found in the reviewed CRUD methods**, which rules out classic SQL injection in insert/query/readById/update/delete/count. Search filtering (via `searchTerm`) happens in Dart over the already-fetched result set, not as a SQL predicate, so it carries no injection surface either. `ExperienceQueryController`'s budget/pagination/allowed-fields behavior was not independently re-verified — UNKNOWN.

## 5. Capability Inventory — PARTIAL

Only `HttpCapability` was read in depth this pass (see §6). `Clock`, `Notifications`, `AI`, `Knowledge`, `File` capabilities exist under `lib/capabilities/{builtin,platform,registry}` per directory listing but were not individually opened/verified for registration, budget, ownership/isolation, or permission enforcement in this pass — UNKNOWN, flagged for the roadmap.

## 6. HTTP Capability / SSRF — VERIFIED (core controls)

`lib/capabilities/builtin/http_capability.dart`:
- Blocks `localhost`, `127.0.0.1`, `::1`, `0.0.0.0` explicitly.
- Blocks the entire `172.16.` through `172.31.` range and `192.168.` — real private-range coverage, not a token gesture.
- Enforces `url.startsWith('https://')`, rejecting non-HTTPS with an explicit error.
- **Not verified this pass:** `10.0.0.0/8` range coverage (not seen in the excerpt read), redirect-following behavior (does a 30x redirect to a blocked host get re-validated?), request size limits, and timeout enforcement beyond the `HttpRequest.timeout` field's existence (its default is `30s`, but whether it's actually honored by the transport implementation wasn't traced). Recommend closing this out before relying on the HTTP capability for untrusted generated-app network access.

## 7. Kaalka — VERIFIED

- Exact locked version `5.0.0` (pubspec.lock).
- Single canonical adapter: `lib/legacy/kaalka_adapter.dart` (`KaalkaProtectionProvider`), imported only by `lib/security/protection_service.dart`. No duplicate/parallel cryptography implementation found elsewhere in `lib/`.
- 18/18 Stage 9.4 tests pass against the real package (not mocked) — protect/unprotect roundtrip, wrong-time rejection, trusted-opening status codes, Activity-independence, restart persistence.
- Naming caveat: the adapter lives in a directory literally named `lib/legacy/` despite being the live, canonical implementation — this is a real risk for a future contributor mistaking it for dead code and deleting or "modernizing" it. Recommend renaming the directory/file in a later cleanup milestone (not urgent, not a security defect, purely a naming hazard).

## 8. WebWeaveX — VERIFIED (import boundary), PARTIAL (trust model)

- Exact locked version `3.0.0`.
- Single import site across all of `lib/`: `lib/knowledge/webweavex_adapter.dart` — the intended "behind an abstraction" boundary is real, not aspirational.
- **Not independently re-verified this pass:** whether content retrieved via WebWeaveX is explicitly treated as untrusted data when it reaches the synthesis/reasoning prompt pipeline (Part LIX's prompt-injection concern) — i.e., is there any sanitization/labeling that prevents retrieved text from being interpreted as instructions that could influence component/capability trust decisions? UNKNOWN — recommend a dedicated check as part of the knowledge-integration milestone.

## 9. Secrets / Repo Hygiene — VERIFIED

- No `.env`, no committed keystores/`.jks`/`.keystore`, no credential files found in the tracked tree.
- `android/.gitignore` correctly excludes `local.properties`, `key.properties`, `**/*.keystore`, `**/*.jks`.
- `.mimocode/` (untracked local automation config) is not covered by any `.gitignore` — low risk, but should be added to prevent an accidental `git add -A` commit; it was not observed to contain credentials, only a scheduler config and its own package-lock.

## 10. Cross-Experience Isolation — UNKNOWN

Each Experience gets its own SQLite file (`experience_<id>.db`), which gives basic filesystem-level data isolation, but capability-level isolation (can one Experience's declared capabilities/credentials leak into another's runtime context?) was not independently re-verified this pass.

## 11. Android Permissions — UNKNOWN

Not independently re-verified this pass (the design/Android research agent was cut off before reporting; not re-checked directly due to session time constraints). Flagged for the Android/Play Store milestone.

## Summary

No critical, currently-exploitable vulnerability was found in the areas actually reviewed (arbitrary execution, SQL injection surface, core SSRF controls, Kaalka boundary). The main security-relevant gap is **coverage**, not a known hole: several capability/isolation/behavior-cycle questions are UNKNOWN rather than verified, and should be closed out before a public release rather than assumed safe by omission.
