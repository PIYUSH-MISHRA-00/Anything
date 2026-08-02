# Performance Guide

Real, measured numbers from this repository's own stress tests
(`test/world_model/stress_test.dart`) and profiling notes from earlier
milestones (`docs/progress/V2_ASAE_PERFORMANCE.md`,
`docs/progress/V2_KNOWLEDGE_PERFORMANCE.md`). Never a promised SLA —
these are observations from one machine, in one run, printed via
`Stopwatch` and reported honestly, including run-to-run variance.

## World Model at scale (1000 entities, 10000 relationships)

| Operation | Measured time |
|---|---|
| `GraphConsistency.validate` | ~18–26ms |
| `GraphTraversal.forward(maxDepth: 3)` | ~33–36ms (30 nodes reached) |
| `GraphMerge` of two identical 1000-node/5000-edge graphs | ~22–27ms |
| `WorldModelRepository.saveGraph` (SQLite, batched) | ~1.4–2.3s |
| `WorldModelRepository.loadGraph` (SQLite) | see stress test output |

`saveGraph` was originally ~5.7s using one `insert()` call per row
inside a transaction. Switching to `Batch` (`txn.batch()` +
`batch.insert(...)` + `await batch.commit(noResult: true)`) cut this by
roughly 3-4x. If you add a new bulk-write method to any repository in
this codebase, use `Batch`, not a per-row loop inside a transaction.

## SQLite

- `SqliteExperienceRepository` now ships two indexes
  (`idx_experiences_last_used`, `idx_experiences_category`) added via a
  real `onUpgrade` migration in Vision Milestone V10 — see
  `docs/architecture/RELEASE_CANDIDATE_HARDENING.md`.
- `WorldModelRepository`'s tables ship indexes on
  `world_graph_edges(from_id)`/`(to_id)` and
  `observation_records(experience_id)` from creation — added before any
  production data existed, so no migration was needed for them.
- All bulk writes anywhere in `lib/storage/` should go through
  `Database.batch()`, never a loop of individual `insert`/`update` calls
  inside a transaction — the perf gap between the two is large (see
  above) and grows with row count.
- `SqliteExperienceRepository.listAll()` orders by
  `last_used_at DESC, created_at DESC` — the new index directly serves
  this query's sort order.

## Graph traversal bounds

`GraphTraversal` (introduced in Vision Milestone V9) never revisits a
node and is bounded by `maxDepth` — it cannot return more nodes than
exist in the graph regardless of edge density. This was re-confirmed,
not re-designed, by the V10 stress test on a densely-connected
1000-node/10000-edge graph.

## Where to look next

If you're chasing a specific perf regression:
1. Reproduce it as a `Stopwatch`-timed test first (see
   `test/world_model/stress_test.dart` for the pattern) — a benchmark
   number without a reproducible test is not actionable.
2. Check whether the hot path does a per-row database call in a loop —
   that's the single highest-value fix pattern found in this codebase
   so far.
3. Check whether a graph traversal is missing a `maxDepth` bound.
