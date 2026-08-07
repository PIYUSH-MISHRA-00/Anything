# ADR — IS-R56: One owner for durable-collection read-modify-write

**Status:** Accepted · **Date:** 2026-08-07 · **Supersedes:** nothing ·
**Milestone:** IS-R56

## Context

IS-R56 was specified as an audit-first milestone: nothing preselected,
repository evidence overriding the specification, and an explicit instruction
to implement a different owner if the audit proved the anticipated one wrong.

It did.

## Decision 1 — Abandon the milestone's own title

**The specification is titled "Canonical Runtime Import Framework".** The audit
found:

- `AnythingRuntime` is constructed in **exactly one** place
  (`experience_host_screen.dart:205`) — runtime creation is already singular.
- Import ownership was settled by R53 (distribution) and R54 (installation),
  both certified.

There was no duplicated runtime-import ownership to canonicalise. Building one
would have been a speculative abstraction over an already-singular concern —
the exact failure mode the mandatory rules forbid.

**Decision:** implement what the evidence showed instead, per the
specification's own first principle.

## Decision 2 — The owner is the critical section, not the storage

Three collections duplicated a read-modify-write pattern, and one was
**measurably** losing data.

The tempting response is a "durable collection repository" that owns storage
for all three. **Rejected.** Each collection has genuinely different semantics —
notification scheduling and delivery, activity history, intent history — and
merging them would create a God object and destroy three well-scoped types.

**Decision:** `DurableCollectionStore` owns *only* the serialised
read-modify-write. Each repository keeps its own types, JSON and semantics. The
store knows nothing about what any collection means.

This is the same shape as R50 (retention: policy moved, storage stayed) and R55
(commit: persistence moved, semantics stayed).

## Decision 3 — Remove the yield rather than add a lock

**Superseded design, recorded because it shipped in review and failed.**

The first implementation serialised callers through a **static per-key future
chain**, with an async mutation callback. Rationale at the time: the resource
is process-wide, so the lock must be, and `ActivityRepository` alone is
constructed in nine places, so per-instance locking would protect nothing.

**It deadlocked.** `flutter_test` disposes a zone between tests, and a chain
entry left by one test was awaited forever by the next — widget tests that
record activity hung, and a 14-test file ran past ten minutes instead of five
seconds. The full suite went from 2 minutes to 12 with eleven failures.

The diagnosis mattered more than the fix: **the lock was needed only because
the async callback reintroduced the very yield the lock existed to survive.**

**Decision:** make the mutation callback *synchronous* and perform read, mutate
and write with no `await` between them. Dart is single-threaded, so with no
yield point inside the critical section concurrent callers cannot interleave.

Consequences:
- No lock, no static state, no cross-zone futures, no deadlock.
- The guarantee is enforced by the **type system** — an async mutation does not
  compile — rather than by a convention.
- The store is stateless and `const`-constructible, so existing `const`
  call sites are untouched.
- Measured: twenty concurrent mutations of one key all apply; ten concurrent
  `schedule()` calls all survive.

**Cost accepted:** work that must await has to sit on either side of the
critical section. `deliverDue` is exactly that shape — claim inside, present
outside — which is the correct structure anyway (Decision 4).

## Decision 4 — Claim before present (at-most-once over at-least-once)

`deliverDue` presented and *then* persisted. Two concurrent callers delivered
the same notification twice.

Two possible orderings:

| Ordering | Failure mode |
|---|---|
| present → persist (R49) | **duplicate delivery** under concurrency |
| claim → present (R56) | **missed delivery** if the process dies between them |

**Decision:** claim first.

The method's documented contract is *exactly once*. Neither ordering achieves
that alone, but a duplicate alarm is worse than a missed one, and the previous
behaviour was neither correct nor safe. Recorded honestly as **G-38** rather
than presented as a full solution. A durable claim → present → confirm cycle
would close it; it is not built because nothing yet demonstrates at-most-once is
too weak.

## Decision 5 — Route activity and intent through the store anyway

The probe **disproved** the hypothesis that all three were losing writes:
activity stored all ten concurrent records.

**Decision:** route them through the store regardless — but claim a proven
defect *only* for notifications.

Rationale: the code shape is identical, the surviving ordering is an accident
nothing asserts, and leaving two copies of a pattern whose third copy was
demonstrably broken is exactly the "duplicate implementation" the specification
asks to eliminate. What is *not* acceptable is claiming they were broken.

## Decision 6 — Delete rather than deprecate

`lib/storage/local_database.dart` had zero references and duplicated live theme
persistence.

**Decision:** delete, following R47's precedent (G-01). Deprecation markers on
code nothing references are debt with a comment attached.

## Decision 7 — Correct a false-negative invariant rather than keep it green

I-77's first form (`indexOf(present) > lastIndexOf(store.update)`) **passed**
against the probe that reintroduced the defect.

**Decision:** rewrite it as a containment check over balanced-parenthesis call
ranges, and record the failure in the certification document rather than quietly
fixing it.

The rule "never weaken an invariant to make tests pass" has a corollary this
milestone exercised: **never keep an invariant that passes for the wrong
reason.**

## Consequences

**Positive**
- A measured data-loss defect and a measured double-delivery defect are fixed,
  with the before/after numbers preserved as permanent tests.
- A silent truncation bug (intents past 50) fixed as a side effect of
  consolidation.
- One fewer dead file; one fewer duplicated pattern.
- Three new invariants, all mutation-proven.

**Negative / accepted**
- Static mutable lock state (justified above).
- At-most-once delivery (G-38).
- Serialisation is per key, not cross-key — no transaction across two
  collections. Nothing needs it; sibling of G-35.
- `ActivityRepository` still has no composition owner (G-37) — deliberately out
  of scope, recommended as the next milestone.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| A mutex package from pub | New dependency for ~20 lines of standard Future-chaining. |
| Move all three collections to SQLite | A persistence redesign, forbidden, and unnecessary — the defect is missing serialisation, not the wrong backend. |
| Fix only `RealNotificationService` | Leaves two copies of a pattern whose third copy was proven broken. |
| A generic `Repository<T>` base class | An abstraction over three types with genuinely different semantics; speculative, and would obscure rather than clarify ownership. |
| Keep present→persist and dedupe on the presenter side | Pushes a correctness obligation onto every future presenter; the defect belongs where the ordering is. |
