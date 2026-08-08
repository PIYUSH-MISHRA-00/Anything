# Examples

Small programs that exercise the real APIs and print what they do. Read one in a
minute; run one in seconds.

| Example | Run with | Shows |
|---|---|---|
| [`minimal_experience`](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/examples/minimal_experience) | `dart run` | The smallest Experience; structural identity; JSON fidelity |
| [`execution_contract`](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/examples/execution_contract) | `dart run` | Declaring how an Experience runs, and every fault refused |
| [`package_codec`](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/examples/package_codec) | `flutter test` | Determinism, tamper detection, every read failure mode |
| [`orchestration`](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/examples/orchestration) | `flutter test` | Request to decision to priority, and why a contract narrows but never widens |

```bash
dart run     examples/minimal_experience/main.dart
dart run     examples/execution_contract/main.dart
flutter test examples/package_codec/main.dart
flutter test examples/orchestration/main.dart
```

## Why two runners

`dart run` works for examples whose import chain is pure Dart. Two of these
reach code that touches `package:flutter/material.dart`, and under the plain
Dart VM that trips the FFI transformer on this project's plugin set. `flutter
test` executes a bare `main()` without complaint — the trailing "No tests ran"
is expected.

This was measured, not assumed: a trivial file runs fine under `dart run`, and
the crash appears exactly when the Flutter-touching chain is imported.

## Reading order

`minimal_experience` then `execution_contract` then `package_codec` then
`orchestration`. That is the order the concepts build in: what an Experience
*is*, how it declares its execution, how it travels, and how it gets to run.
