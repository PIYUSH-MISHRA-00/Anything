# Roadmap

Honest status. Every claim here is measured, and where something is broken this
file says so plainly.

**Last verified:** P18 · local `flutter test` **2334** · CI full suite **2317**
· analyzer **0/0/0** · version `2.0.0+1` · CI run
[31365005092](https://github.com/PIYUSH-MISHRA-00/Anything/actions/runs/31365005092)
· tip `cef8439`

---

## Where the project actually is

| Area | Complete | Note |
|---|---|---|
| Architecture | ~90% | 102 certified invariants, single ownership throughout |
| Testing rigour | ~90% | 2334 local / 2317 CI; P18 unknown-domain battery included |
| Experience system (design) | ~85% | every stage exists and is certified |
| **Experience system (reachable)** | **~85%** | open-world generation + device same-APK multi-domain |
| AI / knowledge | ~60% | WebWeaveX adapter exists; **device acquisition OPEN** |
| UI / UX | ~55% | generic list/form on device for generated domains |
| **Android release** | **~70%** | APK PASS; **CI AAB PASS**; local strip CLI still noisy; not Play-published |
| OSS readiness | ~85% | license, guides, templates, website |
| **Play Store readiness** | **~45%** | needs release-signed AAB, listing, privacy, fuller device cert |

## What works today (automated / package level)

- Describe a structured multi-entity intent → SemanticApp → Blueprint →
  ExperiencePackage → SQLite CRUD (no domain factories)
- Typed fields / references / filter-sort capabilities on the deterministic path
- Capability shells for news / weather / calculation / timing / network-reference
- Kaalka protection APIs and WebWeaveX adapter (unit/integration evidence)
- Import/export codec and distribution framework (implementation exists)

## What is not production-certified yet

| Gap | Why it matters |
|---|---|
| **Full physical-device matrix** | Venue/grooming generate+create+persist proven; search/filter/edit/delete still OPEN |
| **WebWeaveX real acquisition on device** | Adapter + unit tests ≠ production path proof |
| **Kaalka protect → force-stop → recover on device** | Settings shows Kaalka; full protect/recover OPEN |
| **Import/export security matrix on device** | Code + unit/CI tests ≠ end-to-end production cert |
| **Local AAB strip CLI** | CI AAB already PASS; Windows strip check still exits non-zero |
| **Play Store** | No published build; signing/privacy/listing incomplete |

## Current milestone

### P18 — Production closure + semantic generalization (executed; NOT production complete)

- Absolute analyzer cleanliness: **PASS (0/0/0)**
- Version / docs truth: **PASS** (`2.0.0+1`); website deep sync still OPEN
- AAB: **CI PASS**; local strip CLI PARTIAL
- Unknown-domain battery without domain factories: **PASS**
- Device release APK generate + create + force-stop persist: **PARTIAL PASS**
- WebWeaveX / Kaalka / import-export device paths: **OPEN**
- CI remote run: **PASS** `31365005092`

### After P18

Stop. Only continue if an external architectural review requests another
milestone. Do not invent P19 from this file.

## Where help is most useful

1. **Device certification** — release APK journeys with evidence
2. **AAB / NDK toolchain** — clean NDK 28 install + strip pipeline
3. **Accessibility** — semantics, contrast, font scaling
4. **Localisation scaffolding**
5. **Golden tests** for the generic renderer

## Not planned

- Domain-specific application factories (`BakeryFactory`, `VenueFactory`, …)
- Model-emitted Dart / Flutter source for ordinary Experiences
- A second WebWeaveX or Kaalka boundary
