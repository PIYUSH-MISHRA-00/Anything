# ARCHITECTURE CERTIFICATION (reports/final)

HEAD `b867153` (v2.0.0). Reproduced from current source + execution.

## Intended pipeline vs reality

```
USER INTENT
  → IntentUnderstanding            (kernel Step 3; optional LLM, heuristic fallback)
  → CompositeApplicationReasoner    (deterministic → model → IS-P27 best-effort fallback)
       ├─ external knowledge needed? → knowledgeNeeds → WebWeaveX loop → AI
       └─ record-shaped + no/failed provider → honest deterministic records app
  → RequirementGraph → SolutionArchitecture → AppBlueprint
  → BlueprintValidator → DesignReview → Blueprint→Spec → CapabilityResolve
  → CreationEngine → IntentPreservation + IntentContract gates
  → ExperienceCommitFramework.commit (ONE sqflite transaction)
  → (Kaalka protection: user-opt-in post-creation)
  → ExperienceHostScreen (runtime)
```

## Invariants certified

- **Single composition root** (`AppComposition.production()`); one kernel, one
  creation coordinator, one knowledge engine, one Kaalka boundary — enforced by
  `test/r46_architectural_integrity_certification_test.dart` (109 invariants).
- **WebWeaveX boundary intact**: sole `package:webweavex` importer.
- **Kaalka boundary intact**: sole `package:kaalka` importer; no parallel crypto.
- **No hardcoded weather/news API or fixed source**: see HARDCODING_AUDIT.md.
- **No domain-factory explosion**: IS-P27 derives subjects structurally.
- **Dynamic capability resolution**: capabilities resolved from the blueprint,
  not from app names.
- **Intent preservation**: `IntentPreservationValidator` + `IntentContract`
  reject semantically wrong installs before commit (e.g. stopwatch→calculator).
- **Determinism boundary**: exactly one mandatory LLM call at reasoning;
  everything after is deterministic.

## Honest deviation: AI vs deterministic generation (§1.6)

The pipeline is correct, but AI-driven generation is currently UNEXERCISABLE
because the configured Groq key returns HTTP 401. With no working provider, the
composite reasoner uses the deterministic path (IS-P27 fallback for record-shaped
domains; capability shells for calc/timer/weather/news; managed-records for
multi-entity). This produces NAMED, USABLE apps but NOT the rich domain-specific
full-stack apps AI would synthesize. Per §1.6/§26 this is classified
DETERMINISTIC_GENERATED / DEGRADED, never AI-generated PASS.

## Evidence (device, this session)
- Restaurant booking → "Restaurant Booking App" (created, usable).
- Veterinary clinic → "Veterinary Clinic Management" (created, CRUD).
- Pottery studio → "Pottery Studio Manager" ("Manage kiln scheduling and
  inventory for a pottery studio") — created, usable network shell; excellent
  name/description (intent understanding), but deterministic generic UI, not a
  kiln/inventory records model (AI would produce the latter — BLOCKED by 401).

## Verdict: architecture CONFORMS to the vision and is generic/open-world;
AI-driven generation is BLOCKED by the invalid provider key (owner action), and
is honestly reported as deterministic/degraded rather than claimed as AI PASS.
