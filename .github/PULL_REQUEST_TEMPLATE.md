## What does this change?

<!-- One or two sentences. What is different after this PR? -->

## Why?

<!-- The problem, not the solution. Link an issue if there is one. -->

Closes #

## Which of these does it improve?

<!-- IS-P01 rule: a change should improve at least one. Tick all that apply. -->

- [ ] Developer experience
- [ ] User experience
- [ ] Open source quality
- [ ] Play Store readiness
- [ ] Repository maintainability
- [ ] Documentation
- [ ] Testing
- [ ] Release engineering
- [ ] Community

## Checks

<!-- These are exactly what CI runs. Green locally = green in CI. -->

- [ ] `dart format .`
- [ ] `bash tool/analyze_gate.sh` — at or below baseline
- [ ] `flutter test test/r46_architectural_integrity_certification_test.dart` — 101 invariants
- [ ] `flutter test` — full suite

## Architecture

- [ ] This change adds **no new owner** for something that already has one
      (see [OWNERSHIP_MATRIX](../docs/audit/OWNERSHIP_MATRIX.md))
- [ ] If it adds an invariant, it is **mutation-proven** — describe below what
      you broke, that the test failed, and **why** it failed
- [ ] If it adds an invariant, the ID is registered in
      [INVARIANT_TRACEABILITY](../docs/audit/INVARIANT_TRACEABILITY.md)

<!-- Mutation proof, if applicable:
     Probe:  ...
     Result: FAILED as required, reason text: "..."
-->

## What I deliberately did NOT do

<!-- Honest gaps are more useful than confident overstatement. If something is
     incomplete, out of scope, or left for a follow-up, say so here. -->

## Sign-off

- [ ] Commits are signed off (`git commit -s`) per [DCO](../CONTRIBUTING.md#licensing-of-contributions)
