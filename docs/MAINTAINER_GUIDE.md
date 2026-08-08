# Maintainer Guide

For people with merge rights. Contributors want [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## Governance

**Model:** BDFL-with-delegation. `@PIYUSH-MISHRA-00` is the project lead and
final decision-maker on architecture, scope and releases.

This is honest rather than aspirational: the project has one maintainer today,
and pretending otherwise would set expectations the project cannot meet. The
ladder below exists so that changes as the community grows.

### Contributor ladder

| Level | How you get there | What you can do |
|---|---|---|
| **Contributor** | Land one PR | Everything in CONTRIBUTING |
| **Reviewer** | 5+ meaningful PRs, or sustained review help | Requested on reviews; approval counts |
| **Maintainer** | Sustained reviewing, invited by the lead | Merge rights on non-load-bearing paths |
| **Lead** | — | Architecture, releases, CODEOWNERS, licensing |

Advancement is by invitation, and is recorded in a PR editing
[CODEOWNERS](../.github/CODEOWNERS) so it is visible.

### Load-bearing paths

Never merge these without lead review, regardless of who approves:

- `test/r46_architectural_integrity_certification_test.dart` — a change here can
  silently weaken all 102 invariants
- `tool/analyze_gate.sh` — the baseline gate
- `.github/workflows/` — the checks themselves
- `android/` — signing, permissions, R8; decides whether the product ships
- `lib/app/app_composition.dart` — the composition root
- `lib/security/`, `lib/knowledge/webweavex_adapter.dart` — external boundaries
- `LICENSE`

## Reviewing a PR

Beyond "does it work":

1. **Does it create a second owner?** The most common architectural mistake.
   Check [OWNERSHIP_MATRIX](audit/OWNERSHIP_MATRIX.md). Certification usually
   catches this, but a genuinely novel concern will not trip it.
2. **If it weakens an invariant, is the weakening argued?** Adding a name to a
   pinned allowlist is how a real regression gets normalised. Every addition
   needs a reason in the PR body.
3. **If it adds an invariant, is the mutation proof real?** Ask what was broken
   and **why the test failed**. Two milestones running, a probe that "failed"
   for the wrong reason — a compile error, a regex that still matched — was
   caught only by asking that. A probe that fails for the wrong reason is
   indistinguishable from an invariant that does not work.
4. **Is the analyzer baseline respected?** It may go down, never up. If it goes
   down, `tool/analyze_gate.sh` should be updated in the same PR.
5. **Are the claims honest?** This project's documents state their own gaps.
   A PR that overstates completeness is worse than one that under-delivers.

## Triage

| Label | Meaning |
|---|---|
| `needs-triage` | Applied by templates; remove once assessed |
| `bug` / `enhancement` / `documentation` | Kind |
| `architecture` | Needs lead review and probably an ADR |
| `good first issue` | Self-contained, no whole-system knowledge needed |
| `help wanted` | Genuinely want outside help |
| `out-of-scope` | Conflicts with [VISION.md](../VISION.md) — close with the reason, kindly |
| `known` | Already tracked in SUPPORT.md; close as duplicate |

**Marketplace, cloud sync, accounts, multi-device and autonomous execution are
out of scope.** Close them politely with a link to VISION and an invitation to
open a Discussion. Do not leave them open to rot.

## Keeping documents true

Documentation staleness in this repository is systemic — counts embedded in
prose drift because nothing checks them. When you touch any of these, check the
numbers:

| Claim | Where it lives | Verify with |
|---|---|---|
| Invariant count | CI step name, `INVARIANT_TRACEABILITY.md`, README badge | run the certification suite |
| Test count | README badge, ROADMAP | `flutter test` |
| Analyzer baseline | `tool/analyze_gate.sh`, CONTRIBUTING | `bash tool/analyze_gate.sh` |
| Reachability counts | `RUNTIME_REACHABILITY_GRAPH.md` | `python tool/reachability.py` — **currently stale by 3 files** |

I-84 keeps invariant *IDs* honest in both directions. Nothing does the same for
*numbers*. Until something does, this is a human duty.

## Releasing

See [RELEASE_GUIDE.md](RELEASE_GUIDE.md). Short version: bump `pubspec.yaml`,
move `CHANGELOG` `Unreleased` into a version, run all four checks plus
`flutter build appbundle --release`, tag, upload.

**The release keystore is unrecoverable if lost.** Enrol in Play App Signing so
a lost *upload* key is recoverable.

## Security reports

Acknowledge quickly, fix privately, disclose after the fix ships, credit the
reporter unless they decline. Never discuss an unfixed vulnerability in a public
issue or PR. Process: [SECURITY.md](../SECURITY.md).

## Things to resist

Learned from this project's own history, and worth stating so they are not
relearned:

1. **Architecture for its own sake.** Architecture is ~90% complete. Seventeen
   consecutive milestones improved it while release engineering stayed at 15%
   and nobody noticed, because nothing measured it.
2. **Building a framework with no consumer.** Four milestones shipped correct,
   certified frameworks that no production code imports. Before merging a new
   subsystem, ask *what will call this, and is that in scope for this PR?*
3. **Accepting a green run without reading it.** The suite occasionally fails
   one test under contention and passes on re-run (G-40). "All tests pass" is
   weaker than it reads until that is fixed.
4. **Deleting the unreachable v1 files casually.** ~50 files form a coherent
   parallel application. Deleting them is a decision, not cleanup — take it once,
   deliberately, with an ADR.
