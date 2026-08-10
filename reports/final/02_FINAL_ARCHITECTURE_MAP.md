# 02 — Final Architecture Map

## Production pipeline

```
User prompt
  → Composer / Home UI
  → CreationCoordinator + IntentContract
  → Kernel / intent understanding
  → CompositeApplicationReasoner
       ├─ DeterministicReasoner (capability shells, managed records)
       └─ ModelApplicationReasoner (when AI provider configured)
  → Synthesis → ExperiencePackage
  → Engineering / Validation
  → Persistence (SqliteExperienceRepository)
  → Runtime / ExperienceHost / ExperienceRenderer
```

## Bounded subsystems

| Subsystem | Placement | Role |
| --- | --- | --- |
| WebWeaveX | Under **Knowledge** (`lib/knowledge/webweavex_adapter.dart`) | Acquisition / HTML / document IR only |
| Kaalka | Under **Protection** (`KaalkaProtectionProvider` → `KaalkaService` → `package:kaalka`) | Experience protect/recover crypto |
| Governance | OS decision layer (`OperatingSystemGovernanceEngine`) | Policy decisions only — not a second runtime/platform |

## Forbidden crossings

- WebWeaveX must not own Kaalka or become weather/news.
- Governance must not become scheduler, storage, or capability platform.
