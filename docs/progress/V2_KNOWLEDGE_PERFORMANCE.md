# Knowledge Pipeline Performance — Vision Milestone V1

Measured 2026-08-01 via `test/knowledge/performance_test.dart`, run
against real network (target: `https://example.com/`, IANA-reserved for
documentation/testing — stable and tiny, chosen specifically so these
numbers aren't dominated by an arbitrary third-party page's size).

These are **not** a formal benchmark suite (no fixed hardware, no
repeated-trial statistics) — they are a single real, timed run recorded as
evidence that the pipeline is fast enough not to be a product concern at
this milestone's scope, per the "measure and document" requirement. No
regression thresholds are asserted in CI, since a network-latency-based
pass/fail would be inherently flaky.

| Stage | Measured | Notes |
|---|---|---|
| Retrieval (cache miss) | ~107 ms | One `SearchProvider` call (stubbed to a fixed URL for this measurement, isolating extraction cost) + one real `wwx.renderPage` HTTP GET + real `extractSemanticHtml`/`extractSemanticContent` HTML parse |
| Retrieval (cache hit) | ~1 ms | In-memory `KnowledgeCacheKey` lookup, no network |
| Deterministic reasoning + blueprint + package synthesis | ~21 ms | `DeterministicReasoner.reason()` → `SynthesisPlanner.convertToBlueprint()` → `GenericPackageBuilder.build()`, no network, no model call |

## Interpretation

- Cache hit is ~100x faster than a fresh fetch, as expected for an
  in-memory lookup vs. a real HTTP round-trip — confirms caching is
  actually load-bearing, not decorative.
- Synthesis (reasoning → blueprint → package) is dominated by in-process
  computation, not I/O, and is fast regardless of knowledge acquisition
  cost.
- A real `DuckDuckGoSearchProvider` search adds one additional HTTP
  round-trip on top of the extraction fetch (not isolated in this
  measurement, which stubs search to isolate extraction cost); expect
  roughly double the cache-miss latency (~200-300ms) for the full
  production path with real search, still well within interactive
  latency for a one-time app-creation flow.
- Numbers will vary with target page size/latency and network conditions;
  treat these as an order-of-magnitude sanity check, not a guarantee.

## Where this fits in the budget model

Knowledge acquisition happens at most `_maxKnowledgeRounds + 1` = 3 times
per intent (see `AnythingKernel._reasonWithKnowledgeLoop`), each acquiring
at most a handful of requirements' worth of queries — the pipeline is
bounded by the same trusted limits documented in
`docs/security/RUNTIME_LIMITS.md`, so worst-case latency is bounded by
design, not just by observation.
