# Dynamic Ownership Matrix

Canonical owners for the Anything dynamic generation / acquisition / protection stack.
One owner per concern — duplicates are architectural defects.

| Concern | Owner | Path / boundary |
|---|---|---|
| Intent | Intent pipeline / Universal Intent Router | `lib/core/contracts/intent.dart`, intent pipeline |
| Planning | Kernel + synthesis / blueprint | Kernel planning + `AppBlueprint` |
| Capabilities | Capability inferrer + registry | `lib/creation/app_capabilities.dart`, `lib/capabilities/` |
| Source discovery | SearchProvider (query → candidate URLs) | Knowledge acquisition path |
| Web extraction | WebWeaveX via adapter only | `WebWeaveXAdapter` → `package:webweavex` |
| Schema mapping | Acquisition / knowledge normalization after extraction | Knowledge resource → structured result |
| Knowledge | KnowledgeAcquisitionEngine | Canonical knowledge engine (do not fork) |
| Reasoning | Kernel reasoning / corroboration | Existing multi-source path |
| Rendering | ExperienceRenderer + RuntimeComponentRegistry | `lib/runtime/experience_renderer.dart` |
| Runtime | AnythingRuntime + behavior interpreter | `lib/runtime/` |
| Storage | File / persistence capabilities | FileService, experience data store |
| Protection | Kaalka via ProtectionService | `ExperienceProtectionService` → Kaalka provider |
| Portability | ExperiencePortability + package reader/writer | `.anything` codec |

## Explicit non-owners

- UI widgets must not call Kaalka or WebWeaveX directly.
- Domain product names (weather/news/calculator) are **not** ownership axes.
- Weather/news structured services are **provider adapters** satisfying data requirements, not generation templates.
- Custom encryption outside Kaalka is forbidden at the Experience protection boundary.
