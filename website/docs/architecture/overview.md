# Architecture Overview

The map. Deep dives live in the repository's
[`docs/architecture/`](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/architecture) — 81 documents — and this page
indexes rather than restates them.

## The shape

```
main.dart --> AnythingApp --> AppComposition        the one composition root
                                    |
    +-----------+-----------+-------+------+------------+-----------+
    v           v           v              v            v           v
 Kernel     Capability   Storage      Experience    Workspace   Knowledge
            Platform                  frameworks     runtime
```

An intent goes into the **Kernel**, runs through nine reasoning engines, and
produces an **ExperiencePackage**. The package is committed to SQLite through a
transactional commit framework, opened through a single certified entry
pipeline, orchestrated, scheduled, and executed by a runtime that renders its
interface and interprets its behaviour graph.

## One owner per verb

| Verb | Owner |
|---|---|
| DECIDES governance | `OperatingSystemGovernanceEngine` |
| COMPUTES trust | `ExperienceTrustClassifier` |
| ENFORCES capabilities | `CapabilityPlatform` |
| DECIDES execution | `ExperienceOrchestrator` |
| SCHEDULES | `WorkspaceSchedulingEngine` |
| EXECUTES | `AnythingRuntime` |
| ENTERS / navigates | `ExperienceEntryPipeline` |
| STORES | `SqliteExperienceRepository` |
| COMMITS | `ExperienceCommitFramework` |
| SERIALISES | `ExperiencePackageWriter` / `Reader` |
| DECLARES | `ExperienceExecutionContract` |
| MOVES between devices | `ExperiencePortability` |
| PROTECTS | `ExperienceProtectionService` |

Each is certified singular. Add a second and a test fails naming your file.

Full table: [OWNERSHIP_MATRIX.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/audit/OWNERSHIP_MATRIX.md).

## Untrusted input

The same reasoning runs through three layers, and it is the most important idea
in the system:

- **reading a package does not install it** — parsing something must not run it
- **installing does not run it** — activation is a separate, deliberate act
- **declaring a capability does not grant it** — the platform enforces
- **declaring `background` does not grant it** — governance decides

A package arrives as data from somewhere else. It never earns authority by being
well-formed.

## Known debt

| Item | Detail |
|---|---|
| ~50 unreachable v1 files | A complete parallel application that cannot run. Kept because the files import each other and none is individually provably dead |
| Reachability analysis is pinned | The tooling recomputes it; the invariant checks a pinned list |
| Test flakiness (G-40) | Unresolved across five milestones |

Tracked in [REMAINING_GAP_MATRIX.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/audit/REMAINING_GAP_MATRIX.md).
