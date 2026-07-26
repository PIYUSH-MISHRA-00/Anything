# Knowledge Engine Architecture

## Overview

The Knowledge Engine acquires, normalizes, and caches external knowledge for Anything's creation pipeline.

## Components

### KnowledgeAcquisitionEngine
Orchestrates the full pipeline:
1. Query planning
2. Provider selection
3. Retrieval
4. Normalization
5. Provenance
6. Trust classification
7. License metadata
8. Deduplication
9. Ranking
10. Caching

### KnowledgeResource
Normalized representation of an external resource with:
- Resource type
- Provenance (source URL, domain, timestamp, provider)
- Trust metadata (level, reason, confidence)
- License metadata (policy, source, confidence)
- Freshness metadata
- Ranking metadata

### KnowledgeBundle
Grouped resources satisfying requirements:
- Bundle ID and status
- Resources list
- Requirements satisfied/unresolved
- Warnings

### KnowledgeCache
Local bounded cache for acquired knowledge metadata.

## Trust Model

Resources are classified as:
- OFFICIAL: Official documentation
- HIGH_CONFIDENCE: Trusted sources
- COMMUNITY: Community resources
- UNKNOWN: Unverifiable sources
- UNTRUSTED: Potentially hostile

## License Policy

- PERMISSIVE_KNOWN
- ATTRIBUTION_REQUIRED
- COPYLEFT_REVIEW_REQUIRED
- RESTRICTED_OR_INCOMPATIBLE
- UNKNOWN_REVIEW_REQUIRED

## Security

- All web resources are untrusted data
- Prompt-injection defense documented
- Unsafe URLs rejected
- Local/private network blocked by default
- Source code non-executable
