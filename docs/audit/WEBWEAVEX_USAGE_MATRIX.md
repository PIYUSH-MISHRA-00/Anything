# WebWeaveX Usage Matrix — IS-R46

Repository-wide audit of where `package:webweavex` (v3.0.0) is used, where
semantic acquisition **should** use it, and which of its capabilities remain
unused.

**WebWeaveX was not modified.** This is an audit, per the specification.

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
| Deterministic serialization | **NOT USED** | Was the Stage 5 plan for knowledge normalization/caching; deferred and never revisited |
| Runtime graph construction | **NOT USED** | No consumer; Anything builds its own World Model graph |
| Replay equivalence | **NOT USED** | Anything's determinism is proven by its own compiler-certification (R23) instead |
| Memory fabric | **NOT USED** | Anything has `EngineeringMemoryRepository` + `WorldModelCoordinator` |
| Kaalka v5 crypto (via WebWeaveX) | **NOT USED — deliberately** | Anything depends on `package:kaalka` directly through `KaalkaService`; routing crypto through WebWeaveX would create a **second** protection path and violate I-21a |
| Runtime normalization | **NOT USED** | No consumer identified |
| Workflow execution | **NOT USED** | Anything has its own `lib/workflow/` |
| Runtime reconstruction | **NOT USED** | No consumer identified |

## 4. Where semantic acquisition *should* use WebWeaveX but does not

Honest assessment. Each row states a real, cited gap — not a hypothetical.

| # | Opportunity | Current state | Assessment |
|---|---|---|---|
| W-1 | **Knowledge normalization / caching via deterministic serialization** | `KnowledgeAcquisitionEngine` re-acquires per Kernel call; `WebWeaveXAdapter` returns a fresh `KnowledgeResource` each time | The single most concrete unrealized integration, and it is the one the integration doc itself named and deferred at Stage 5. Would cut repeat network work and make knowledge inputs byte-reproducible — which matters because Anything's determinism story stops at the Kernel boundary today. **Recommended for a future milestone; explicitly NOT built in R46 (certification milestone).** |
| W-2 | Replay equivalence for knowledge acquisition | No replay of acquisition | Would strengthen determinism auditing, but R23's compiler certification already covers the generation path. Lower value than W-1. |
| W-3 | Runtime graph / memory fabric | Anything has its own World Model and Engineering Memory | **Should NOT adopt.** Adopting these would create a second graph and a second memory system — a direct violation of the "no parallel architecture" rule. Recorded here so the option is closed deliberately rather than left open. |
| W-4 | Kaalka v5 via WebWeaveX | Direct `package:kaalka` dependency | **Should NOT adopt.** Would create a second protection path and break I-21a. Closed deliberately. |

## 5. Certified constraints (from the integration doc, now mechanically enforced)

| Constraint | Enforcement |
|---|---|
| Only the adapter boundary imports WebWeaveX | I-21b — CERTIFIED |
| Kernel / UI / ExperienceSpec / ExecutionPlan do NOT import WebWeaveX | I-21c — CERTIFIED |
| WebWeaveX failure does not break Anything | pre-existing `KnowledgeAcquisitionEngine` behaviour (not newly certified) |
| No arbitrary code execution; source stays non-executable | pre-existing design |
| Local/private network retrieval blocked by default | pre-existing `HttpCapability` allowlist |

Before R46 the first two constraints were prose in a document. They are now
mechanically enforced on every test run.

## 6. Summary

WebWeaveX is **correctly bounded** and **genuinely used** for what Anything
actually needs today: HTML extraction, bounded fetch, and repository/document
IR. Its unused capabilities are mostly unused for good reason — adopting the
graph, memory, or crypto surfaces would create parallel architecture. The one
real, worthwhile unrealized integration is **W-1 (deterministic serialization
for knowledge normalization/caching)**, which the project itself planned and
deferred at Stage 5.
