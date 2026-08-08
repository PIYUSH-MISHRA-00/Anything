# Roadmap

Honest status. Where something is broken, this page says so.

**Last verified:** IS-P02 · `flutter test` 2,141 passing · 102 invariants

## Where the project is

| Area | Complete |
|---|---|
| Architecture | ~90% |
| Testing rigour | ~80% |
| Experience system (design) | ~90% |
| **Experience system (reachable)** | **~75%** — import/export now wired |
| AI / knowledge | ~60% |
| UI / UX | ~45% |
| Android release engineering | ~65% |
| OSS readiness | ~85% |
| Website | ~70% |
| **Play Store readiness** | **~50%** |

## What works

Describe an intent, get a validated Experience, run it natively, run several as
a workspace, modify and evolve it, protect it with time-keyed encryption,
**export and import it as a file**, and acquire knowledge from the web that
persists across restarts.

## What does not work yet

| Gap | Why it matters |
|---|---|
| **No published Android build** | Signing, permissions and R8 are fixed and a signed App Bundle builds. Publishing needs a privacy policy, store listing and closed testing |
| **Never run on a device** | A release artifact builds; nobody has yet installed it |
| **One AI provider, and you must bring a key** | Without a Groq key the app runs and reports `ProviderRequired` |
| **Accessibility is minimal** | 5 `Semantics` widgets across the whole codebase |
| **No localisation** | Every string is hard-coded English |
| **Test flakiness (G-40)** | The full suite occasionally fails one test under contention and passes on re-run. Unresolved across five milestones |
| **~50 unreachable v1 files** | A parallel application that cannot run, pending a disposition decision |

## Next

**P03 — Device Verification & First Run.** Install on a real device, verify R8
broke nothing, then onboarding and the no-provider path.

**P04 — Accessibility & Localisation.**

**P05 — Test Integrity.** Diagnose G-40; golden tests; one end-to-end journey.

**P06 — Launch.** Privacy policy, store listing, telemetry, closed testing.

**4–6 milestones to a production-quality release**, none of them architectural.

## Where help is most useful

None of these require understanding the whole architecture:

1. **Accessibility** — semantics, contrast, font scaling on 7 screens
2. **Localisation** — `l10n.yaml`, ARB files, externalising strings
3. **Golden tests** — no rendering regression protection exists at all
4. **A second AI provider** — implement `ModelProvider` and register it
5. **G-40 diagnosis** — reproducible test-database contention
6. **Screenshots** — genuinely blocked on someone running it

## Not planned

Marketplace, cloud sync, accounts, multi-device sync, autonomous execution.

Each conflicts with a stated principle. If you want one, open a
[Discussion](https://github.com/PIYUSH-MISHRA-00/Anything/discussions) rather
than a PR — it is a product conversation, not a code one.
