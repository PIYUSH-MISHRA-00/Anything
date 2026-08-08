# Roadmap

Honest status. Every claim here is measured, and where something is broken this
file says so plainly.

**Last verified:** IS-P02 · `flutter test` 2,141 passing · 102 invariants

---

## Where the project actually is

| Area | Complete | Note |
|---|---|---|
| Architecture | ~90% | 102 certified invariants, single ownership throughout |
| Testing rigour | ~80% | 2,141 tests, 0 skipped; no golden tests yet |
| Experience system (design) | ~85% | every stage exists and is certified |
| **Experience system (reachable)** | **~75%** | import/export wired and reachable (IS-P02) |
| AI / knowledge | ~60% | nine engines; one provider; needs a key |
| UI / UX | ~45% | 7 reachable screens |
| **Android release** | **~35%** | signing, permissions and R8 fixed in IS-P01; not yet published |
| OSS readiness | ~85% | license, guides, templates, website, NOTICE, Dependabot |
| **Play Store readiness** | **~50%** | see [PLAYSTORE_READINESS](docs/audit/) |

## What works today

Describe an intent → get a validated Experience → run it natively → run several
as a workspace → modify and evolve it → protect it with time-keyed encryption →
persistent local knowledge acquisition.

## What does not work yet

| Gap | Why it matters |
|---|---|
| **Never run on a physical device** | A signed release App Bundle builds, but nobody has installed it. Whether R8 broke anything at runtime is unknown. |
| **No published Android build** | IS-P01 fixed release signing, permissions and R8. Publishing still needs a keystore, a privacy policy and a store listing. |
| **One AI provider, and you must bring a key** | Without a Groq key the app runs and reports `ProviderRequired`. |
| **Accessibility is minimal** | 5 `Semantics` widgets across the whole codebase. |
| **No localisation** | Every string is English and hard-coded. |
| **Test flakiness (G-40)** | The full suite occasionally fails one test under contention and passes on re-run. Unresolved across four milestones. |
| **~50 unreachable v1 files** | A parallel application that cannot run. Kept pending a disposition decision. |

## Next

### P03 — Device Verification & First Run *(recommended)*

Install the App Bundle on a real device, verify R8 broke nothing, then
onboarding and the no-provider path.

### P04 — Accessibility & Localisation

Onboarding, the no-provider path, empty and error states, an accessibility pass
over the seven reachable screens, localisation scaffolding.

### P05 — Test Integrity

Diagnose and fix G-40. Golden tests for the reachable screens and the renderer.
One end-to-end journey test from `main()`.

### P06 — Launch

Privacy policy, Data Safety, store listing, telemetry, closed testing.

**Estimate: 4–6 milestones to a production-quality Play Store release**, of
which at most one is architectural.

## Where help is most useful

Highest value first — and note that none of the top items require understanding
the whole architecture:

1. **Accessibility** — semantics, contrast, font scaling on 7 screens
2. **Localisation scaffolding** — `l10n.yaml`, ARB files, externalising strings
3. **Golden tests** — no rendering regression protection exists at all
4. **A second AI provider** — implement `ModelProvider`, register it; the
   abstraction exists and has never had a second implementation
5. **G-40 diagnosis** — reproducible test-database contention
6. **Examples** — see [`examples/`](examples/)

## Not planned

Marketplace · cloud sync · accounts · multi-device sync · autonomous execution.

Each conflicts with a stated principle in [VISION.md](VISION.md). If you want
one of these, open a Discussion rather than a PR — it is a product conversation,
not a code one.
