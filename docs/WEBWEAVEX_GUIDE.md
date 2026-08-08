# WebWeaveX Integration Guide

[`package:webweavex`](https://pub.dev/packages/webweavex) provides Anything's
knowledge layer: semantic extraction from web content, plus deterministic
canonicalisation.

Runnable: [`examples/webweavex_knowledge`](../examples/webweavex_knowledge).

---

## The boundary

```
KnowledgeAcquisitionEngine     ← never imports package:webweavex
          │
   WebWeaveXAdapter            ← the ONE importer
          │
   package:webweavex
```

**Exactly one file imports it**: `lib/knowledge/webweavex_adapter.dart`.

| Invariant | Enforces |
|---|---|
| **I-21b** | Only the adapter imports `package:webweavex` |
| **I-21d** | The knowledge engine reaches canonical representations only through the adapter |
| **I-21e** | WebWeaveX's runtime graph is never adopted — Anything has its own World Model |

## What is used

Five symbols, all inside the adapter:

| Symbol | Purpose |
|---|---|
| `wwx.renderPage` | fetch a page (injectable, so tests never touch the network) |
| `wwx.extractSemanticHtml` | semantic HTML extraction |
| `wwx.extractSemanticContent` | semantic content extraction |
| `wwx.normalizeRuntimeValue` | deterministic normalisation of titles and content |
| `wwx.stableSerialize` | canonical representation → identity and cache keys |

## Why determinism matters here

The last two are load-bearing rather than cosmetic.

Before IS-R47, canonically-equivalent knowledge did **not** deduplicate —
identical content acquired twice produced different ids. Routing identity
through `stableSerialize` fixed it, and IS-R48 built persistence on top:
canonical ids, hashes and representations are proven **byte-identical across a
genuine app restart**, and a re-extraction in a new session matches the restored
value.

That last property is what proves identity is *canonical* rather than merely
round-tripped.

## Utilisation status

| # | Capability | Status |
|---|---|---|
| **W-1** | Deterministic normalisation | **DONE** (R47) — 15 behavioural tests |
| **W-5** | Cross-restart persistence | **DONE** (R48) |
| W-2 | Replay equivalence for acquisition | Open, low value |
| W-3 | WebWeaveX runtime graph / memory fabric | **Rejected, and enforced** — would create a second graph alongside the World Model |
| W-4 | Kaalka routed via WebWeaveX | **Rejected, and enforced** — would create a second protection path |

W-3 and W-4 are unusual and worth noting: the decision *not* to adopt a
capability is as mechanically certified as the decision to adopt one (I-21e).

Full matrix: [`docs/audit/WEBWEAVEX_USAGE_MATRIX.md`](audit/WEBWEAVEX_USAGE_MATRIX.md).

## Retention

Acquired knowledge is bounded by `RetentionPolicyEngine` (R50): **500 entries,
20 MB, 30 days**. The knowledge cache asks the engine which keys to drop; the
repository owns no policy of its own (I-47).

## A limitation worth knowing

Fetching needs network access. Before IS-P01 the release manifest declared no
`INTERNET` permission, so `wwx.renderPage` **would have failed on every real
device** — the code was correct and the app could not reach the network. Fixed
in IS-P01; mentioned because it is the kind of failure that looks like a library
problem and is not.

There is still **no defined offline behaviour** beyond a failed fetch. That is a
real open gap.

## Contributing here

- **Never** add a `package:webweavex` import outside the adapter.
- Inject `fetchPage` in tests — production defaults to `wwx.renderPage`, and no
  test should touch the network.
- Do not adopt W-3 or W-4. Both rejections are enforced by I-21e, and a PR
  attempting either will fail certification.
