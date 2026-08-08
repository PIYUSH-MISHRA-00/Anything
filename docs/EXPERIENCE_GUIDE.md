# Experience Guide

An **Experience** is the unit of software Anything creates and runs. This guide
explains what one is, how it flows through the system, and how to work with one
in code.

Runnable code: [`examples/`](../examples/).

---

## What an Experience is

```dart
ExperiencePackage(
  manifest:   ExperienceManifest(...),   // identity + declared capabilities
  interface:  InterfaceDefinition(...),  // screens → node tree
  behavior:   BehaviorGraph(...),        // what happens on interaction
  state:      StateSchema(...),          // what it remembers
  capabilityDeclarations: [...],
  provenance: PackageProvenance(...),    // which engine version made it
  integrity:  PackageIntegrity(...),     // content hash
)
```

**It is data, not code.** That is the central design decision: an Experience
cannot execute arbitrary instructions because there are none — the runtime
interprets a behaviour graph. It can therefore be validated before it runs,
versioned, revised, protected and removed completely.

## The manifest is canonical

`ExperienceManifest` is the *one* description of an Experience's identity and
capabilities. Certified by **I-60**: it is declared exactly once, and everything
that needs identity — the transport envelope, the execution contract — **embeds**
it rather than copying its fields.

```dart
ExperienceManifest(
  experienceId: 'water-tracker',
  name: 'Water Tracker',
  description: 'Logs daily water intake',
  category: 'health',
  entryPoint: 'home',               // must be a real screen id
  version: '1.0.0',
  requiredCapabilities: ['clock'],  // refused if unavailable
  optionalCapabilities: ['notifications'],
  createdAt: now, updatedAt: now,
)
```

A capability in **both** lists is a validation error, not a preference — the
Experience has not decided whether it can run without it.

## Lifecycle

| Stage | Owner | Reachable by a user |
|---|---|---|
| Create | `CreationEngine` ← `AnythingKernel` | ✅ |
| Validate | `ExperiencePackageValidator` | ✅ |
| Commit | `ExperienceCommitFramework` (transactional) | ✅ |
| Store | `SqliteExperienceRepository` | ✅ |
| Open | `ExperienceEntryPipeline` | ✅ |
| Orchestrate | `ExperienceOrchestrator` | ✅ |
| Schedule | `WorkspaceSchedulingEngine` | ✅ |
| Execute | `AnythingRuntime` | ✅ |
| Protect | `ExperienceProtectionService` | ✅ |
| Serialise | `ExperiencePackageWriter` / `Reader` | ⚠️ built, not wired to the UI |
| Install | `ExperienceInstallationFramework` | ⚠️ built, not wired |
| Distribute | `ExperienceDistributionFramework` | ⚠️ built, not wired |

The last three are why [ROADMAP](../ROADMAP.md) lists portability as the next
milestone: everything exists and is certified, and nothing calls it.

## Validating

```dart
final result = ExperiencePackageValidator.validate(package);
if (!result.isValid) print(result.errors);
```

**Do not write a second validator.** This one is canonical (I-59, I-65), and
every layer that needs structural validation delegates to it — the reader, the
installer, the verifier.

## Serialising

```dart
const writer = ExperiencePackageWriter();
const reader = ExperiencePackageReader();

final bytes  = writer.write(package);          // deterministic
final result = reader.read(bytes);

if (result.succeeded) {
  use(result.package!);
} else {
  switch (result.failure!) {
    case PackageReadFailure.malformed:               // not JSON / not an object
    case PackageReadFailure.notAPackage:             // wrong magic
    case PackageReadFailure.unsupportedFormatVersion:// newer than this build
    case PackageReadFailure.checksumMismatch:        // tampered in transit
    case PackageReadFailure.invalidPackage:          // structurally invalid
  }
}
```

**The writer is deterministic** — every map is emitted with sorted keys, so the
same package always produces byte-identical output. Lists keep their order,
because element order is data. Without that, a checksum would be meaningless.

**The reader never installs, activates or computes trust.** Parsing something
must not run it, and a well-formed package earns no authority by being
well-formed. Certified by **I-88**.

## Declaring how it runs

```dart
ExperienceExecutionContract(
  manifest: manifest,                    // embedded, not copied
  mode: ExecutionMode.background,        // a request, not a grant
  requirements: const ExecutionRequirements(requiresProtection: true),
  onInterruption: InterruptionPolicy.suspend,
)
```

**A contract declares; it never decides.** Declaring `background` does not grant
background — governance still refuses it below `local` trust. Declaring a
capability does not grant it — the capability platform still enforces. This is
because a contract travels *inside* a package, and a package is untrusted input.
Certified by **I-90**.

## Protecting

```dart
final result = await protectionService.protect(package);
// → ProtectedEnvelope { payload, seed: TimeSeed, protectedAt }
```

Recovery needs the same `TimeSeed`. See [KAALKA_GUIDE](KAALKA_GUIDE.md).

## Common mistakes

| Mistake | What happens |
|---|---|
| An `entryPoint` that names no screen | `manifestIncomplete` — there is nothing to execute |
| The same capability required *and* optional | `contradictoryCapabilities` |
| `requiredExperiences` naming itself | `circularRequirement` |
| `memoryBytes: 0` to mean "no limit" | `invalidRequirement`. Omit the field — `null` means *undeclared*, which is a different claim |
| `ExecutionMode.headless` / `.autonomous` | Refused. Reserved architecture; no runtime implements them |
| Writing a second validator or manifest | A certification test fails and names your file |

## Where to look next

| Topic | Doc |
|---|---|
| The runtime that executes it | [UNIVERSAL_EXPERIENCE_RUNTIME](architecture/UNIVERSAL_EXPERIENCE_RUNTIME.md) |
| How it gets on screen | [UNIFIED_EXPERIENCE_ENTRY_PIPELINE](architecture/UNIFIED_EXPERIENCE_ENTRY_PIPELINE.md) |
| Execution decisions | [EXPERIENCE_ORCHESTRATION](architecture/EXPERIENCE_ORCHESTRATION.md) |
| The contract in full | [EXPERIENCE_EXECUTION_CONTRACT](architecture/EXPERIENCE_EXECUTION_CONTRACT.md) |
| Who owns what | [OWNERSHIP_MATRIX](audit/OWNERSHIP_MATRIX.md) |
