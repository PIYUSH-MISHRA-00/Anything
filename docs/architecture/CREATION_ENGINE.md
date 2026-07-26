# Creation Engine Architecture

## Overview

The Creation Engine converts ExperienceSpec + ExecutionPlan + KnowledgeBundle into an ExperiencePackage. It does NOT execute arbitrary code.

## Pipeline

```
CreationContext
  → Interface Generator
  → Behavior Generator
  → State Generator
  → Data Generator
  → Service Mapper
  → Capability Mapper
  → Package Builder
  → Validator
  → ExperiencePackage
```

## CreationContext

Contains everything needed:
- Intent
- ExperienceSpec
- ExecutionPlan
- KnowledgeBundle (optional)
- Available capabilities
- Platform context
- Security policy

## CreationResult

Typed outcomes:
- CreationReady
- CreationNeedsClarification
- CreationNeedsCredential
- CreationFailed
- CreationUnsupported

## Security

- Only trusted behavior node types allowed
- Capability allowlist enforced
- No arbitrary eval
- No downloaded code execution
- Resource limits enforced
