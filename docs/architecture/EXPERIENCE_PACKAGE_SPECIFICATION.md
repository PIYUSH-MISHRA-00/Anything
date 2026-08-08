# Experience Package Specification — IS-R60

## The decision that shaped this milestone

IS-R60 Phase 2 says *"Create ONE canonical ExperienceManifest"*. Phase 6 says
*"Implement package validator"*. **Both already existed and were certified.**

| Asked for | Already existed | Certified by |
|---|---|---|
| Canonical manifest | `ExperienceManifest` — `lib/creation/experience_package.dart:137` | I-60 (R53) |
| Package validator | `ExperiencePackageValidator` — `lib/creation/package_validator.dart:31` | I-59 (R53), I-65 (R54) |
| Transport envelope | `ExperienceDistributionManifest` | I-57, I-60 |
| Checksums / fingerprints | `PackageIntegrity`, `computeIntegrityHash` | — |
| Trust metadata | `ExperienceProvenance` | R52 |

Creating either would have produced a **second manifest and a second
validator** — forbidden by this specification's own ABSOLUTE RULES and
contradicted by its own success criteria. **R60 created neither.**

## What was genuinely missing

- **No container format.** Nothing defined how a package becomes bytes.
- **No reader.** Nothing turned bytes into a package.
- **No writer.** Nothing turned a package into bytes.
- **No `fromJson` on `ExperienceDistributionPackage`.** R53 gave it `toJson()`
  and no way back — a one-way street open for four milestones.

That is the concrete reason **G-25** ("a user still cannot import an
Experience") survived R53 → R59: the pipeline was complete on package
*objects*, and nothing could produce one.

## The container

```
{
  "format":        "ANYTHING-EXPERIENCE-PACKAGE",   <- magic, checked first
  "formatVersion": 1,                                <- container version
  "checksum":      "<computeIntegrityHash(package)>",
  "payload":       { ...canonical ExperiencePackage JSON... },
  "signature":     { ... }   // RESERVED, optional, never verified
  "extensions":    { ... }   // RESERVED, optional, carried verbatim
}
```

**Three independent versions, deliberately.** The container version
(`formatVersion`), the package **model** version (`experiencePackageVersion`)
and the R53 **envelope** version each change for different reasons. A binary
container could replace this encoding without touching the manifest, the
validator or any caller.

**Encoding is canonical JSON, not zip.** `archive` is not a dependency and R60
is forbidden from adding one. This is an encoding choice, not an architectural
one — see the version field above.

### Reserved blocks

`signature` and `extensions` are written verbatim and read back unchanged.
**Nothing verifies a signature.** A signed package written by a future build
round-trips through this one without losing the block, and reading it grants no
authority — the same position R52 and R53 took on publisher signatures.

## The pipeline

```
bytes → ExperiencePackageReader        (parse, checksum, delegate validation)
      → ExperiencePackageValidator     (canonical, R53 — NOT re-implemented)
      → ExperienceDistributionFramework (MOVES, R53)
      → ExperienceInstallationFramework (INSTALLS, R54)
      → ExperienceCommitFramework       (COMMITS, R55)
      → SqliteExperienceRepository      (STORES)
```

**No ownership changed.** The codec sits in front of a pipeline that already
existed.

## Determinism

The writer emits every map with **sorted keys**, recursively. Lists keep their
order — element order is data, not formatting.

The same package therefore always produces byte-identical output, regardless of
insertion order or hash order. This is asserted directly: two packages equal in
content but built in reverse key order produce identical bytes.

**Without this a checksum is meaningless**, and a future signature would be
worse than meaningless.

## What the reader will not do

| Never | Owner |
|---|---|
| install / commit | R54 / R55 |
| activate a runtime | R45 |
| compute trust | R52 |
| move or distribute | R53 |
| read or write files | `RealFileService` (R49) |
| network | nothing — forbidden by R60 |
| encrypt | `ExperienceProtectionService` |

All certified by **I-88**.

The checksum is verified against the **rebuilt package**, not the raw text, so
a payload edited in transit is caught even when the edit leaves valid JSON.

## Known limitations

1. **Still no file I/O.** The codec produces and consumes bytes; nothing writes
   them to a `.anything` file. `RealFileService` (R49) owns file I/O and
   `file_picker` is already a dependency. **G-25 is now one small step from
   closed, and is not closed.**
2. **No signature verification.** The block is reserved and carried; nothing
   checks it.
3. **JSON, not a compressed archive.** Deliberate — no new dependency. Large
   packages are stored uncompressed.
4. **No UI.** Nothing lets a user choose a package.
