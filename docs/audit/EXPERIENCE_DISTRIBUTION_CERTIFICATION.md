# Experience Distribution Certification — IS-R53

Enforced mechanically by `test/r46_architectural_integrity_certification_test.dart`.

## The four invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-57 | Exactly ONE distribution framework and ONE package verifier | STATIC | CERTIFIED |
| I-58 | Distribution never computes trust, enforces governance, activates a runtime, or protects | STATIC | CERTIFIED |
| I-59 | The verifier DELEGATES structural validation and never computes trust | STATIC | CERTIFIED |
| I-60 | The distribution manifest EMBEDS the canonical `ExperienceManifest` | STATIC | CERTIFIED |

### I-57 — no second mover

Scans for any `*Distribution*|*Import*|*Export*|*Install*` class ending in
Framework/Engine/Pipeline/Manager/Service, plus any `*Package*Verifier`, and
pins the result to exactly two. A second importer, exporter, installer or
verifier fails outright.

### I-58 — the long forbidden list, on purpose

Distribution may not reference:

- `ExperienceTrustClassifier`, `ExperienceTrustLevel`, `classify(` — trust is R52's
- `OperatingSystemGovernanceEngine`, `GovernanceDecision`, `GovernanceEvaluation` — policy is R51's
- `ExperienceEntryPipeline`, `ExperienceHostScreen`, `Navigator` — activation is R45's
- `ExperienceProtectionService`, `KaalkaService` — protection is Kaalka's

The list is long deliberately. A distribution layer is the most tempting place
in the system to "just also" do the next step, because it already holds the
package. Every one of those four subsystems is one line away from being
absorbed.

### I-59 — "no second verifier", made mechanical

Requires the literal `ExperiencePackageValidator.validate` call to be present
in the distribution file. Delegation is not merely intended, it is required:
remove it and re-implement structural validation, and certification fails.

### I-60 — "exactly one Experience Manifest", made mechanical

Two clauses:

1. exactly one class named `ExperienceManifest` exists in `lib/`;
2. the envelope declares `final ExperienceManifest manifest;`.

The second is what distinguishes *embedding* from *duplicating*. A parallel
record that copied `experienceId`/`name`/`version` into itself would satisfy
clause 1 and fail clause 2.

## Mutation evidence

**Probe A — a parallel importer and a second verifier.** A file declaring
`ExperienceImportPipeline` and `ExperiencePackageVerifier2`:

```
I-57  a duplicate importer/exporter/installer/verifier appeared:
      [..., lib/r53_mutation_probe.dart:ExperienceImportPipeline]
```

**Probe B — the verifier computing trust.** A `trustFor()` returning an
`ExperienceTrustLevel` added to `ExperiencePackageVerifier`.

This probe produced an instructive intermediate result: it **would not
compile**, because `experience_distribution.dart` has no import for
`ExperienceTrustLevel`. The boundary is enforced by the type system before
certification even runs. Adding the import to make the probe compile then
tripped the invariant explicitly:

```
I-58  Expected: false / Actual: <true>
      distribution moves experiences only; referencing ExperienceTrustLevel
      would make it a second owner of that subsystem
```

Worth recording: the compile failure is the cheaper guard, and it fired first.
Certification is the guard for the case where someone adds the import
deliberately.

Both probes were removed and the tree confirmed clean. (Note: the R53 file was
still untracked at probe time, so `git checkout --` could not revert it — the
edits were removed manually and verified absent by grep. A probe on an
uncommitted file needs manual cleanup, which is easy to forget.)

## What this certification cannot catch

- **Whether a package is genuinely safe.** It proves the package is intact and
  internally consistent. Integrity is not safety — a well-formed package from
  an untrusted origin is exactly what the trust chain exists to constrain, and
  that is R52's job, not the verifier's.
- **Whether a publisher signature is real.** Nothing verifies signatures; the
  classifier deliberately refuses to treat the field as proof.
- **That a user can actually import anything.** There is no file format and no
  file I/O yet — see limitation 1 in the architecture document.
