# Remaining Gap Matrix — IS-R46, updated by IS-R47

Everything the repository-wide audit surfaced that is **not** resolved. Each
row cites real evidence; nothing here is hypothetical.

Severity: **A** = architectural integrity, **B** = correctness/UX,
**C** = hygiene.

## CLOSED BY IS-R47

| # | Gap | How it was closed |
|---|---|---|
| G-01 | Dead, name-colliding v1 runtime contract | **DELETED.** Re-verified repository-wide that nothing implemented it and all six of its symbols were unused, then removed `lib/core/contracts/runtime.dart`. `AnythingRuntime` now declares exactly once; `knownDuplicateDeclarations` is empty. Three guards prevent its return (I-15, I-15b, I-15c), mutation-proven. |
| G-07 | Stale R44 comment in `experience_activation_manager.dart` | **CORRECTED** (documentation only, no behavior change). It now names `ExperienceEntryPipeline` as the single pusher, states plainly that the old `HomeScreen` claim was never true, explains why it was deliberately left through R45/R46, and points at the invariants that now enforce it mechanically. |
| G-08 | `HomeScreen` submit-button reactivity | **FIXED.** The icon subtree is wrapped in a `ValueListenableBuilder<TextEditingValue>` on the existing `_textController` — the native Flutter mechanism, rebuilding only that subtree. No new state, no listener to dispose, no business-logic change. |
| G-10 | WebWeaveX deterministic serialization unused | **IMPLEMENTED** (IS-R47 Task 4). See `WEBWEAVEX_USAGE_MATRIX.md` W-1. |

## CLOSED BY IS-R48

| # | Gap | How it was closed |
|---|---|---|
| G-13 | `KnowledgeCache` in-memory only; no cross-restart persistence | **CLOSED.** Persistence added *inside* `KnowledgeCache` as an implementation detail, backed by a new `KnowledgeRepository` following the same per-domain pattern as the ten repositories already in `lib/storage/`. Canonical ids, hashes and representations are proven byte-identical across a genuine restart. Restoration is lazy and per-key — no startup scan, no eager load. |

## Gaps IS-R48 found and closed within the same milestone

| # | What happened |
|---|---|
| G-14 | **`KnowledgeResource.toJson()` silently dropped `content`**, and `fromJson()` never read it — so `fromJson(toJson(r))` returned a resource with `content == null`. A latent round-trip bug in `KnowledgeBundle` serialization (its only consumer) that was harmless while nothing round-tripped resources, and fatal for R48: `canonicalRepresentation()` includes `content`, so a content-less round trip would have produced a DIFFERENT canonical representation after restart. Fixed and directly tested. |
| G-15 | **The certification scanner was blind to string interpolations.** A mutation probe reintroducing timestamp ids as `return 'wwx-${DateTime.now().microsecondsSinceEpoch}';` **passed** certification, because the offending code sat inside a string literal and the stripper blanked string contents wholesale — meaning *any* logic inside `${...}` was invisible to *every* static invariant. The instrument was fixed (interpolations now survive stripping) and a self-certification test added. This is the **third** scanner defect found by mutation or tooling rather than by inspection, after R46's vacuously-passing import scan and R47's incomplete reference search. |
| G-16 | **The restart test had the same blind spot from the other direction.** It extracted once and then only round-tripped the stored value, so it would have passed with timestamp ids too. A stronger test now re-extracts the same page in the second session and requires the fresh id to equal the persisted one — true only if identity is genuinely canonical. |
| G-17 | **Stale rationale in `knowledge_graph_bridge.dart`.** Its R2 doc comment stated `KnowledgeResource.id` is `'wwx-${microsecondsSinceEpoch}'`, "a fresh value on every fetch, by design" — true when written, false since R47. Corrected (documentation only). The R2 *decision* to key the World Graph on `sourceUri` still stands, on stronger footing: a page edited between fetches now correctly yields a different canonical id, and keying on that id would split one real entity into two nodes. |

## A gap R47 created and closed within the same milestone

| # | What happened |
|---|---|
| G-11 | Deleting `lib/core/contracts/runtime.dart` left a **dangling barrel export**. `lib/core/contracts/contracts.dart` re-exported it as `export 'runtime.dart';` — a **relative** path with no `contracts/` segment, which R47's first verification search (for the literal text `contracts/runtime.dart`) never matched. The deletion produced `uri_does_not_exist` and moved the analyzer baseline 71 → 72, which is how it surfaced. The export was removed and invariant I-15 widened to match `import|export` on the anchored bare filename. **Lesson recorded rather than hidden: a "find all references" search must cover `export` and relative paths, not just `import` and package paths.** |
| G-12 | The widened I-15 pattern `[^'"]*runtime\.dart` then matched `anything_runtime.dart` — the LIVE implementation — producing a repository-wide false positive that failed the full suite. Anchored to `(?:[^'"]*/)?<basename>['"]`. **Caught by the full suite, not by inspection.** |

## Open gaps

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-02 | C | **`MinimalKernel` is dead.** `lib/kernel/minimal_kernel.dart` declares it; nothing constructs it. | Repository-wide construction scan: 1 occurrence, its own declaration. | **Still open.** R47's spec scoped Task 1 to the runtime contract specifically. Unlike G-01 this name collides with nothing, so it is inert. Deletion is a candidate for R48 review. |
| G-03 | A | **Two production `Fake*` services are registered in the real composition.** `AppComposition` lines 229–230 register `FakeNotificationService()` and `FakeFileService()`. | `lib/app/app_composition.dart:229-230`. | These are real product gaps (notifications and file access are genuinely unimplemented), not architectural violations. Fixing them is feature work, not certification. |
| G-04 | A | **`EncryptionManager` bypasses the `ProtectionProvider` contract** (path K-B), reaching `KaalkaService` directly. | `security/encryption_manager.dart:40,45`; consumers `memory/memory_manager.dart`, `screens/kaalka_security_screen.dart`. | Collapsing it into the canonical contract is a real architectural change requiring review. Does **not** violate I-21a — there is still exactly one crypto importer. See `KAALKA_USAGE_MATRIX.md` §2. |
| G-05 | B | **`savePackage()` stores Experience packages in plaintext by default.** Kaalka protection is opt-in per Experience. | `storage/sqlite_experience_repository.dart:172` vs `:292`. | Confirmed deliberate product design, cited in three places in `lib/`. Restated because "Kaalka is canonical" is easily misread as "everything is encrypted". Not a defect; a disclosure. |
| G-06 | B | **`IntentRepository` stores raw user intent text unprotected.** User-authored natural language can be sensitive. | Persistence audit, `KAALKA_USAGE_MATRIX.md` §3. | Product/security decision, out of certification scope. Worth explicit review. |
| G-09 | C | **`FakeKnowledgeProvider` lives in production `lib/`.** | `capabilities/builtin/knowledge_capability.dart:12`. Verified **not** wired in production — `AppComposition:220` wires the real `KnowledgeAcquisitionProviderAdapter`. | **Still open.** Harmless test double in the wrong directory. Hygiene only. |
| G-18 | C | **Persisted knowledge has no size ceiling or eviction.** The durable store grows until `clear()`. Each resource is bounded by `RuntimeSecurityLimits.maxKnowledgeBytes` (200 KB), but the number of rows is not. | `lib/storage/knowledge_repository.dart`. | **Open, deliberately.** IS-R48 Task 5 required reusing existing expiration policies and forbade a second policy engine — and a repository-wide search found the knowledge subsystem has **no** TTL, eviction or staleness rule to reuse. Inventing one would have been exactly the speculative machinery the rules forbid. The honest position: R48 gave persistence the same replace-on-put/clear semantics the in-memory cache always had, and a real retention policy is a deliberate product decision for a future milestone. |
| G-19 | C | **The 3 network-dependent knowledge tests could not run in this environment.** They self-skip when there is no outbound network. | `test/knowledge/performance_test.dart`, `test/knowledge/knowledge_pipeline_production_test.dart`. | **Environmental, not a defect.** They passed during R47's run (network up) and skipped during R48's (network down). They exercise the real DuckDuckGo + WebWeaveX path, so R48's changes to that path are verified only by the injectable-fetcher tests, not against live network. Stated plainly rather than reported as a clean pass. |

## Deliberately closed options — recorded so they are not reopened by accident

| Option | Decision | Reason |
|---|---|---|
| Adopt WebWeaveX runtime graph / memory fabric | **REJECTED** | Would create a second graph and second memory system — direct "no parallel architecture" violation. |
| Route Kaalka crypto through WebWeaveX v5 | **REJECTED** | Would create a second protection path and break I-21a. |
| Put the certification layer in `lib/` | **REJECTED** | Zero runtime value; would ship dead weight and be exactly the speculative parallel machinery the rules forbid. Certified: R46 added nothing to `lib/` (I-34). |
| Add test-only public accessors to `HomeScreen` for identity assertions | **REJECTED** | Production surface for test convenience. Certified structurally instead; recorded as a known limitation. |

## Limitations of the certification itself

| # | Limitation | Impact |
|---|---|---|
| L-01 | The scanner is **textual**, not AST-based. Comments and string literals are stripped (defeating the real false positives in this repo), but a construction via type alias, reflection, or a generic factory would go undetected. | Small, given Dart's static nature and this codebase's plain constructor style. An `analyzer`-package custom lint would close it; not built here to avoid a dev dependency and significant machinery for a pattern the codebase does not use. |
| L-02 | `HomeScreen`'s shared-activation-manager binding is certified **structurally**, not by object identity. | Weaker than an identity assertion; fails loudly if the binding is removed or inverted. See G-07 rationale and `ARCHITECTURAL_INTEGRITY_CERTIFICATION.md` §Known Limitations. |
| L-03 | Allowlists require deliberate maintenance on legitimate architectural change. | Intentional friction — it converts silent drift into an explicit, reviewable decision. |
| L-04 | Dynamic certification does not drive a full end-to-end Experience open. | Covered by R45's own suite rather than duplicated. |

## Closed by R46

| Previously-open item | Now |
|---|---|
| "Every production entry path flows through one pipeline" was prose, verified by hand-run grep | **Mechanically certified** every run (I-02, I-16, I-17), and **proven to fail** via mutation test |
| "Exactly one AI boundary" was prose | **Mechanically certified** (I-18, I-19, I-20) with the honest four-site distinction |
| "Kaalka/WebWeaveX stay behind their adapters" was prose in two architecture docs | **Mechanically certified** (I-21a/b/c) |
| No repository-wide invariant enforcement existed at all | 37 certification tests, ~1.2 s total cost |
