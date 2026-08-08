# Experiences

An **Experience** is the unit of software Anything creates and runs.

Full developer reference:
[EXPERIENCE_GUIDE.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/EXPERIENCE_GUIDE.md).
This page is the concept; that document is the API.

## The shape

```dart
ExperiencePackage(
  manifest:   ExperienceManifest(...),   // identity + declared capabilities
  interface:  InterfaceDefinition(...),  // screens → node tree
  behavior:   BehaviorGraph(...),        // what happens on interaction
  state:      StateSchema(...),          // what it remembers
  provenance: PackageProvenance(...),    // which engine version made it
  integrity:  PackageIntegrity(...),     // content hash
)
```

## The manifest is canonical

`ExperienceManifest` is the *one* description of identity and capabilities.
Everything that needs identity — the transport envelope, the execution
contract — **embeds** it rather than copying its fields. A test fails if a
second manifest ever appears.

A capability declared in **both** the required and optional lists is a
validation error, not a preference: the Experience has not decided whether it
can run without it, and the two answers lead to different enforcement outcomes.

## The lifecycle

| Stage | Owner |
|---|---|
| Create | `CreationEngine` ← `AnythingKernel` |
| Validate | `ExperiencePackageValidator` |
| Commit | `ExperienceCommitFramework` — transactional |
| Store | `SqliteExperienceRepository` |
| Open | `ExperienceEntryPipeline` |
| Orchestrate | `ExperienceOrchestrator` |
| Schedule | `WorkspaceSchedulingEngine` |
| Execute | `AnythingRuntime` |
| Protect | `ExperienceProtectionService` |
| Serialise | `ExperiencePackageWriter` / `Reader` |
| Install | `ExperienceInstallationFramework` |

Exactly one owner each, and that singularity is certified by a test.

## Portability

```
export:  repository → writer → .anything file
import:  file → reader → installer → repository
```

**Read, then install — never install while reading.** The reader deliberately
never installs, activates or computes trust: parsing something must not run it,
and a well-formed package must not earn authority by being well-formed.

The writer is **deterministic** — every map is emitted with sorted keys, so the
same Experience always produces byte-identical output. Lists keep their order,
because element order is data. Without that, the embedded checksum would mean
nothing.

## Declaring how it runs

A contract states what an Experience **asks for**. It never decides.

```dart
ExperienceExecutionContract(
  manifest: manifest,
  mode: ExecutionMode.background,   // a request, not a grant
  onInterruption: InterruptionPolicy.suspend,
)
```

Declaring `background` does not grant background — governance still refuses it
below `local` trust. Declaring a capability does not grant it — the capability
platform still enforces.

**Why:** a contract travels *inside* a package, and a package is untrusted
input. A contract that could decide its own eligibility would be a governance
engine reachable by anyone who can write a manifest.

## Try it

[`examples/minimal_experience`](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/examples/minimal_experience)
and
[`examples/package_codec`](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/examples/package_codec)
run in a terminal and print exactly what happens.
