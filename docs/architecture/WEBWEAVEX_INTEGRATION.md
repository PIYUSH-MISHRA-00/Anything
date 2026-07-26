# WebWeaveX Integration

## Overview

Anything uses the published `webweavex` Dart package (v3.0.0) as the canonical knowledge extraction library.

## Package

- **Package**: `webweavex` on pub.dev
- **Version**: ^3.0.0 (verified from pub.dev)
- **License**: Apache License 2.0
- **Dependencies**: crypto, http, kaalka, unorm_dart
- **Platforms**: Linux, macOS, Windows, Web, Mobile

## Architecture

```
Kernel
→ KnowledgeRequirement
→ KnowledgeAcquisitionEngine
→ KnowledgeProvider
→ WebWeaveXKnowledgeProvider
→ package:webweavex
→ WebWeaveX
```

Only the WebWeaveX adapter (`lib/knowledge/webweavex_adapter.dart`) imports `package:webweavex/...`.

The Kernel, UI, ExperienceSpec, and ExecutionPlan do NOT import WebWeaveX.

## What WebWeaveX Is

WebWeaveX is deterministic runtime cognition infrastructure — NOT a web scraper. It captures runtime state, not just HTML content. Core capabilities include:

- Runtime graph construction
- Replay equivalence
- Memory fabric
- Kaalka v5 crypto
- Deterministic serialization
- Runtime normalization
- Repository analysis
- Workflow execution
- Runtime reconstruction

## Integration Strategy

For Stage 5, we use WebWeaveX's deterministic serialization and runtime graph capabilities for knowledge normalization and caching. The full extraction pipeline integration is deferred to when specific knowledge acquisition requirements are implemented.

## Constraints

- WebWeaveX failure does not break Anything
- No arbitrary code execution
- Source code remains non-executable
- Prompt-injection trust boundary maintained
- Local/private network retrieval blocked by default
