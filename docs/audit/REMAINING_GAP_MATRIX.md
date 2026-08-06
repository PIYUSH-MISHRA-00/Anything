# Remaining Gap Matrix — IS-R46

Everything the R46 repository-wide audit surfaced that is **not** resolved.
Each row cites real evidence. Nothing here is hypothetical, and nothing here
was fixed inside R46 — this is a certification milestone with an explicit
stop condition.

Severity: **A** = architectural integrity, **B** = correctness/UX,
**C** = hygiene.

## Open gaps

| # | Sev | Gap | Evidence | Why not fixed in R46 |
|---|---|---|---|---|
| G-01 | A | **Dead, name-colliding v1 runtime contract.** `lib/core/contracts/runtime.dart` declares `abstract class AnythingRuntime`, colliding with the live `lib/runtime/anything_runtime.dart`. Shapes differ entirely (`openExperience(ExperienceId)` vs `openExperience(ExperiencePackage)`). | Zero importers and zero implementors in `lib/` **or** `test/` (certified I-15). | Deleting production files is outside a certification milestone's scope. Held stable by certification; deletion recommended for R47. |
| G-02 | C | **`MinimalKernel` is dead.** `lib/kernel/minimal_kernel.dart` declares it; nothing constructs it. | Repository-wide construction scan: 1 occurrence, its own declaration. | Same as G-01. Not currently certified, because it does not collide with a canonical name. |
| G-03 | A | **Two production `Fake*` services are registered in the real composition.** `AppComposition` lines 229–230 register `FakeNotificationService()` and `FakeFileService()`. | `lib/app/app_composition.dart:229-230`. | These are real product gaps (notifications and file access are genuinely unimplemented), not architectural violations. Fixing them is feature work, not certification. |
| G-04 | A | **`EncryptionManager` bypasses the `ProtectionProvider` contract** (path K-B), reaching `KaalkaService` directly. | `security/encryption_manager.dart:40,45`; consumers `memory/memory_manager.dart`, `screens/kaalka_security_screen.dart`. | Collapsing it into the canonical contract is a real architectural change requiring review. Does **not** violate I-21a — there is still exactly one crypto importer. See `KAALKA_USAGE_MATRIX.md` §2. |
| G-05 | B | **`savePackage()` stores Experience packages in plaintext by default.** Kaalka protection is opt-in per Experience. | `storage/sqlite_experience_repository.dart:172` vs `:292`. | Confirmed deliberate product design, cited in three places in `lib/`. Restated because "Kaalka is canonical" is easily misread as "everything is encrypted". Not a defect; a disclosure. |
| G-06 | B | **`IntentRepository` stores raw user intent text unprotected.** User-authored natural language can be sensitive. | Persistence audit, `KAALKA_USAGE_MATRIX.md` §3. | Product/security decision, out of certification scope. Worth explicit review. |
| G-07 | B | **Stale R44 comment in canonical source.** `lib/app/experience_activation_manager.dart:16-18` still claims `HomeScreen` is "the ONE and ONLY real production call site that ever pushes `ExperienceHostScreen` ... (confirmed by grep)". That was never true. | Carried from R45, where it was left byte-identical to keep the unchanged-subsystem proof mechanical. | R46 changes nothing in `lib/`. The claim is now mechanically **true** and enforced (I-16), so the comment can be corrected safely in R47. |
| G-08 | B | **`HomeScreen` submit-button reactivity gap.** `TextField.onChanged` never calls `setState()`, so the submit/voice icon does not rebuild from typed input alone. | Found during R45, carried forward. | Unrelated to certification. |
| G-09 | C | **`FakeKnowledgeProvider` lives in production `lib/`.** | `capabilities/builtin/knowledge_capability.dart:12`. Verified **not** wired in production — `AppComposition:220` wires the real `KnowledgeAcquisitionProviderAdapter`. | Harmless test double in the wrong directory. Hygiene only. |
| G-10 | C | **WebWeaveX deterministic serialization unused** for knowledge normalization/caching — the integration the project itself planned at Stage 5 and deferred. | `WEBWEAVEX_USAGE_MATRIX.md` §4 (W-1). | Real feature work, not certification. The most worthwhile unrealized WebWeaveX integration. |

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
