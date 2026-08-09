# Groq Root Cause Analysis — IS-P06

**Reported:** a fresh, valid Groq API key fails "Test Connection" with HTTP 400.

**Verdict:** the key was never the problem. **Anything validated the key by
asking Groq to run a model that Groq had retired.**

---

## The one-line cause

`GroqModelProvider.testConnection` validated an API key by POSTing a **chat
completion** to a **hardcoded model ID**, and that model —
`gemma2-9b-it` — was **decommissioned by Groq on 2025-10-08**.

Groq answers a request for a decommissioned model with **HTTP 400** and
`"code": "model_decommissioned"`. Anything's error handling had cases for
401, 403 and 429, and sent everything else to a default branch that printed
the status code. So a valid key produced:

> The provider returned HTTP 400.

Which is true, useless, and reads as though the key is at fault.

---

## The evidence, in order

### 1. What the code sent

`lib/legacy/groq_adapter.dart` before this milestone:

```dart
static const String defaultFallbackModel = 'gemma2-9b-it';
...
Future<bool> testConnection(String apiKey) async {
  response = await http.post(
    Uri.parse(_GroqConfig.chatEndpoint),        // /chat/completions
    headers: {'Authorization': 'Bearer ${apiKey.trim()}', ...},
    body: jsonEncode({
      'model': _GroqConfig.defaultFallbackModel,   // <-- gemma2-9b-it
      'messages': [{'role': 'user', 'content': 'Reply with: OK'}],
    }),
  ).timeout(const Duration(seconds: 15));

  switch (response.statusCode) {
    case 200: return true;
    case 401: case 403: return false;
    case 429: throw const HttpException('Rate limited...');
    default:  throw HttpException('The provider returned HTTP ${response.statusCode}.');
  }
}
```

Every element of the request was investigated. All of them were correct:

| Element | Value | Verdict |
|---|---|---|
| Endpoint | `https://api.groq.com/openai/v1/chat/completions` | ✅ correct |
| Method | POST | ✅ correct for chat completions |
| Authorization | `Bearer <key>`, single space, trimmed | ✅ correct |
| Content-Type | `application/json` | ✅ correct |
| Body | `{"model": ..., "messages":[{"role":"user","content":...}]}` | ✅ well-formed |
| TLS | default Dart/Android trust store | ✅ correct — a TLS fault throws, not 400 |
| Timeout | 15 s | ✅ adequate |
| **Model** | **`gemma2-9b-it`** | ❌ **decommissioned** |

**Exactly one element was wrong, and it was the one that had to change over
time.**

### 2. What Groq says

From Groq's own deprecation documentation, fetched during this milestone:

> `gemma2-9b-it` — deprecated 2025-10-08, **shutdown 10/08/25**.
> Recommended replacement: **`llama-3.1-8b-instant`**.
> "The newer Llama 3.1 8B model delivers exceptional price-performance at the
> same speed as the Gemma 2 9B model."

And on the resulting error: a request for a decommissioned model returns
**HTTP 400** with error code **`model_decommissioned`**.

Sources:
[Model Deprecations](https://console.groq.com/docs/deprecations) ·
[Supported Models](https://console.groq.com/docs/models)

`openai/gpt-oss-120b` — the *main* model — is still live, which is why the
failure looked confined to connection testing.

### 3. Reproduced in a test

`test/p06_provider_platform_test.dart` feeds the classifier the exact body
Groq returns:

```json
{"error":{"message":"The model `gemma2-9b-it` has been decommissioned and is
no longer supported. ...","type":"invalid_request_error",
"code":"model_decommissioned"}}
```

Before: `default:` → `"The provider returned HTTP 400."`
After: `ProviderFailure.modelDecommissioned` → *"That model has been retired
by Groq and no longer accepts requests. Choose a current model — your API key
is fine."*

### 4. Confirmed against the live API on the device

A real call to `https://api.groq.com/openai/v1/models` from the moto g45 5G
with a deliberately invalid key returned **401**, and the app said:

> That key was rejected by the provider. Check you copied all of it, and that
> it has not been revoked.

That single result proves the endpoint, DNS, TLS, Bearer format and error
classification are all correct on the new path.

---

## The deeper fault

Fixing the model ID alone would have fixed the symptom and left the defect.

**Validating a credential should never depend on a model existing.** A model
ID is the most perishable value in an AI integration — providers retire them
on a schedule. Coupling key validation to one guarantees that key validation
breaks on that schedule, in a way that blames the user.

OpenAI-compatible APIs expose `GET /models`, which:

- authenticates with the same Bearer token
- names no model
- returns the model list, so it doubles as discovery
- cannot rot when a model is retired

**Key validation now uses `GET /models`.** A test pins this:

```dart
expect(requests.single.method, 'GET');
expect(requests.single.url.path, endsWith('/models'));
expect(requests.single.url.path, isNot(contains('chat/completions')),
    reason: 'validating a key must not depend on a model');
```

---

## Three further defects found while investigating

### A. `generate()` retried every failure against the same dead model

```dart
if (response.statusCode != 200) {
  response = await attempt(_GroqConfig.defaultFallbackModel);  // gemma2-9b-it
  usedFallback = true;
}
```

The fallback was **the decommissioned model**. So real generation had the same
bug, and worse: a 401 triggered a second request, and the error surfaced was
the *second* failure — masking the real cause. Retry-on-any-error is removed;
failures are reported as they occur.

### B. `listModels()` swallowed every error

```dart
} catch (_) {}
return [];
```

A rejected key and a provider with no models were indistinguishable. It now
throws a classified failure.

### C. **The active provider was never set** — the most severe finding

`setActiveProvider` was implemented on `AnythingProviderRegistry` and called
**from nowhere in `lib/`** — only from test doubles. `_activeProviderId`
therefore stayed `null` for the entire lifetime of every session, so
`activeProvider` always returned `null`.

Consequences:

| Consumer | Behaviour |
|---|---|
| `ModelProviderAiAdapter.generate` | always threw "No active AI provider configured" |
| `ModelUnderstandingService.understand` | silently fell through to heuristic understanding |

**A user could enter a perfectly valid key and Anything would still never call
a model.** The IS-P05 device screenshot recorded this in plain sight —
Developer Mode read "Groq registered / none active" — and it was not
recognised at the time.

The active provider is now resolved at launch, derived from configuration when
nothing is stored, and persisted.

A related lie: `isConfigured` reads a cache populated only by an async keystore
read that nothing performed at startup, so it reported `false` for a provider
whose key was in the keystore. Providers are now primed on load.

---

## What shipped

| Change | Effect |
|---|---|
| Validation via `GET /models` | Key checking cannot be broken by a retired model |
| Default model `llama-3.3-70b-versatile` | A current production model |
| `ProviderErrors` taxonomy | 14 named failures, each with an actionable sentence |
| No blind fallback retry | The real error is the one reported |
| Active provider resolved and persisted | A configured key is actually used |
| Providers primed at load | `isConfigured` tells the truth |

## What is still unverified

**A valid Groq key returning 200 has not been observed**, because this
milestone had no live key. The 401 path was confirmed against the real API;
the 200 path is covered by unit tests only. It is the first item on the manual
checklist.
