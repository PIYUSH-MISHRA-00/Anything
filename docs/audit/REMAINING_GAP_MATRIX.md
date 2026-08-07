# Remaining Gap Matrix — IS-R46, updated through IS-R54

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

## CLOSED BY IS-R49

| # | Gap | How it was closed |
|---|---|---|
| G-03 | Two production `Fake*` services registered in the real composition | **CLOSED.** `FakeNotificationService` → `RealNotificationService` (durable schedules, real ownership, real due computation, real foreground delivery on the existing `EventBus` via R35's `NotificationGenerated`). `FakeFileService` → `RealFileService` (real picking via the already-present `file_picker`, real sandboxed adoption/export/temp/workspace assets via `path_provider` + `dart:io`). No `Fake*` is constructed in the composition root any more (I-39), mutation-proven. |

## CLOSED BY IS-R50

| # | Gap | How it was closed |
|---|---|---|
| G-18 | Persisted knowledge had no retention policy — unbounded growth | **CLOSED.** `RetentionPolicyEngine` now owns it: 500 entries / 20 MB / 30 days. `KnowledgeCache.applyRetention()` asks the engine and tells `KnowledgeRepository` which keys to drop; the repository still owns no policy (I-47). R48 deliberately did not invent a policy because none existed to reuse — R50 created the canonical owner first, then applied it. |
| G-22 | Retention was invented independently three times with three magic numbers (`_maxRecords=100`, `_maxEvents=200`, `maxScheduled=200`) | **CLOSED.** All three delegate to the ONE engine. Values unchanged — three tests assert 100/200/200 exactly, so ownership moved without behaviour moving. No repository or capability service may hold a retention rule any more (I-46), mutation-proven. |

## CLOSED BY IS-R54

| # | Gap | How it was closed |
|---|---|---|
| G-27 (part) | R53's `dependencies` were transported and resolved by nothing | **PARTIALLY CLOSED.** `ExperienceDependencyPlanner` is the field's first reader: an import declaring a dependency that is not installed is now REFUSED, tested. The other half of G-27 (protection state transported but not restored) remains open and deliberate — see below. Nothing fetches a dependency, and nothing can: that is G-31. |

## OPENED BY IS-R54 — recorded at the moment they were created

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-28 | **A** | **The installation transaction is COMPENSATING, not atomic.** It snapshots prior state at `prepare`, writes at `commit`, and restores the snapshot on failure. If the process dies BETWEEN the two writes, the snapshot dies with it and nothing is left to call `rollback()`. | `InstallationTransaction`; `SqliteExperienceRepository.savePackage`/`saveMetadata` are separate `INSERT … ConflictAlgorithm.replace` calls and `db.transaction` is not exposed. | **Open, and structurally forced.** IS-R54 Task 5 says "Repository unchanged" and Task 12 forbids a persistence migration, so one real SQL transaction was not available. This is exactly why `repair()` exists and why it is tested against the torn state a crash produces. Closing it properly means exposing a transaction on the repository — a real change to a canonical type, correctly deferred to a milestone that is allowed to make it. |
| G-29 | B | **`currentRuntimeVersion` is hand-maintained and can silently drift from `pubspec.yaml`,** which still reads `1.0.0+1` while the branch is v2.0.0. | `ExperienceCompatibilityEvaluator.currentRuntimeVersion = '2.0.0'`. | **Open, deliberately.** Reading the pubspec at runtime needs `package_info_plus`; IS-R54 adds no dependency. It is declared in exactly ONE place and every entry point takes an override, so the blast radius is one line — but nothing mechanically ties it to the pubspec, and a compatibility check against a wrong runtime version is worse than none. Worth a build-time generated constant. |
| G-30 | **A** | **Committing is NOT unified.** Four sites still write to the repository directly: creation (`creation_coordinator.dart:442`), modification (`experience_modification_coordinator.dart:136, 295, 379`), evolution (`evolution_coordinator.dart:79`) and protection (`protection_service.dart:289`). | Repository-wide `savePackage` scan. | **Open, deliberately and explicitly.** R54 established the owner and moved the ONE path Task 8 names (distribution). Rerouting four coordinators — each with genuinely different pre-conditions — would be replacing architecture, which this milestone's rules forbid. Stated rather than implied, because "there is now one installer" reads as "everything installs through it" and that is false. |
| G-31 | C | **Dependencies are planned but can never be fetched.** A package declaring an uninstalled dependency is simply refused; nothing can supply it. | `ExperienceDependencyPlanner` — no networking, by instruction (Task 4 is architecture only). | **Open by design.** There is no transport for a dependency to arrive on. Refusing is the correct conservative behaviour until one exists. |
| G-32 | C | **Platform compatibility is not actually checked.** `IncompatibilityReason.platformUnsupported` exists and is never emitted. | `ExperienceCompatibilityEvaluator.evaluate`. | **Open, deliberately.** `NetworkMode`/`StorageMode` exist on the manifest, but no device policy exists to check them against. Inventing one would be a fabricated check that looks like enforcement. The reason code is declared so the vocabulary does not need widening later; that it is unused is recorded here rather than left for someone to discover. |

## Gaps IS-R54 found and closed within the same milestone

| # | What happened |
|---|---|
| G-33 | **`experiencePackageVersion` was declared TWICE** — `experience_package.dart:10` and `package_validator.dart:221`, both `const int = 1`, independent. The validator's local declaration shadowed the canonical one, so bumping the package-format version in one place would have left the validator silently enforcing the other. Invisible for as long as nothing imported both libraries; the new installer does, and could not compile (`ambiguous_import`). **The ANALYZER caught it — the fifth time across R46–R54 that something other than the certification layer found the real defect.** Fixed by deleting the duplicate; no consumer imported it from there. |

## OPENED BY IS-R53 — recorded at the moment they were created

| # | Sev | Gap | Evidence | Status |
|---|---|---|---|---|
| G-25 | **A** | **A user still cannot import an Experience.** R53 built a complete, end-to-end-tested distribution pipeline — but it moves `ExperienceDistributionPackage` *objects* and serialises them to JSON. There is no `.anything` file format, no file read or write, no zip, no share-sheet integration. | `lib/app/experience_distribution.dart` — no `dart:io`, no `FileService`, no `RealFileService` reference anywhere in the file. | **Open, deliberately and explicitly.** Stated first in every R53 document, because a working pipeline reads as a shipped feature and it is not one. The pieces exist: `RealFileService` (R49) owns file I/O and `file_picker` is already a dependency. Deferred so this milestone established ownership boundaries before adding a file layer on top of them. |
| G-26 | B | **Nothing verifies publisher signatures, so nothing is ever `verified`.** `MarketplaceMetadata.publisherSignature` is transported and never checked. Every channel — including `marketplace` and `enterprise` — yields `VerificationState.unverified` and classifies as `imported`. | `provenanceFor()`; asserted for all five channels in `test/r53_experience_distribution_test.dart`. | **Open by design, not by omission.** Assigning `verified` because a signature *field* was present is precisely the "assumed rather than computed" failure R52 removed. The honest state is recorded in the data rather than hidden. A real verifier needs a key-distribution decision that is a product question, not an implementation one. |
| G-27 | C | **Protection state is transported but never restored; `dependencies` is transported but never resolved.** An imported Experience is persisted with `isProtected: false` even when the envelope says the source was protected. | `import()`; `ExperienceDistributionManifest.dependencies`. | **Open, deliberately.** Distribution must not fabricate a protected state it cannot honour — the Kaalka ciphertext envelope is not transported, and `ExperienceProtectionService` remains the sole owner of protection. An imported Experience must be re-protected on the receiving device. `dependencies` is declared so the envelope format needs no version bump when dependency resolution arrives. |

## Gaps IS-R50 found and closed within the same milestone

| # | What happened |
|---|---|
| G-23 | **R50 broke a caller of R49's own API.** Removing `RealNotificationService.maxScheduled` invalidated R49's test, which constructed the service with `maxScheduled: 3`. No certification invariant caught it — static checks verify architectural shape, not API compatibility. The **analyzer baseline** caught it, moving 71 → 72 with an `undefined_named_parameter`. The test was migrated to express the same bound as a retention policy; its assertions are unchanged. Fourth time across R46–R50 that something other than the certification layer caught the real defect. |
| G-24 | **An observed, non-reproducing test failure, recorded rather than buried.** One full-suite run reported `r43_workspace_experience_switcher_test.dart` failing with `type 'CreationFailed' is not a subtype of type 'CreationCreated'` — a Kernel creation failure, in the same run that carried the broken R49 test file. It did **not** reproduce: the file passed 14/14 in isolation, and the subsequent clean full run passed 1878/1878. Reported because "it passed the second time" is not the same as "it never failed", and a future recurrence should find this note rather than start from zero. |

## Gaps IS-R49 found and closed within the same milestone

| # | What happened |
|---|---|
| G-21 | **A file id could carry `..`.** `_idFor()` collapsed non-`[A-Za-z0-9._-]` to `_`, which removes path separators — but `.` is in that safe set, so a display name of `../../evil` survived as `.._.._evil`. The path was still *contained* (one segment, so `p.normalize` does not treat it as traversal, and `_resolveInside` would reject it regardless), but an id carrying `..` is a latent hazard the moment any future code joins it with a non-normalising API. Found by a test asserting the stronger property; fixed by collapsing runs of dots rather than by weakening the assertion. |

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
| G-20 | B | **OS-level BACKGROUND notification delivery is not implemented.** `RealNotificationService` schedules durably, computes due state and delivers in-app (foreground) through the existing `EventBus`. A notification that fires while Anything is not running still requires a platform plugin (`flutter_local_notifications` + timezone database, Android manifest permissions/receivers, iOS `AppDelegate` registration, a notification icon asset). | `lib/capabilities/adapters/notification_service_adapter.dart`. | **Open, deliberately and explicitly.** None of that native configuration can be exercised by `flutter test` (no platform channels) and no device or emulator is available in this environment. Shipping it unverified would LOOK complete while silently never delivering — strictly worse than a documented gap. `background_coordinator.dart` already drew this exact line in its own words ("never fabricating live execution"). The seam is singular and named: `NotificationPresenter`. **R50 should implement it and verify on a real device.** |
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
