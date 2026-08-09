# AI Provider Platform

How Anything talks to AI providers, and how to add one.

## The shape

```
Kernel / capabilities
        |
        v
ModelProviderRegistry          <- contract (core/contracts/model_provider.dart)
        |
AnythingProviderRegistry       <- decides which provider is active
        |
        +-- ProviderCatalogue       DECLARES  (lib/ai/provider_catalogue.dart)
        +-- OpenAiCompatibleProvider MOVES    (lib/ai/openai_compatible_provider.dart)
        +-- ProviderErrors           CLASSIFIES (lib/ai/provider_error.dart)
        +-- CredentialVault          STORES keys (platform keystore)
        +-- DurableCollectionStore   STORES config (the one prefs owner)
```

Each part has one verb. The catalogue never performs I/O. The adapter never
classifies errors. The classifier never retries. The registry never builds
HTTP requests.

## One adapter, not twenty

Groq's base URL is `https://api.groq.com/openai/v1`. Groq, OpenAI, xAI,
Mistral, OpenRouter, Together, Fireworks, Cerebras, SambaNova, Nebius,
DeepInfra, Ollama, LM Studio, LocalAI, llama.cpp and vLLM all speak the same
OpenAI-compatible wire protocol. **They differ by base URL, not by code.**

So `OpenAiCompatibleProvider` serves all of them, parameterised by a
`ProviderDescriptor`. Sixteen adapters would have been sixteen copies of the
same bug — which is not hypothetical: the single hardcoded model ID inside the
old Groq-specific adapter is what broke every valid key.

`GroqModelProvider` still exists as a named class, because the R1 composition
root test refers to it and its credential purpose (`groq_api_key`) must not
change. It carries no implementation.

## Adding a provider

**If it is OpenAI-compatible — add a row. No new class.**

```dart
static const ProviderDescriptor example = ProviderDescriptor(
  id: 'example',                       // stable; persisted in configuration
  name: 'Example AI',
  category: ProviderCategory.openWeight,
  status: ProviderStatus.experimental,
  auth: ProviderAuth.bearerToken,
  baseUrl: 'https://api.example.com/v1',
  defaultModel: 'example-8b',
  summary: 'One sentence a user reads before pasting a secret.',
  consoleUrl: 'https://example.com/keys',
);
```

Then add it to `ProviderCatalogue.all`. The registry instantiates it, the
settings screen lists it, search and grouping pick it up, and the tests cover
it. Nothing else needs editing.

**If it is not OpenAI-compatible** (Anthropic, Gemini, Cohere, Hugging Face),
write a class implementing `ModelProvider` and register it in the registry
constructor. Until then, declare it with `ProviderStatus.comingSoon` and a
real `unavailableReason` — a test fails if that reason is missing, so a
deferred provider can never become unexplained dead UI.

## Ownership rules

| Concern | Owner | Never |
|---|---|---|
| Which providers exist | `ProviderCatalogue` | performs I/O |
| Which provider is active | `AnythingProviderRegistry` | builds requests |
| HTTP requests | `OpenAiCompatibleProvider` | classifies failures |
| Failure meaning | `ProviderErrors` | retries or performs I/O |
| API keys | `CredentialVault` (keystore) | written to preferences |
| Configuration | `DurableCollectionStore` | holds a key |

**An API key never enters `DurableCollectionStore`.** Configuration and
credentials have separate stores with separate threat models.

## Compatibility

**WebWeaveX** is untouched. It handles knowledge extraction and
normalisation and never sees a provider.

**Kaalka** is untouched. Protection encrypts an Experience with a time key and
is independent of which provider created it. A protected Experience made with
one provider opens with another configured, or none.

## Invariants worth keeping

1. Key validation never names a model.
2. A failed request is not retried against a different model.
3. A deferred provider carries a reason.
4. A provider claiming `available` has been verified against a live endpoint.
5. A provider with no default model must support discovery.
6. Raw HTTP status codes never reach the user.
