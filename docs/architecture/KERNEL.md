# Kernel Architecture

## Overview

The Kernel is the intelligence and orchestration authority of Anything. It processes user Intents through a structured pipeline to produce typed outcomes.

## Pipeline

```
Intent → Classification → Experience Resolution → Understanding →
Ambiguity Check → Specification → Capability Resolution →
Plan Building → Validation → Kernel Outcome
```

## Responsibilities

- Classify intent category
- Check for existing experiences
- Produce structured intent understanding
- Evaluate ambiguities
- Build ExperienceSpec
- Resolve capabilities
- Build ExecutionPlan
- Validate plan structure
- Return typed outcomes

## Trust Boundaries

- User Intent is untrusted input
- Model output is untrusted — parsed defensively
- Kernel never renders UI
- Kernel never accesses SQLite directly
- Kernel never depends on specific providers
- Kernel never depends on Kaalka, WebWeaveX, or Flutter widgets

## Provider Interaction

```
Kernel → ModelProviderRegistry → configured ModelProvider → structured interpretation
```

If no provider exists, Kernel returns typed ProviderRequired outcome.

## Experience Resolution

Checks existing experiences before creating new ones. Uses ExperienceRepository.

## Ambiguity Handling

Classifies ambiguities as:
- SAFE_TO_ASSUME: use smart defaults
- USER_INPUT_REQUIRED: ask via ClarificationRequest
- CRITICAL: cannot proceed

## Plan Validation

Validates:
- Unique step IDs
- Dependencies exist
- No cycles
- Capabilities available
- Spec/plan versions supported
