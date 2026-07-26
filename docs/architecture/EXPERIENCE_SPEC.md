# Experience Specification

## Overview

ExperienceSpec is the canonical typed specification for what an Experience must contain. It is technology-independent — describing requirements semantically, not implementation details.

## Key Principles

- Implementation-independent
- Versioned from v1
- Supports full-stack experiences
- Separates UI from logic from data
- Distinguishes local vs network requirements

## Fields

| Field | Purpose |
|-------|---------|
| specVersion | Schema version for migration |
| name | Human-readable name |
| description | What the Experience does |
| category | Classification (tool, productivity, etc.) |
| interactionModel | How user interacts |
| uiRequirements | Semantic UI needs |
| functionalRequirements | What it must do |
| stateRequirements | State management needs |
| storageRequirements | Data persistence needs |
| networkRequirements | Network needs |
| backendClassification | Service execution type |
| requiredCapabilities | Needed capabilities |
| protectionRequirements | Security needs |
| offlineBehavior | Offline capability |
