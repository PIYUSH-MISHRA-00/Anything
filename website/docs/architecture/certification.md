# Certification

**102 invariants run on every commit.** Each was *mutation-proven*: the thing it
protects was deliberately broken, and the test confirmed to fail **for the right
reason**.

This is the single best reason this codebase is safe to contribute to. You do
not need to hold the system in your head — a test will tell you if you break an
architectural rule, and it will name your file.

## What they enforce

| Invariant | Enforces |
|---|---|
| I-02 / I-16 / I-17 | Exactly one construction path for the Experience host screen |
| I-21a to I-21e | One Kaalka importer, one WebWeaveX importer; rejected capabilities stay rejected |
| I-49 | The governance engine imports nothing |
| I-50 | Exactly one trust model |
| I-59 / I-60 | One validator, one manifest |
| I-70 | Every commit-framework write runs in a transaction |
| I-87 / I-88 | One package format; the reader never installs or computes trust |
| I-90 | The execution contract declares and never decides |
| I-91 / I-92 | Nothing reaches the scheduler except through the orchestrator |
| **I-93** | **Every canonical framework has a real production consumer** |

## Why I-93 exists

It is the newest, and it exists because of a real failure.

Four consecutive milestones shipped correct, certified frameworks that
**nothing imported** — a package codec with zero importers, an installer read
only by tests. Every existing invariant passed the whole time, because they
certify *ownership* — that exactly one thing owns a concern — and none of them
asked whether that thing was reachable.

A gap stayed open for ten milestones behind that blind spot.

**A framework with no consumer is not architecture. It is inventory.**

## Mutation testing, and its failure mode

An invariant that has never been made to fail is a claim, not a check. But a
probe can also fail for the *wrong* reason — a compile error, a regex that still
matched — and a probe that fails for the wrong reason is indistinguishable from
an invariant that does not work.

Three milestones running, checking *why* a probe failed has caught a worthless
probe. That habit is now part of the
[contribution guide](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/CONTRIBUTING.md).

## Run it yourself

```bash
flutter test test/r46_architectural_integrity_certification_test.dart
```

Registry:
[ARCHITECTURE_INVARIANT_MATRIX.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/audit/ARCHITECTURE_INVARIANT_MATRIX.md)
and
[INVARIANT_TRACEABILITY.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/audit/INVARIANT_TRACEABILITY.md)
