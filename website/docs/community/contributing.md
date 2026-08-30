# Contributing

Contributions are genuinely welcome, and this project is unusually safe to
contribute to: **102 certified invariants and 2,350+ tests will tell you
immediately if a change breaks an architectural rule.**

Full guide: [CONTRIBUTING.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/CONTRIBUTING.md).

## The four checks

Exactly what CI runs. Green locally means green in CI.

```bash
dart format .
bash tool/analyze_gate.sh
flutter test test/r46_architectural_integrity_certification_test.dart
flutter test
```

## Where help is most useful

None of these require understanding the whole architecture:

| Area | Why it is a good first contribution |
|---|---|
| **Accessibility** | 5 `Semantics` widgets across the whole codebase. 7 screens, well bounded |
| **Localisation** | No `l10n.yaml` yet. Scaffolding plus externalising strings |
| **Golden tests** | Zero exist. The renderer has no regression protection at all |
| **A second AI provider** | The abstraction exists and has never had a second implementation |
| **G-40 diagnosis** | A reproducible test-database contention bug, unresolved for five milestones |
| **Testing on hardware we do not have** | Join the [closed test](/guide/installation) and report what breaks on your device |

## If a certification test fails

It is usually right. You have probably created a second owner for something that
already has one. Check the
[ownership matrix](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/audit/OWNERSHIP_MATRIX.md) and prefer extending
the existing owner.

If a new owner is genuinely correct, open a
[Discussion](https://github.com/PIYUSH-MISHRA-00/Anything/discussions) and
expect to write an ADR.

## Adding an invariant

It must be **mutation-proven**: break the thing it protects, confirm the test
fails, and check **why** it failed. Three milestones running, that last step has
caught a probe that "failed" for the wrong reason and proved nothing.

## Out of scope

Marketplace, cloud sync, accounts, multi-device sync and autonomous execution.
Each conflicts with a stated principle. Open a Discussion rather than a PR.

## Licensing

Apache-2.0, with **DCO rather than a CLA** — sign off your commits:

```bash
git commit -s -m "fix: ..."
```

No paperwork, no copyright assignment. You keep ownership of what you write.
