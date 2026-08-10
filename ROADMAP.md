# Roadmap

Honest status. Every claim here is measured, and where something is broken this
file says so plainly.

**Last verified:** P18 in progress · P17 `flutter test` **2325** passing ·
version `2.0.0+1` · analyzer target: absolute 0 issues (P18)

---

## Where the project actually is

| Area | Complete | Note |
|---|---|---|
| Architecture | ~90% | 102 certified invariants, single ownership throughout |
| Testing rigour | ~85% | 2325 tests at P17; P18 adding unknown-domain battery |
| Experience system (design) | ~85% | every stage exists and is certified |
| **Experience system (reachable)** | **~80%** | open-world multi-entity generation (P16/P17); import/export code exists |
| AI / knowledge | ~60% | WebWeaveX adapter exists; **device acquisition OPEN** |
| UI / UX | ~50% | generic entity list/form from semantics |
| **Android release** | **~40%** | APK builds; **AAB strip/NDK issue OPEN**; not Play-published |
| OSS readiness | ~85% | license, guides, templates, website |
| **Play Store readiness** | **~40%** | needs release-signed AAB, listing, privacy, device cert |

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
| **Full physical-device matrix** | Attached devices exist; P17/P18 device journeys still OPEN |
| **WebWeaveX real acquisition on device** | Adapter + unit tests ≠ production path proof |
| **Kaalka protect → force-stop → recover on device** | Integration tests exist; device process restart OPEN |
| **Import/export security matrix on device** | Code + unit tests ≠ end-to-end production cert |
| **Release AAB** | P17 failed stripping native debug symbols / NDK 28 incomplete |
| **Play Store** | No published build; signing/privacy/listing incomplete |
| **Documentation drift (being fixed in P18)** | README historically claimed 2141 tests / device never run |

## Current milestone

### P18 — Production closure + semantic generalization

- Absolute analyzer cleanliness (or documented exceptions)
- Version / docs / website truth
- AAB success or proven CI equivalence
- Stronger unknown-domain battery without domain-noun accumulation
- Device release APK: generate + CRUD + persistence
- WebWeaveX / Kaalka / import-export real paths
- CI remote run recorded

### After P18

Only if an external architectural review requests it. Do not invent P19 from
this file.

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
