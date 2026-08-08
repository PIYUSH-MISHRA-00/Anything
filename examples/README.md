# Examples

Small programs that exercise Anything's real APIs and print what they do. Read
one in a minute; run one in a few seconds.

```bash
flutter pub get   # once
```

## The examples

| Example | Run with | Shows |
|---|---|---|
| [`minimal_experience`](minimal_experience) | `dart run examples/minimal_experience/main.dart` | The smallest Experience; structural identity; JSON fidelity |
| [`execution_contract`](execution_contract) | `dart run examples/execution_contract/main.dart` | Declaring how an Experience runs, and every fault the validator refuses |
| [`package_codec`](package_codec) | `flutter test examples/package_codec/main.dart` | Writing/reading a `.anything` package, determinism, tamper detection |
| [`orchestration`](orchestration) | `flutter test examples/orchestration/main.dart` | Turning a request into a decision; why a contract narrows but never widens |

Run them all:

```bash
dart run    examples/minimal_experience/main.dart
dart run    examples/execution_contract/main.dart
flutter test examples/package_codec/main.dart
flutter test examples/orchestration/main.dart
```

## Why two different runners

`dart run` is the natural way to run a Dart `main()`, and it works for examples
whose import chain is pure Dart.

Two of these reach `ExperiencePackageValidator` and the scheduler, whose import
chains touch `package:flutter/material.dart`. Under the plain Dart VM that trips
the FFI transformer on this project's plugin set and the compile crashes —
a toolchain limitation, not a problem with the example. `flutter test` executes
a bare `main()` without complaint.

Those runs end with **`No tests ran.`** That line is expected. These are
examples, not tests.

## Reading order

`minimal_experience` → `execution_contract` → `package_codec` →
`orchestration`. That is the order the concepts build in: what an Experience
*is*, how it declares its execution, how it travels, and how it gets to run.

## What these honestly show

`package_codec` and `orchestration` demonstrate machinery that is **built,
tested and certified — and, in the codec's case, not yet reachable from the
app's UI.** Nothing in the app currently imports the package codec, which is
why an Experience cannot yet be imported or exported. That is the project's
next milestone ([ROADMAP](../ROADMAP.md)), and these examples are the clearest
way to see what already works while waiting for the button that calls it.

## Not covered here

Kaalka protection and WebWeaveX knowledge acquisition are exercised by their own
test suites rather than by examples — both need real async setup (a `TimeSeed`
lifecycle; an injected page fetcher) that would make an example longer than the
guide explaining it. Read [KAALKA_GUIDE](../docs/KAALKA_GUIDE.md) and
[WEBWEAVEX_GUIDE](../docs/WEBWEAVEX_GUIDE.md) instead, then
`test/r47_*` and `test/r48_*` for working code.
