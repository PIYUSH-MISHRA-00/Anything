# Model Discovery

## Why this exists

Anything shipped with a hardcoded model ID. Groq retired it. Every valid API
key then failed. See `GROQ_ROOT_CAUSE_ANALYSIS.md`.

Hardcoded model IDs are the most perishable value in an AI integration. This
document is about not depending on them.

## The endpoint

`GET {baseUrl}/models` with the same Bearer token. Response:

```json
{"object": "list", "data": [{"id": "llama-3.3-70b-versatile"}, ...]}
```

`OpenAiCompatibleProvider.listModels()` reads `data[].id`, sorts, and returns
`ModelInfo`. Entries without a string `id` are skipped rather than throwing —
providers add fields freely.

## The same call validates the key

`testConnection` uses `GET /models` too. It authenticates, names no model, and
cannot be broken by a retirement.

It also checks the response *shape*. A captive portal answers 200 with an HTML
login page; without the shape check that reads as a working key. A 200 whose
body is not `{"data": [...]}` is reported as an endpoint problem.

## Caching

Cached per provider under `anything.provider_models`.

**Deliberately not time-expiring.** A stale list is visibly refreshable, and
silently re-fetching on a timer spends a user's rate limit without them asking.
Refresh is a button.

The sheet loads the cache on open, so it appears instantly and an offline user
still sees what they had.

## Manual entry always available

The model field is **free text**, with discovered models as tappable chips
beside it. Discovery can fail — no network, a key without listing permission, a
server that does not implement `/models` — and a user who knows the model ID
must never be blocked by that.

This is a deliberate rejection of a dropdown-only picker.

## Refresh saves the key first

Discovery authenticates. Refreshing with an unsaved key would report a rejected
credential for a key that is merely untyped-into-storage, so `_refreshModels`
saves first.

## Defaults

| Provider kind | Default model |
|---|---|
| Hosted, known catalogue | A current production model (Groq: `llama-3.3-70b-versatile`) |
| Local / custom | **None** — the user must choose |

A test enforces that any implemented provider without a default supports
discovery, so there is always a way to find one.

## What is not built

- **No per-model capability data.** `/models` rarely reports context window,
  vision or tool support consistently. `ProviderCapabilities` therefore records
  protocol-level facts only. Claiming per-model capabilities from an
  inconsistent field is how a matrix goes stale.
- **No automatic model migration.** When a model is retired the user is told,
  in those words, and chooses. Silently substituting a model changes cost and
  behaviour without consent.
- **No streaming.** The runtime consumes whole responses;
  `capabilities.streaming` records that the protocol supports it.
