# Runtime Limits — Anything v2.0.0

Every trusted resource/size/count boundary enforced against untrusted
generated Experience content. Centralized (where practical) in
`lib/security/runtime_security_limits.dart` as `RuntimeSecurityLimits`.
Two enforcement sites predate M2 and are deliberately left as the
independent source of truth rather than refactored to import the new
class (lower risk than touching already-tested, load-bearing constants
mid-milestone) — both are cross-referenced below.

These are v2 safety defaults, not claimed-optimal values. They may evolve.

| Constant | Value | Reason | Enforcement site | Test |
|---|---|---|---|---|
| `maxComponentDepth` | 20 | Bound recursive tree-walk cost and rendering depth | `ComponentTreeValidator._validateNode` (via `RuntimeComponentRegistry.maxDepth`) | `test/stage11/stage11_security_certification_test.dart` |
| `maxChildrenPerNode` | 50 | Bound per-node fan-out / layout cost | same | same |
| `maxTotalComponentsPerScreen` | 500 | Bound total widget construction per screen | same (`RuntimeComponentRegistry.maxTotalComponents`) | same |
| `maxScreensPerPackage` | 100 | Bound package size/parse cost from screen count alone | `ExperiencePackageValidator.validate` | `test/security/package_and_query_limits_test.dart` |
| `maxBehaviorNodesPerPackage` | 5000 | Bound declared graph size (independent of the *execution* budget below) | `ExperiencePackageValidator.validate` | `test/security/package_and_query_limits_test.dart` |
| `maxBehaviorNodesPerEvent` | 100 | Bound work done per dispatched event; also the de facto recursion-depth bound for `BehaviorInterpreter._executeNode` | `BehaviorInterpreter._maxNodesPerExecution` (private; documented here, not re-implemented) | `test/security/behavior_cycle_safety_test.dart` |
| `maxComponentPropertyTextLength` | 20,000 chars | Prevent a single property value smuggling a multi-MB string | `ComponentTreeValidator._validateNode` | `test/security/package_and_query_limits_test.dart` |
| `maxMetadataFieldLength` | 500 chars | Bound manifest name/description size | `ExperiencePackageValidator.validate` | `test/security/package_and_query_limits_test.dart` |
| `maxFetchRowsPerQuery` | 1000 (= `maxQueryResultLimit`) | Bound a single `ExperienceDataRuntime.query()` SQLite fetch regardless of table size — see "Search scalability" below | `ExperienceDatabase.query` / `ExperienceDataRuntime.query` | `test/security/package_and_query_limits_test.dart` |
| `maxQueryResultLimit` | 1000 | Bound rows returned after client-side filter/sort/paginate | `lib/runtime/data_query.dart` `DataQuery.maxResultLimit` (pre-existing, independent constant) | `test/stage11/stage11_security_certification_test.dart` |
| `maxQueryFilters` | 20 | Bound filter-evaluation cost per query | `DataQuery.maxFilters` | same |
| `maxQuerySorts` | 5 | Bound sort-comparator cost per query | `DataQuery.maxSorts` | same |
| `maxPackageBytes` | 5 MB | Reject an oversized package before any structural validation walk | `ExperiencePackageValidator.validate` (first check) | `test/security/package_and_query_limits_test.dart` (structural budgets exercise this indirectly; size check itself follows the same "reject before expensive work" pattern) |
| `maxHttpRedirects` | 5 | Bound redirect-following once a real transport exists (`HttpCapability` does not itself follow redirects today — see below) | Documented contract for a future `HttpTransport` implementation | — (no live redirect-following code yet) |
| `maxHttpConnectTimeout` / `maxHttpOverallTimeout` | 10s / 30s | Prevent indefinitely hanging requests | Documented contract; `HttpRequest.timeout` defaults to 30s today, not yet caller-overridable | — |
| `maxHttpRequestBytes` | 1 MB | Bound request body size | `HttpCapability.execute` | `test/security/http_capability_hardening_test.dart` |
| `maxHttpResponseBytes` | 5 MB | Bound response body size held in memory | `HttpCapability.execute` | `test/security/http_capability_hardening_test.dart` |
| `maxKnowledgeBytes` | 200 KB | General knowledge-bundle-level cap (distinct from the tighter per-prompt cap below) | Not yet enforced at the `KnowledgeBundle` level (retrieval is currently a stub — see `TRUST_BOUNDARIES.md`); documented for when real retrieval lands | — |
| (per-prompt knowledge cap) | 4000 chars | Bound knowledge text actually injected into one reasoning prompt | `ModelApplicationReasoner._maxKnowledgeContextSize` (pre-existing, independent constant in `lib/synthesis/model_reasoner.dart`) | covered by existing synthesis/reasoner tests |
| `maxFileBytes` | 10 MB (`RuntimeSecurityLimits`) / 5 MB (`FileCapability._defaultMaxFileSize`) | Bound adopted/picked file size; effective limit is `min(requested, trusted)` | `FileCapability._effectiveMaxSize` | `test/stage82`, `test/stage83`, `test/stage84` |
| `maxFileNameLength` | 255 | Bound filename length (filesystem-safe) | Documented; `FileCapability` returns opaque `FileReference`s so raw path/name handling is delegated to the (currently fake) `FileService` | — |
| `maxModelOutputBytes` | 2 MB | General cap on raw LLM response text before JSON extraction | Documented contract for `ModelApplicationReasoner`/provider layer | — |
| `maxAiPromptBytes` | 20,000 chars | Bound Experience-supplied prompt text | `AiCapability.execute` | `test/security/*` (AI capability hardening covered inline; see `ai_capability.dart`) |
| `maxAiResponseBytes` | 100,000 chars | Bound AI provider response text surfaced to an Experience | `AiCapability.execute` | same |

## Search scalability (documented limitation, not a defect)

`ExperienceQueryController.refresh()` fetches up to `maxFetchRowsPerQuery`
rows (ordered `created_at ASC`) from SQLite, then applies `DataQuery`
filter/sort/search/paginate in Dart over that fetched set. This means:

- A table with more rows than the fetch ceiling has its **oldest**
  `maxFetchRowsPerQuery` rows visible to search/filter/sort; newer rows
  beyond that window are invisible until older ones are removed or the
  ceiling is raised.
- This is a real, intentional trade-off for M2: the goal was resource
  safety (no unbounded SQLite fetch, no unbounded memory growth), not
  search completeness at scale. A generated Experience with more than
  1000 records of a single entity is not expected at v2.0.0 scope.
- A real indexed/paginated SQL search (e.g. `WHERE`-pushdown for filters,
  `LIKE`/FTS for search) is the correct fix and is out of scope for M2;
  tracked as a scalability item for a future milestone.

## HTTP redirect and timeout status (documented, not yet live)

`HttpCapability` does not itself follow HTTP redirects — a 3xx response
from the transport is returned to the caller unchanged. Combined with the
fact that no real `HttpTransport` implementation exists yet (see
`TRUST_BOUNDARIES.md`), there is no redirect-following code in production
today, so the "public URL redirects to a private IP" SSRF vector is not
currently exploitable. This is captured here as a hard requirement on
whoever implements a real transport: **it must not auto-follow redirects
internally**; `HttpCapability` must own manual redirect following,
re-running the full scheme/host/DNS validation against each hop's target,
bounded by `maxHttpRedirects`.

## Experience packages cannot raise any limit

Every limit above is enforced as `min(requested, trusted)` or an outright
rejection. No `ExperiencePackage` field, behavior node config, or
capability invocation parameter can increase a trusted constant — this
was spot-checked explicitly for `DataQuery.limit` (rejected, not clamped,
if over `maxQueryResultLimit`) and `FileCapability`'s `maxSizeBytes`
parameter (`test/stage83`: "Experience cannot raise trusted limit").
