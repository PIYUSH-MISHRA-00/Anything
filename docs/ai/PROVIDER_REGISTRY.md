# Provider Registry

The declared catalogue. Source: `lib/ai/provider_catalogue.dart`.

## Status meanings

| Status | Meaning |
|---|---|
| **Available** | Adapter exists **and** has been exercised against a live account |
| **Experimental** | Adapter exists and the protocol matches; not verified against a live account by the maintainers |
| **Coming soon** | Declared deliberately, not implemented, with a stated reason |

The distinction between Available and Experimental is deliberate. Every
OpenAI-compatible provider below *should* work through the same adapter, but
"should" is not "was observed to", and the catalogue does not blur the two.

## Commercial

| Provider | Status | Endpoint | Default model |
|---|---|---|---|
| **Groq** | **Available** (verified) | `api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| OpenAI | Experimental | `api.openai.com/v1` | `gpt-4o-mini` |
| xAI | Experimental | `api.x.ai/v1` | `grok-2-latest` |
| Mistral AI | Experimental | `api.mistral.ai/v1` | `mistral-small-latest` |
| Anthropic | Coming soon | — | — |
| Google Gemini | Coming soon | — | — |
| Cohere | Coming soon | — | — |

## Open-weight / hosted

| Provider | Status | Endpoint |
|---|---|---|
| OpenRouter | Experimental | `openrouter.ai/api/v1` |
| Together AI | Experimental | `api.together.xyz/v1` |
| Fireworks AI | Experimental | `api.fireworks.ai/inference/v1` |
| Cerebras | Experimental | `api.cerebras.ai/v1` |
| SambaNova | Experimental | `api.sambanova.ai/v1` |
| Nebius AI Studio | Experimental | `api.studio.nebius.ai/v1` |
| DeepInfra | Experimental | `api.deepinfra.com/v1/openai` |
| Hugging Face | Coming soon | — |

## Local / self-hosted

All require the user to supply an address, and none requires an API key.

| Provider | Status |
|---|---|
| Ollama | Experimental |
| LM Studio | Experimental |
| LocalAI | Experimental |
| llama.cpp | Experimental |
| vLLM | Experimental |

**No local provider has a default endpoint.** `localhost` from a phone means
the phone, not the computer running the server, so a default would send every
request to the handset. The user enters their machine's address on the
network.

**No local provider has a default model** either: what is loaded is unknown
ahead of time, and guessing is the exact failure this milestone fixed. Use
"Refresh list".

## Generic

| Provider | Status | Notes |
|---|---|---|
| OpenAI-compatible endpoint | Experimental | Any service implementing the OpenAI chat-completions API |

## Why four are deferred

| Provider | Reason |
|---|---|
| **Anthropic** | The Messages API is not OpenAI-compatible: system prompts sit outside the message list and the response shape differs |
| **Google Gemini** | Uses `generateContent` with its own request shape and passes the key as a query parameter |
| **Cohere** | The v2 Chat API differs from the OpenAI shape |
| **Hugging Face** | The router needs a provider chosen per model, and its model listing is not the OpenAI `/models` shape |

Each is a contained piece of work: one class implementing `ModelProvider`.

## Declared metadata

Per provider: id, name, category, status, auth method, base URL, endpoint
requirement, key requirement, default model, summary, console URL, key hint,
unavailable reason, verified flag, and capability flags (model discovery,
streaming, tools, vision, embeddings, audio, image generation, local
execution).

**Capability flags are protocol-level facts**, not per-model matrices. Whether
a *particular model* has vision is a property of the model; discovery is the
authority. A hardcoded per-model matrix would be wrong within a month — the
same rot that produced this milestone's defect.
