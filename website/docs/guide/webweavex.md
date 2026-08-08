# WebWeaveX

[`package:webweavex`](https://pub.dev/packages/webweavex) is Anything's
knowledge layer: semantic extraction from web content, plus deterministic
canonicalisation.

Full guide:
[WEBWEAVEX_GUIDE.md](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/WEBWEAVEX_GUIDE.md).

## One adapter, certified

```
KnowledgeAcquisitionEngine   ← never imports package:webweavex
        │
   WebWeaveXAdapter          ← the ONE importer
        │
   package:webweavex
```

Exactly one file imports it. This is enforced by a test, not by convention —
add an import elsewhere and certification fails and names your file.

## Why determinism is load-bearing

Anything routes knowledge **identity** through `stableSerialize`, not just
content. Before that, canonically-equivalent knowledge did not deduplicate:
identical content acquired twice produced different ids.

Today canonical ids, hashes and representations are proven **byte-identical
across a genuine app restart**, and a re-extraction in a new session matches the
restored value — which is what proves identity is canonical rather than merely
round-tripped.

## Retention

Acquired knowledge is bounded: 500 entries, 20 MB, 30 days. The cache asks the
one retention engine which keys to drop; the repository owns no policy of its
own.

## What is deliberately NOT adopted

Two WebWeaveX capabilities are **rejected, and the rejection is enforced in
code**:

- its **runtime graph** — Anything has its own World Model, and adopting a
  second graph would be exactly the parallel architecture this project spends
  its effort preventing
- **Kaalka routed through WebWeaveX** — would create a second protection path

The decision *not* to adopt a capability is as certified as the decision to
adopt one. That is unusual, and deliberate.

## Known gap

There is **no defined offline behaviour** beyond a failed fetch. For a mobile
product that is a real gap, and it is open.
