# Execution Plan

## Overview

ExecutionPlan represents HOW Anything intends to satisfy an ExperienceSpec. It is a typed, validated plan — not executable code.

## Structure

- Plan ID and version
- Reference to ExperienceSpec
- Ordered steps with dependencies
- Validation before acceptance

## ExecutionStep

Each step has:
- Step ID (unique)
- Type (resolve, obtain, prepare, validate, persist, launch)
- Dependencies on other steps
- Required capability IDs
- Network requirement
- Permission requirements
- Failure policy
- Status

## Validation

Plans must pass deterministic validation:
- No duplicate step IDs
- All dependencies exist
- No circular dependencies
- Required capabilities available
- Versions supported
