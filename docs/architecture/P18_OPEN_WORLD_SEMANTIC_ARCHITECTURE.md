# P18 — Open-world semantic architecture

**Status:** living architecture note for P18  
**Product version:** 2.0.0+1

## Pipeline (single path)

```text
User Intent → Understanding → Reasoning → SemanticApp → Blueprint
  → Validation → ExperienceSpec → Capability Resolution → CreationEngine
  → ExperiencePackage → Package Validation → Persistence → Runtime
```

There is one Kernel creation path. Domain is data flowing through the graph,
not a branch that selects a different graph.

## Deterministic inference

Used when the prompt has enough **structure**:

- bullet / manage / with noun lists (`StructuralEntityExtractor`)
- explicit `Entity with field1, field2` clauses
- generic type cues (`quantity` → integer, `amount` → decimal, …)
- dependent-role → earlier anchor references (`schedule`, `job`, `order`, …)

It must **not** invent rich schemas for vague prompts. Vague cases escalate to
`ReasoningProviderRequired`.

### Boundary rule (P18)

Do **not** add a new domain noun to `StructuralFieldInferrer` merely to make a
new test pass. Prefer grammatical role, explicit with-clauses, type cues, or
AI reasoning.

## AI inference

When a model provider is configured, richer SemanticApps (entities, fields,
relationships, actions, views, capabilities) may come from the model.
Output is never trusted Dart — only structured semantics that must pass the
same validators as the deterministic path.

## Generic UI / runtime

`CreationEngine` + `ExperienceRenderer` consume:

- `SemanticField.type` → form controls
- entity list + searchField (+ filter/sort when capabilities requested)
- `dataMutation` behavior for CRUD
- SQLite via `ExperienceDataRuntime`

Capability shells (`News` / `Weather` / `Calculation` / `Timing` /
`NetworkReference` InterfaceFactories) remain capability-scoped, not product
domain generators.

## Fallbacks and honesty

| Situation | Expected behaviour |
|---|---|
| Structured CRUD, no AI | Deterministic SemanticApp |
| Complex semantics, AI present | Model SemanticApp + validation |
| Complex semantics, no AI | Provider required / honest failure |
| Ambiguous lexical cues vs plan | Semantic plan wins |
| Management app + “news/weather” words | Not hijacked to news/weather shells |

## External boundaries

- **WebWeaveX:** only via `lib/knowledge/webweavex_adapter.dart`
- **Kaalka:** only via the documented protection adapters/services
- Web content remains untrusted data, never instructions or capability grants

## Evidence levels

Claims must state: STATIC / UNIT / INTEGRATION / END-TO-END / DEVICE / CI /
RELEASE. Package-level green is not device certification.
