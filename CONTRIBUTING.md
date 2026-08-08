# Contributing to Anything

Thank you for considering it. This project is unusually safe to contribute to:
**101 certified invariants and 2,127 tests will tell you immediately if a change
breaks an architectural rule**, so you do not need to hold the whole system in
your head to make a correct change.

---

## Before you start

| Kind of change | What to do first |
|---|---|
| Bug fix | Open an issue, or just send the PR if it is small and obvious |
| New feature | Open an issue first — it may conflict with a stated principle |
| Architecture change | Open a **Discussion**. See [Architecture changes](#architecture-changes) |
| Marketplace / cloud / accounts | Open a Discussion. These are [explicitly out of scope](VISION.md#what-anything-is-not) |
| Docs, examples, tests | Send the PR |

## Setup

```bash
git clone https://github.com/PIYUSH-MISHRA-00/Anything.git
cd Anything
flutter pub get
flutter test
```

Requires **Flutter 3.44+**. A full test run takes about 3 minutes.

## The four checks

Run these before every push. They are exactly what CI runs, so a green local run
means a green CI run.

```bash
dart format .                                              # 1. format
bash tool/analyze_gate.sh                                  # 2. analyzer baseline
flutter test test/r46_architectural_integrity_certification_test.dart   # 3. invariants
flutter test                                               # 4. full suite
```

**The analyzer gate compares against an explicit baseline** (0 errors, 27
warnings, 43 infos) rather than demanding zero. It fails on any *increase*. If
you reduce the count, say so in your PR — the baseline in `tool/analyze_gate.sh`
should come down with you.

## Architecture changes

Anything enforces **one owner per concern**, mechanically. If your change adds a
second thing that decides, stores, schedules, validates or serialises something
that already has an owner, a certification test will fail and name the file.

That failure is usually correct. Before working around it:

1. Read [`docs/audit/OWNERSHIP_MATRIX.md`](docs/audit/OWNERSHIP_MATRIX.md) —
   who owns this already?
2. Prefer **extending** the existing owner over creating a new one.
3. If a new owner is genuinely right, open a Discussion first and expect to
   write an ADR.

**Adding an invariant?** It must be *mutation-proven*: deliberately break the
thing it protects, confirm the test fails, restore, and record both in the PR.
An invariant that has never been made to fail is a claim, not a check — and
verify **why** it failed, not just that it did. Two milestones running, a probe
that "failed" for the wrong reason (a compile error, a regex that still matched)
has been caught by exactly that habit.

Register any new `I-nn` in
[`docs/audit/INVARIANT_TRACEABILITY.md`](docs/audit/INVARIANT_TRACEABILITY.md).
I-84 fails the suite if you forget.

## Style

- **Match the surrounding code.** Comment density, naming and idiom vary by
  layer; follow the file you are in.
- **Comments explain *why*, not *what*.** This codebase's comments routinely
  record what was true before a change and why it changed. That convention is
  load-bearing — please keep it.
- `dart format` decides formatting. Do not argue with it.
- Optional dependencies use the established seam: `this.thing`, defaulted with
  `thing ?? DefaultThing()`. Do not make an existing constructor parameter
  required.

## Commits and PRs

Conventional commit prefixes: `feat:` `fix:` `docs:` `test:` `refactor:`
`chore:` `perf:`.

Larger changes are usually split into `feat:` / `test:` / `docs:` commits. That
is a convention here, not a rule.

A good PR body says: what changed, why, what you ran, and what you deliberately
did **not** do. If something is incomplete, say so — an honest gap is far more
useful than a confident overstatement.

## Testing

| Change | Expected test |
|---|---|
| Bug fix | A test that fails before your fix |
| New behaviour | Behavioural tests, not just construction |
| New invariant | Mutation proof, recorded in the PR |
| Docs / examples | None, but examples must actually run |

**Do not skip tests.** `skip:` currently appears zero times in this repository
and we would like to keep it that way. A skipped test is how a suite decays
quietly.

## What makes a change likely to be accepted

- It improves developer experience, user experience, OSS quality, Play Store
  readiness, maintainability, documentation, testing, release engineering or
  community.
- It reuses what exists rather than adding a parallel mechanism.
- It is the smallest change that actually solves the problem.
- It is honest about its limitations.

## Code of Conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Licensing of contributions

Contributions are accepted under the [Apache License 2.0](LICENSE). We use
**DCO** rather than a CLA — sign off your commits:

```bash
git commit -s -m "fix: ..."
```

That adds a `Signed-off-by:` line certifying you have the right to submit the
work. No paperwork, no copyright assignment; you keep ownership of what you
write.
