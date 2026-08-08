# Invariant Traceability — IS-R58 Phase 9

## The measured problem

The certification suite runs **92 invariants**. The matrices in `docs/audit/`
reference **80 numbered invariant IDs** (`I-01` … `I-83`).

Measured at IS-R58 Phase 9:

| | Count |
|---|---|
| Numbered IDs referenced in `ARCHITECTURE_INVARIANT_MATRIX.md` | 80 |
| IDs that appear anywhere in the certification source | **20** (was 15 at R58) |
| Tests carrying an ID in their **name** | **3** |
| IDs documented but absent from the source | **68** |

**Traceability was therefore ~4%.** A reader looking at a failed certification
test could not map it to the matrix row that explains why it exists; a reader
looking at a matrix row could not find the test that enforces it.

The post-R57 audit reported this as "`I-79` is documented but absent". That
understated it by a factor of 68.

## The rule, enforced by I-84

`I-84` makes the correspondence machine-checked in both directions:

- **No orphan IDs.** Every `I-NN` mentioned in the certification source must
  appear in the table below.
- **No stale map entries.** Every `I-NN` in the table below must appear in the
  certification source.

So the map cannot rot, and a new invariant cannot be added without registering
it here.

## What a compliant entry looks like

New certification tests (IS-R58 onward) carry their ID **in the test name**, so
a failure prints it:

```
I-83 — EVERY declared type in lib/ is declared exactly once, or is a PINNED
       documented duplicate (IS-R58 Phase 6)
```

## Registered IDs

| ID | Owning milestone | Protects | Historical defect it prevents |
|---|---|---|---|
| I-21a | R46 | Exactly one crypto importer in `lib/` | Kaalka reachable outside its adapter, creating a second protection path |
| I-49 | R51 | The governance engine imports nothing | A policy engine acquiring dependencies and becoming a second owner |
| I-50 | R51 | Exactly one trust model | A second `TrustLevel` competing with the canonical one |
| I-59 | R53 | The package verifier DELEGATES structural validation | A second verifier re-implementing the canonical validator's rules |
| I-60 | R53 | The distribution manifest EMBEDS the canonical `ExperienceManifest` | A parallel manifest copying `experienceId`/`name`/`version` into itself |
| I-65 | R54 | The installation transaction DELEGATES structural validation | The same "second validator" drift, one layer lower |
| I-61 | R54 | One installer, one compatibility evaluator, one dependency planner | Duplicate installers/updaters |
| I-67 | R54 | Distribution never commits | R53's distribution framework writing to the repository directly |
| I-68 | R55 | One commit framework, one transaction coordinator | A second persistence commit path |
| I-70 | R55 | Every commit-framework write runs in a transaction | A dropped `using:` silently reopening the G-28 crash window |
| I-74 | R55 | The repository does not know the commit framework | Circular ownership letting a write re-enter from below |
| I-75 | R56 | One durable collection store | A second `SharedPreferences` collection owner |
| I-77 | R56 | `deliverDue` claims before it presents | Concurrent delivery presenting the same notification twice |
| I-78 | R57 | Repositories constructed only via approved seams | Nine bare `ActivityRepository` constructions with no injection point |
| I-80 | R57 | Dead contracts and `MinimalKernel` stay deleted | Dead, name-colliding contract files returning |
| **I-81** | **R58** | CI runs formatting, the analyze gate, certification and the suite | CI halting before `flutter test`, leaving 89 invariants advisory |
| **I-82** | **R58** | The analyze gate declares an explicit baseline and weakens nothing | A step *named* for a baseline comparison that never performed one |
| **I-83** | **R58** | Every declared type is declared once or is a pinned duplicate | A duplicate-declaration check that scanned 13 of 1,263 types |
| **I-84** | **R58** | Invariant IDs are traceable in both directions | 80 documented IDs, 15 present in source, 3 tagged — ~4% traceability |
| **I-85** | **R59** | Exactly one entry point, one app widget, no `ProviderScope` | A disconnected parallel v1 application revived by a second entry or a stray scope |
| **I-86** | **R59** | Every `lib/` file has a KNOWN runtime classification | 110 of 466 files unreachable from `main()` with no classification at all |
| **I-87** | **R60** | Exactly one package format, reader and writer; manifest and validator not duplicated | A transport envelope with `toJson()` and no `fromJson` — a one-way street since R53 |
| **I-88** | **R60** | The reader never installs, activates, computes trust or performs I/O | Parsing something must not run it, and a well-formed package must not earn authority |
| **I-89** | **R61** | Exactly one execution contract and one execution validator; the contract EMBEDS the canonical manifest | A second execution contract would re-declare the capabilities `ExperienceManifest` has owned since R53 (I-60) |
| **I-90** | **R61** | The execution contract DECLARES only — it never decides, schedules, executes, enforces or persists | A contract travels inside a package, and a package is untrusted input; a contract that could decide its own eligibility would be a governance engine reachable by anyone who can write a manifest |

## Remaining work, stated plainly

**68 documented IDs (I-01 … I-48, I-51, I-57–I-66, I-69, I-71–I-73, I-76, I-79
and the lettered variants) are NOT yet registered**, because their tests do not
carry the ID and mapping 89 pre-R58 tests to matrix rows by hand is a
substantial, error-prone edit that IS-R58 did not authorise — it changes no
architecture, but a wrong mapping would be worse than none.

I-84 prevents the gap from **growing**: any ID newly mentioned in the source
must be registered, and any registered ID must exist.

`I-79` specifically remains unreconciled: it is referenced in
`ARCHITECTURE_INVARIANT_MATRIX.md` and appears nowhere in the source. It is one
of the 68 and is recorded as gap **G-49**.

**Recommended:** retro-tag the 89 pre-R58 tests in a milestone of its own,
one milestone-family per commit, verifying each mapping against that
milestone's own report.
