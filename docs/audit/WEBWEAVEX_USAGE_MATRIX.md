# WebWeaveX Usage Matrix — IS-R46, updated by IS-R47

Repository-wide audit of where `package:webweavex` (v3.0.0) is used, where
semantic acquisition **should** use it, and which of its capabilities remain
unused.

**WebWeaveX itself was not modified.** R46 was an audit; R47 consumed one
further already-published capability through the existing adapter.

## IS-R47 CHANGE — W-1 is now IMPLEMENTED

The R46 audit named exactly one worthwhile unrealized integration:
**deterministic serialization for knowledge normalization** (W-1), which the
project itself planned at Stage 5 and deferred. IS-R47 Task 4 implemented it.

**What was wrong, concretely.** `WebWeaveXAdapter.extract()` hashed and cached
content exactly as the page served it, and stamped each resource with
`id: 'wwx-${now.microsecondsSinceEpoch}'`. Two real consequences:

1. The same page acquired twice produced **different ids** — no two
   acquisitions were ever comparable.
2. Byte-different but canonically **equivalent** content (CRLF vs LF, NFC vs
   NFD, trailing whitespace) produced **different `contentHash`** values.
   `KnowledgeAcquisitionEngine._deduplicate()` keys on exactly that hash, so
   genuinely duplicate knowledge survived deduplication and was handed to the
   reasoner twice.

**What R47 did.** Extraction now runs through WebWeaveX's own
`normalizeRuntimeValue` (NFKC + CRLF→LF + trailing-whitespace strip) before
hashing, and resource identity is derived from `stableSerialize` over the
identity-bearing fields instead of a wall clock. `KnowledgeAcquisitionEngine`
additionally canonicalizes its cache-key queries through the same normalizer.

**What R47 did NOT do**, per the Task 4 rules: no bespoke normalizer, no
second serializer, no second cache layer (the existing `KnowledgeCache` is
untouched and simply receives canonical input), no second knowledge engine,
no duplicate normalization pipeline. WebWeaveX types still stop at the
adapter — the engine reaches normalization via
`WebWeaveXAdapter.normalizeText()`, never by importing the package. Certified
by invariant **I-21d**.

**Deliberately excluded from the canonical form:** `retrievedAt`, `id`, and
the trust/ranking metadata. Those record *when* a fetch happened and *how it
was judged*, not *what was fetched*; including them would defeat the entire
purpose. Provenance stays truthful — two acquisitions still carry their real,
different timestamps — while their canonical representations are identical.

## 1. Where it is imported — certified

Exactly four files in `lib/` import `package:webweavex` (certified I-21b;
the Kernel and all UI are certified never to, I-21c):

| File | Purpose | WebWeaveX primitives used |
|---|---|---|
| `knowledge/webweavex_adapter.dart` | URL → `KnowledgeResource` | `renderPage`, `extractSemanticHtml`, `extractSemanticContent` (Soup engine) |
| `software_cognition/repository_analyzer.dart` | repository IR | `compileRepository`, `queryRepository` |
| `software_cognition/package_analyzer.dart` | dependency analysis | `compileDocument`, `Soup` |
| `software_cognition/component_analyzer.dart` | component/API analysis | `analyze`, `Soup` |

## 2. Where semantic acquisition actually flows through it

| Consumer | Path | Real? |
|---|---|---|
| `AnythingKernel.processIntent()` | `_knowledgeEngine.acquire()` ×2 (`anything_kernel.dart:771`, `:796`) → `SearchProvider` → `WebWeaveXAdapter` | YES — real, production-wired |
| `SoftwareCognitionCoordinator` | the three analyzers above | YES — real (Vision Milestone V11) |
| `KnowledgeCapability` (Experience-facing) | `KnowledgeAcquisitionProviderAdapter(knowledgeEngine)` | YES — production composition wires the **real** engine |

**Verified, not assumed:** `AppComposition` line 214 constructs
`KnowledgeAcquisitionEngine(searchProvider: DuckDuckGoSearchProvider(), webweavexAdapter: WebWeaveXAdapter())`
and line 220 registers
`KnowledgeCapability(provider: KnowledgeAcquisitionProviderAdapter(knowledgeEngine))`.
The real WebWeaveX path is genuinely live in production — no fake is
substituted here.

Note: `FakeKnowledgeProvider` exists in `lib/capabilities/builtin/knowledge_capability.dart`
but is **not** wired in production. It is a test double that happens to live
in `lib/`. Flagged in `REMAINING_GAP_MATRIX.md` as a hygiene item only.

## 3. Documented WebWeaveX capabilities — utilization

From `docs/architecture/WEBWEAVEX_INTEGRATION.md`'s own capability list:

| Capability | Used? | Where / why not |
|---|---|---|
| HTML extraction (Soup / bs4 parity) | **USED** | `webweavex_adapter.dart`, `package_analyzer.dart`, `component_analyzer.dart` |
| Bounded HTTP fetch (`renderPage`) | **USED** | `webweavex_adapter.dart` |
| Repository analysis | **USED** | `repository_analyzer.dart` (V11) |
| Document IR (`compileDocument`) | **USED** | `package_analyzer.dart` |
| Deterministic serialization (`stableSerialize`) | **USED (IS-R47)** | `webweavex_adapter.dart` — resource identity + canonical representation |
| Runtime normalization (`normalizeRuntimeValue`) | **USED (IS-R47)** | `webweavex_adapter.dart` — content/title normalization and, via `normalizeText()`, cache-key queries |
| Runtime graph construction | **NOT USED** | No consumer; Anything builds its own World Model graph |
| Replay equivalence | **NOT USED** | Anything's determinism is proven by its own compiler-certification (R23) instead |
| Memory fabric | **NOT USED** | Anything has `EngineeringMemoryRepository` + `WorldModelCoordinator` |
| Kaalka v5 crypto (via WebWeaveX) | **NOT USED — deliberately, now ENFORCED** | Anything depends on `package:kaalka` directly through `KaalkaService`; routing crypto through WebWeaveX would create a **second** protection path and violate I-21a. Closed by I-21e. |
| Workflow execution | **NOT USED — deliberately, now ENFORCED** | Anything has its own `lib/workflow/`. Closed by I-21e. |
| Runtime reconstruction | **NOT USED** | No consumer identified |

## 4. Where semantic acquisition *should* use WebWeaveX but does not

Honest assessment. Each row states a real, cited gap — not a hypothetical.

| # | Opportunity | Current state | Assessment |
|---|---|---|---|
| W-1 | **Knowledge normalization via deterministic serialization** | **DONE — IS-R47 Task 4.** Content and titles normalized via `normalizeRuntimeValue`; identity and canonical representation via `stableSerialize`; cache keys canonicalized through the adapter. | **CLOSED.** Repeated acquisitions now produce byte-identical normalized representations, and canonically-equivalent duplicates actually deduplicate — which they previously did not. Certified by I-21d and 15 behavioural tests in `test/r47_deterministic_knowledge_normalization_test.dart`. |
| W-2 | Replay equivalence for knowledge acquisition | No replay of acquisition | Would strengthen determinism auditing, but R23's compiler certification already covers the generation path. Still open, still lower value than W-1 was. |
| W-3 | Runtime graph / memory fabric | Anything has its own World Model and Engineering Memory | **Should NOT adopt** — would create a second graph and a second memory system, a direct "no parallel architecture" violation. Closed deliberately in R46; **now mechanically enforced** by I-21e. |
| W-4 | Kaalka v5 via WebWeaveX | Direct `package:kaalka` dependency | **Should NOT adopt** — would create a second protection path and break I-21a. Closed deliberately in R46; **now mechanically enforced** by I-21e. |
| W-5 | Cross-restart knowledge persistence | `KnowledgeCache` is in-memory and process-scoped | Unchanged by R47 and out of its scope. Now that cache keys and resource identities are canonical, a persistent cache would be a straightforward follow-on — R47 removed the blocker (non-deterministic ids) rather than the feature gap itself. |

## 5. Certified constraints (from the integration doc, now mechanically enforced)

| Constraint | Enforcement |
|---|---|
| Only the adapter boundary imports WebWeaveX | I-21b — CERTIFIED |
| Kernel / UI / ExperienceSpec / ExecutionPlan do NOT import WebWeaveX | I-21c — CERTIFIED |
| Deterministic serialization reached only via the adapter | I-21d — CERTIFIED (IS-R47) |
| Closed surfaces (graph, memory, workflow, crypto) stay closed | I-21e — CERTIFIED (IS-R47) |
| WebWeaveX failure does not break Anything | pre-existing `KnowledgeAcquisitionEngine` behaviour (not newly certified) |
| No arbitrary code execution; source stays non-executable | pre-existing design |
| Local/private network retrieval blocked by default | pre-existing `HttpCapability` allowlist |

Before R46 the first two constraints were prose in a document. They are now
mechanically enforced on every test run.

## 6. Summary

WebWeaveX is **correctly bounded** and **genuinely used** for what Anything
actually needs: HTML extraction, bounded fetch, repository/document IR, and —
since IS-R47 — deterministic normalization and serialization.

The one real, worthwhile unrealized integration R46 identified (**W-1**) is
now **closed**. The remaining unused capabilities are unused for good reason:
adopting the graph, memory, workflow or crypto surfaces would create parallel
architecture, and those four are no longer merely documented as closed — they
are mechanically enforced by I-21e, so a future change cannot quietly open
one.

Adoption count: **6 WebWeaveX capabilities used** (HTML extraction, bounded
fetch, repository analysis, document IR, deterministic serialization, runtime
normalization), up from 4 at R46; **4 deliberately closed and enforced**;
2 unused with no identified consumer.
