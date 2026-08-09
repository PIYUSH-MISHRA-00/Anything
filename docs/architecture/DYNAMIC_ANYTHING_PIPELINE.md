# Dynamic Anything Pipeline

Canonical flow for prompt → protected persistent Experience:

```text
Prompt
 ↓
Intent
 ↓
Requirements (capabilities, data needs, calculation mode, …)
 ↓
Capability Graph / inferrer
 ↓
Provider / Source Resolution
 ↓
WebWeaveX  |  structured providers  |  compute  |  storage
 ↓
Structured Data (+ provenance)
 ↓
Experience Spec / Package (interface, behavior, state, services)
 ↓
Validation (semantic completeness, intent preservation)
 ↓
Runtime (renderer + behavior interpreter + sessions)
 ↓
Kaalka Protection (when classified / requested)
 ↓
Persistence / Export (.anything)
```

## Calculation path

```text
intent / capability ids
 → CalculationSpec.resolve
 → CalculationInterfaceFactory (pad from operations)
 → CalculationSession (generic ops, including scientific unary)
 → ExperienceRenderer (calculationPad)
```

## Image path

```text
structured record.imageUrl  (or state binding)
 → RemoteImageUrl.sanitize
 → InterfaceNode type remoteImage | image
 → Image.network with loading / error placeholders
```

## Import path

```text
picker (withData: true)
 → PickedFile.bytes | path
 → readPickedText
 → package reader validate
 → install
```
