# Experience Installation Architecture — Implementation Specification IS-R54

## WHAT THE TASK 1 AUDIT FOUND

Four findings shaped the milestone. Each is a fact from the repository, not a
design preference.

### 1. Nothing owned installation — five call sites committed independently

| Site | What it commits |
|---|---|
| `app/creation_coordinator.dart:442` | a newly created Experience |
| `app/experience_distribution.dart` (R53) | an imported Experience |
| `app/experience_modification_coordinator.dart:136, 295, 379` | a modified Experience, and a rollback |
| `evolution/evolution_coordinator.dart:79` | an evolved Experience |
| `security/protection_service.dart:289` | a protected Experience |

Five writers, five sets of rules about what must be true before a write.
Nothing evaluated compatibility, nothing prepared dependencies, and nothing
wrapped the two-row write in anything resembling a transaction.

### 2. `minimumRuntimeVersion` was declared and read by NOTHING

`ExperienceManifest.minimumRuntimeVersion` has existed, been serialised and
round-tripped since the manifest existed. A repository-wide search found its
only occurrences to be its own declaration, its `toJson`/`fromJson`, and a
doc comment.

**The system made a compatibility promise in its data model and never kept
it.** `ExperienceCompatibilityEvaluator` is that field's first consumer.

### 3. A migration engine ALREADY existed

| Type | Location |
|---|---|
| `MigrationExecutor` | `lib/storage/migration_executor.dart:28` |
| `DataMigrationPlan`, `MigrationValidator`, `MigrationOperation` | `lib/storage/migration.dart` |

`MigrationExecutor` runs typed, transactional `ALTER TABLE`/`CREATE TABLE`
operations against a real per-Experience SQLite database, and updates
`data_schema_versions` inside the same transaction. It is real and it works.

IS-R54's ABSOLUTE RULES forbid a "Second migration engine", so R54 built none.
See [Migration](#task-6--migration-preparation) below.

### 4. The repository keeps NO version history

`savePackage` and `saveMetadata` are separate
`INSERT … ConflictAlgorithm.replace` calls keyed on the Experience id. One row
per Experience, replace-on-write, and sqflite's `db.transaction` is not exposed.

`ExperienceModificationCoordinator.rollback` already documented this and solved
it by making the caller hold the previous package. R54 does the same thing, for
the same reason, deliberately — so there are not two different rollback
contracts in one system.

## OWNERSHIP AFTER R54

```
ExperienceDistributionFramework  MOVES      (import / export)         R53
ExperienceInstallationFramework  COMMITS    (install/upgrade/repair)  R54
ExperiencePackageVerifier        VERIFIES envelopes                   R53
ExperiencePackageValidator       VALIDATES structure                  canonical
ExperienceTrustClassifier        COMPUTES trust                       R52
OperatingSystemGovernanceEngine  DECIDES                              R51
CapabilityPlatform               ENFORCES                             R49/R51
SqliteExperienceRepository       STORES                               canonical
ExperienceEntryPipeline          ACTIVATES                            R45
ExperienceProtectionService      PROTECTS                             Kaalka
MigrationExecutor                MIGRATES                             canonical
```

The installer is the most dangerous component in this list: it is the last
thing to touch a package before it becomes real, so every other subsystem is
one convenience call away from being absorbed. Certification forbids it from
naming the trust classifier, the governance engine, the capability platform,
the distribution framework, the entry pipeline, `Navigator`, `AnythingRuntime`,
the migration executor, or any crypto type (I-61 … I-67).

## TASK 8 — DISTRIBUTION NO LONGER COMMITS

R53's `import()` wrote both repository rows itself. R54 takes that back:

```
distribution.import()
  -> verify envelope        (R53, unchanged)
  -> assign provenance      (R53, unchanged — channel -> origin, one place)
  -> installer.install(...) (R54 — evaluate, plan, validate, transact, commit)
  -> STOP. No activation.
```

**Signatures, return types and observable behaviour are unchanged.** Every R53
test passes untouched. The ownership moved; the behaviour did not — the same
pattern R50 used when three magic retention numbers moved to one engine.

### The tension in the specification, and how it was resolved

IS-R54's success criteria say both *"Distribution moves only"* and
*"Distribution unchanged"*. Task 8 says explicitly *"Distribution never
commits. Installer commits."*

Delegation satisfies all three readings at once: distribution stops committing
(so it moves only), and its API and behaviour are unchanged (so it is
unchanged). No redesign, no API break, no second write path.

### Avoiding a circular dependency

The installer accepts `ExperiencePackage` + `ExperienceProvenance`, **not**
`ExperienceDistributionPackage`. So `experience_installation.dart` imports
nothing from `experience_distribution.dart`, and the dependency runs one way:
distribution → installer → repository.

That is not just cycle-avoidance; it is the better boundary. **The installer
knows nothing about transport.** It cannot tell an import from a creation, and
it should not be able to.

## TASK 3 — COMPATIBILITY

`ExperienceCompatibilityEvaluator` is **pure**: no repository, no protection
service, no platform, no I/O. It cannot install even by accident — the type
system enforces "only evaluate" before certification does.

| Axis | Check |
|---|---|
| Runtime version | `minimumRuntimeVersion` vs this build — **the field's first consumer** |
| Manifest | id and entryPoint present, version parseable |
| Package format | `packageVersion` vs `experiencePackageVersion` |
| Capability | required ⊆ available (**blocking**); optional ⊄ available (**warning**) |
| Future SDK | `supportsPackageFormat()` — the existing format axis, not an invented one |

Two decisions worth stating:

- **A missing OPTIONAL capability warns, it does not block.** The Experience
  degrades; it does not become uninstallable.
- **An EMPTY capability set means "the caller did not say", not "nothing is
  available".** Treating those the same would turn a caller's omission into an
  incompatible device and block every install.

`availableCapabilities` is passed in rather than read from `CapabilityPlatform`
directly, which keeps the evaluator pure and stops it importing the enforcement
layer it must never touch.

### The version comparator

`compareVersions` is the one version comparator in `lib/`. A repository-wide
search before writing it found exactly one version-arithmetic site,
`ModificationEngine._bumpVersion` — which *produces* a version and is private.
Nothing existed to reuse.

It returns `null` on an unparseable input rather than defaulting to "equal", so
a caller must decide what an unreadable version means. It orders `1.10.0` above
`1.9.0`, which a string comparison would get wrong.

## TASK 4 — DEPENDENCY PREPARATION

`ExperienceDependencyPlanner` classifies each declared dependency as
`satisfied`, `missing` or `circular`. **It downloads nothing and opens no
socket** — architecture only, as instructed.

It is the first reader of R53's `dependencies` envelope field, which had been
transported and resolved by nothing (gap G-27, now closed).

**Not a second `DependencyResolver`.** The five resolvers in
`lib/feature_discovery/` expand a *feature candidate* into capability,
permission, storage and navigation primitives during design. This plans
*Experience-to-Experience package* dependencies at install time. Different
inputs, different outputs, different lifecycle stage. Certification pins both
sets so the distinction stays deliberate rather than becoming an excuse.

## TASK 5 — THE INSTALLATION TRANSACTION

`prepare → validate → commit → rollback / cancel`.

**This is a compensating transaction, not a database transaction.** It captures
the prior package and metadata at `prepare`, writes at `commit`, and on failure
restores exactly what it captured — deleting instead when prepare found nothing
there.

It is built this way because of the two constraints from the audit: the
repository exposes no transaction and must stay unchanged (Task 5, Task 12),
and it keeps no version history.

**The honest consequence:** if the process dies between the two writes, the
snapshot dies with it and nothing is left to call `rollback()`. That torn state
is real. It is recorded as gap **G-28**, and it is precisely why `repair()`
exists.

`validate` delegates to `ExperiencePackageValidator` and re-implements no rule —
the "no second verifier" discipline applied at the install layer (I-65).

## TASK 6 — MIGRATION PREPARATION

`MigrationRequirement` **records** that an install crosses a boundary
(`dataSchema`, `packageFormat`, `runtime`) and names the versions on each side.
It is derived by comparing the installed package with the incoming one — real
data on both sides, nothing fabricated.

It plans no operations and executes none:

- **Planning operations** would mean inventing a schema diff this milestone
  cannot honestly compute. A fabricated migration plan is worse than none.
- **Executing any** would make this a second migration engine, which the
  ABSOLUTE RULES forbid, when `MigrationExecutor` already does it properly.

Certified both ways (I-66): exactly one migration engine exists in `lib/`, and
the installer may not name `MigrationExecutor`, `DataMigrationPlan`,
`MigrationOperation` or `ALTER TABLE`.

## TASK 7 — PROTECTION

The installer **requests**; `ExperienceProtectionService` **performs**. It is
called only after a successful commit, and only when the caller asks.

`isProtected` is committed as `false` and only the protection service can make
it true. The installer never asserts a protected state it did not produce.

When protection is requested and no service is wired, that is **reported in the
result**, never silently ignored — an install that quietly failed to protect
what it was asked to protect is exactly the class of invisible gap this
codebase records instead of shipping.

Certification is a "must not reach past it" rule rather than the usual "must not
reference" rule: the installer MUST name `ExperienceProtectionService`, and must
NOT name `KaalkaService`, `ProtectionProvider`, `TimeSeed`, `encrypt(` or
`decrypt(`.

In the production composition the protection service is given the **same**
repository the composition owns, rather than being left to construct its own
(its constructor defaults to a fresh `SqliteExperienceRepository`).

## TASK 9 — INSTALL NEVER ACTIVATES

`install()` commits and stops. Certified: the file may not name
`ExperienceEntryPipeline`, `ExperienceHostScreen`, `ExperienceActivationManager`,
`Navigator`, `AnythingRuntime` or `ExperienceRenderer`.

This is a safety property, not an oversight. R53 established it for import;
R54 enforces it one layer lower, where the temptation is stronger because the
installer has just finished making the Experience real.

## REPAIR

The two rows an install writes can disagree, because they are two writes.
Repair fixes what is genuinely fixable from data still on the device:

| State | Action |
|---|---|
| package present, metadata missing | **rebuild metadata from the package's own manifest** |
| metadata present, package missing | **not repairable** — the package is gone and cannot be invented. Reported, never faked. |
| both present | nothing to repair |
| neither present | not installed |

When metadata is rebuilt, **provenance is not invented**. The row that carried
it is the row that was lost, so the truthful answer is unknown origin — which
R52's classifier will treat as untrusted. That is the correct outcome: a
recovered Experience whose origin nobody can vouch for should not silently
inherit authority.

## A REAL DEFECT FOUND AND FIXED

`experiencePackageVersion` was declared **twice** — `experience_package.dart:10`
and `package_validator.dart:221`, both `const int = 1`, independent. The
validator's local declaration shadowed the canonical one, so bumping the format
version in one place would leave the validator silently enforcing the other.

It had been invisible because nothing imported both libraries. The new installer
does, and could not compile (`ambiguous_import`) — the analyzer surfacing a real
defect again, for the fifth time across R46–R54.

The duplicate was deleted. No consumer imported it from there.

## KNOWN LIMITATIONS — read this section

1. **The transaction is compensating, not atomic.** A crash between the two
   writes leaves torn state that only `repair()` can address, because the
   in-memory snapshot is gone. Gap G-28.

2. **`currentRuntimeVersion` is hand-maintained.** `pubspec.yaml` cannot be read
   at runtime without adding `package_info_plus`, and R54 adds no dependency.
   It is declared in one place and overridable everywhere, but nothing
   mechanically ties it to the pubspec — which still reads `1.0.0+1` while the
   branch is v2.0.0. Gap G-29.

3. **Nothing calls the installer from a UI.** It is composed once and reached
   only by `distribution.import()` and its tests. Installation is not a user-
   facing feature in this milestone. And since there is still no file format or
   file I/O (R53's G-25, still open), **a user still cannot install an
   Experience from outside the device.**

4. **The other four commit sites still commit directly.** Creation,
   modification, evolution and protection were NOT rerouted through the
   installer. Doing so would have been a redesign of four coordinators in a
   milestone whose rules forbid replacing architecture, and each has genuinely
   different pre-conditions. R54 establishes the owner and moves the one path
   (distribution) that Task 8 names. Gap G-30 — this is the honest state, not a
   claim that all committing is unified.

5. **Dependencies are planned but never fetched.** Nothing can supply a missing
   dependency; there is no transport for one. A package declaring a dependency
   that is not already installed is simply refused.
