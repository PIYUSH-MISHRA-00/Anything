# Roadmap

Honest status. Where something is broken, this page says so.

**Last verified:** device validation on moto g31 (Android 12) and moto g45 5G
(Android 15) · 102 architectural invariants · signed App Bundle targeting
Android 17 (API 37), live on Google Play closed testing.

## Where the project is

| Area | Complete |
|---|---|
| Architecture | ~95% |
| Testing rigour | ~85% |
| Experience system (design) | ~95% |
| Experience system (reachable) | ~90% |
| AI / knowledge | ~80% |
| UI / UX | ~75% |
| Android release engineering | **~100%** — signed, targeted at API 37, shipped to a Play track |
| OSS readiness | ~90% |
| Website | ~90% |
| **Play Store readiness** | **~90%** — closed testing running; public listing next |

## What works

Describe an intent and get a validated Experience. Run it natively — interface,
behaviour and state. Run several as a workspace, with scheduling. Modify and
evolve one by talking to it, scoped to the screen you are on or the whole app.
Pull **live web data** into a generated app through WebWeaveX. Protect an
Experience with time-keyed Kaalka encryption. Export and import one as a file.
Acquire knowledge from the web that persists across restarts.

All of it on-device, with no account and no server.

## Shipped

| Milestone | State |
|---|---|
| Signed release App Bundle | ✅ Real keystore, R8, shrinking |
| Target API level | ✅ Android 17 (API 37) — the newest stable level |
| Verified on physical hardware | ✅ moto g31 / Android 12, moto g45 5G / Android 15 |
| Privacy policy and store listing | ✅ [Privacy policy](/privacy) |
| Google Play closed testing | ✅ Running |
| Export / import round-trip | ✅ Device-proven, MediaStore-registered |

## What does not work yet

| Gap | Why it matters |
|---|---|
| **Not on the public Play Store** | The closed test has to complete first — Google requires 12 testers opted in for 14 continuous days before a production release can be reviewed |
| **One AI provider, and you must bring a key** | Without a Groq key the app runs and reports `ProviderRequired` |
| **Accessibility is minimal** | A handful of `Semantics` widgets across the whole codebase |
| **No localisation** | Every string is hard-coded English |
| **Test flakiness (G-40)** | The full suite occasionally fails one test under database contention and passes on re-run |

## Next

**Public release.** Finish the closed test, then promote to production.

**Accessibility & localisation.** The largest remaining quality gap, and the
one that needs no architectural knowledge to help with.

**A second AI provider.** Implement `ModelProvider` and register it.

**Test integrity.** Diagnose G-40; golden tests.

## Where help is most useful

None of these require understanding the whole architecture:

1. **Accessibility** — semantics, contrast, font scaling on 7 screens
2. **Localisation** — `l10n.yaml`, ARB files, externalising strings
3. **Golden tests** — no rendering regression protection exists at all
4. **A second AI provider** — implement `ModelProvider` and register it
5. **G-40 diagnosis** — reproducible test-database contention
6. **Testing on hardware we do not have** — join the closed test and report what breaks

## Not planned

Marketplace, cloud sync, accounts, multi-device sync, autonomous execution.

Each conflicts with a stated principle. If you want one, open a
[Discussion](https://github.com/PIYUSH-MISHRA-00/Anything/discussions) rather
than a PR — it is a product conversation, not a code one.
