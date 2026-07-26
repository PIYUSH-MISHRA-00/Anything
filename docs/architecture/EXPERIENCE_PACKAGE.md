# Experience Package Format

## Overview

ExperiencePackage is the canonical format for generated applications in Anything. It is versioned, portable, and machine-validatable.

## Structure

```
ExperiencePackage
├── Manifest (identity, metadata, capabilities)
├── Interface (declarative UI)
├── Behavior (declarative logic graph)
├── State (state variables)
├── Data (persistence schema)
├── Services (service definitions)
├── Network (declarations)
├── Capabilities (declarations)
├── Permissions (declarations)
├── Protection (metadata)
├── Provenance (source tracking)
└── Integrity (hash)
```

## Key Principles

- Not just UI — represents complete applications
- Versioned for migration
- Technology-independent
- Deterministic serialization
- Integrity hashing
- No arbitrary code execution
