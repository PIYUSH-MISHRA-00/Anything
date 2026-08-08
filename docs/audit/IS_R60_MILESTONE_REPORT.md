# IS-R60 — Canonical Experience Package & Manifest Framework

**Date:** 2026-08-08 · `db0d44d` → HEAD · **Status:** COMPLETE

---

## 1. EXECUTIVE SUMMARY

R60 asked for a canonical manifest and a package validator. **Both already
existed and were certified**, so R60 created neither — the same document that
asked for them forbids a second manifest and a second validator.

What was genuinely missing was the thing four milestones had worked around:

- no container format
- no reader
- no writer
- **`ExperienceDistributionPackage` had `toJson()` and no `fromJson`** — a
  package could be written and never read back, since R53

That one-way street is the concrete reason **G-25** ("a user still cannot
import an Experience") survived R53 → R59: the pipeline was complete on package
*objects* and nothing could produce one.

| | Before | After |
|---|---|---|
| Package container format | **none** | one, versioned |
| Reader / writer | **none** | one each |
| Envelope round-trip | **write only** | read + write |
| Invariants | 95 | **97** |
| Tests | 2,068 | **2,085** |
| Analyzer | 0/27/43 | 0/27/43 |

**Architecture, ownership and behaviour unchanged.**

---

## 2. PHASE RESULTS

| Phase | Result |
|---|---|
| 1 — Audit | Manifest, validator, envelope, integrity hash, provenance **all pre-existing**; reader/writer/format **absent**; `fromJson` **absent** |
| 2 — Manifest | **Not created** — exists at `experience_package.dart:137`, certified I-60 |
| 3 — Package format | `ExperiencePackageFormat` — magic, version, checksum, payload, reserved signature + extension blocks |
| 4 — Reader | `ExperiencePackageReader` — parses, checksums, delegates validation, stops |
| 5 — Writer | `ExperiencePackageWriter` — deterministic, sorted-key canonical output |
| 6 — Validation | **Not created** — delegates to `ExperiencePackageValidator`, certified I-88 |
| 7 — Installation | Unchanged; codec sits in front of the existing R53→R54→R55 pipeline |
| 8 — Certification | I-87, I-88, both mutation-proven |
| 9 — Documentation | spec, usage matrix, ADR, this report |

---

## 3. CERTIFICATION AND MUTATION

| ID | Protects | Probe | Result |
|---|---|---|---|
| I-87 | One format, one reader, one writer; manifest and validator not duplicated | A — a second reader | **FAILED as required, after the invariant was fixed** |
| I-88 | Reader never installs, activates, computes trust, distributes or does I/O | B — a `classify()` on the reader | FAILED as required |

**I-87 was wrong on its first attempt and the probe caught it.** The regex
required the suffix at the *end* of the class name, so `ExperiencePackageReader2`
escaped entirely — `\b` cannot match between `r` and `2`. A second reader would
have been invisible with any trailing character. Rewritten to match the whole
identifier and filter by content.

Third time in five milestones a probe has exposed a **brand-new** invariant
rather than confirming it (R48 scanner blindness, R56 ordering-vs-containment,
R60 suffix anchoring).

**I-84 also fired**: the new comments referenced I-59, I-60 and I-65, which
were unregistered. They were registered rather than removed — traceability rose
from 15 to 20 IDs.

---

## 4. VALIDATION EVIDENCE

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed .` | **exit 0** |
| `tool/analyze_gate.sh` | **exit 0** — 0 errors / 27 warnings / 43 infos |
| Certification suite | **97 passed** |
| Full suite | **2,085 passed, 0 skipped** |
| `git status --porcelain` | empty |

---

## 5. DETERMINISM — demonstrated, not asserted

The writer emits every map with sorted keys, recursively; lists keep their
order because element order is data.

Three tests: the same package writes byte-identical output twice; two packages
equal in content but built in **reverse key order** produce identical bytes; a
different package produces different bytes.

Without this the checksum is meaningless and a future signature worse than
meaningless.

---

## 6. ARCHITECTURAL / BEHAVIOURAL / API DIFF — expected: none

**None.** No ownership moved. The only change to existing code is an additive
`ExperienceDistributionPackage.fromJson` — the missing half of a round-trip.
2,068 pre-existing tests pass unchanged; the +17 are 15 codec tests and 2
invariants.

---

## 7. REMAINING GAPS

| # | Sev | Gap |
|---|---|---|
| **G-25** | **A** | **A user still cannot import an Experience.** Half closed: the format exists, the file layer does not |
| G-53 | MED | No file I/O for packages — the codec must not own it (R49 does); wiring is unbuilt |
| G-54 | LOW | No signature verification — block reserved and carried, verified by nothing |
| G-55 | LOW | Packages uncompressed — no `archive` dependency, by rule |
| **G-40** | **HIGH** | Suite flakiness, unresolved and highest priority (see R59 §10) |
| G-48/G-50 | MED | The parallel v1 application, inert but present |
| G-44…G-47, G-49, G-51, G-52 | LOW–MED | Carried forward |

---

## 8. RECOMMENDATION FOR IS-R61

### Close G-25 — wire the codec to `RealFileService`

It is now genuinely small, and it is the only remaining step between four
milestones of package machinery and a user actually importing an Experience.

**Scope:**
1. `RealFileService` (R49) writes the writer's bytes to a `.anything` file and
   reads a user-picked one back. **No new ownership** — the codec still owns
   serialisation, the file service still owns I/O, and an invariant should
   assert the codec still contains no `dart:io`.
2. A single entry point in the distribution framework: pick file → read →
   verify → install, reusing R53→R54→R55 untouched.
3. One UI affordance. R59 proved `lib/features/` is 100% reachable, so it
   belongs there — not in the disconnected `lib/screens/` set.

**Do G-40 first if CI has gone red.** It remains the highest-priority item in
the repository: CI runs the suite as of R58, and an intermittently red gate
trains everyone to ignore it.

**Explicitly rejected for R61:** signature verification (needs a
key-distribution decision, which is a product question), compression (new
dependency), and anything resembling a marketplace, cloud sync or accounts.
