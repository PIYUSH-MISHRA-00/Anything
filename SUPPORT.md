# Support

## Where to go

| I want to… | Go here |
|---|---|
| Ask a question | [Discussions → Q&A](https://github.com/PIYUSH-MISHRA-00/Anything/discussions) |
| Report a bug | [Issues → Bug report](https://github.com/PIYUSH-MISHRA-00/Anything/issues/new/choose) |
| Request a feature | [Issues → Feature request](https://github.com/PIYUSH-MISHRA-00/Anything/issues/new/choose) |
| Report a vulnerability | [SECURITY.md](SECURITY.md) — **not** a public issue |
| Discuss an architecture change | [Discussions → Ideas](https://github.com/PIYUSH-MISHRA-00/Anything/discussions) |

## Before opening an issue

Check the [FAQ](docs/FAQ.md) and the
[Troubleshooting guide](docs/TROUBLESHOOTING_GUIDE.md). Then confirm your
checkout is healthy:

```bash
flutter pub get
flutter test test/r46_architectural_integrity_certification_test.dart
```

If those 101 invariants fail on a clean checkout, that is itself the bug —
please report it.

## Known issues

These are already tracked; you do not need to report them:

| Issue | Status |
|---|---|
| Not on the public Play Store yet | On Google Play in **closed testing**; the public listing follows |
| `ProviderRequired` with no AI key | Expected — add a key in Settings |
| A test occasionally fails in a full run and passes on re-run | Known as **G-40**, unresolved |
| Accessibility is minimal | Known; help welcome |
| No localisation | Known; help welcome |

## Response expectations

This is a small project. Issues and PRs are read, but there is no SLA. Security
reports get priority — see [SECURITY.md](SECURITY.md).
