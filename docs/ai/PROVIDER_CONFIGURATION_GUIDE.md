# Provider Configuration Guide

For contributors. The user-facing version is `USER_GUIDE_AI_PROVIDERS.md`.

## Where things live

| Item | Store | Key |
|---|---|---|
| Configurations | `DurableCollectionStore` | `anything.provider_configs` |
| Active provider | `DurableCollectionStore` | `anything.active_provider` |
| Model cache | `DurableCollectionStore` | `anything.provider_models` |
| **API keys** | **`CredentialVault`** (keystore) | `credential_<id>_api_key` |

Keys are namespaced per provider, so configuring OpenAI cannot overwrite a
Groq key.

## `ProviderConfig`

| Field | Purpose |
|---|---|
| `id` | UUID for this configuration |
| `providerType` | Catalogue id (`groq`, `ollama`, …) |
| `displayName` | Editable label |
| `endpoint` | Address; required for local/custom |
| `preferredModel` | Chosen model |
| `isDefault` / `isConfigured` | Selection and readiness |
| `createdAt` / `updatedAt` | Timestamps |
| **`lastValidatedAt`** | When the key last passed a test — `null` means never tested, which differs from tested-and-failed |
| **`lastFailureReason`** | Message from the most recent failed test, cleared on success |

`fromJson` tolerates configurations written before IS-P06: absent fields read
as `null`, so an existing install upgrades rather than losing its provider. A
test pins this.

`copyWith` takes `clearFailureReason: true` because `null` means "unchanged"
everywhere else, and a success must be able to *remove* a stale message.

## Lifecycle

```
createConfig(descriptor)      -> unconfigured row, endpoint/model prefilled
  saveApiKey(key)             -> keystore
  testProvider(id, key)       -> GET /models
  recordTestResult(...)       -> stamps lastValidatedAt or lastFailureReason
saveConfig(isConfigured:true) -> persisted; becomes active if none is
deleteConfig(id)              -> removes config AND key; reassigns active
```

Deleting removes the stored key. Leaving an orphaned credential for a provider
the user just deleted is residue a privacy-focused app must not create.

## Resolving the active provider

At launch `initialize()` runs and:

1. loads configurations
2. reads the stored active provider id
3. if absent or stale, derives it — the default configured one, else the first
4. primes every provider so `isConfigured` reflects the keystore

Step 3 matters: before IS-P06 nothing set the active provider at all, so a
configured key was never used. Step 4 matters because `isConfigured` is a
synchronous getter over an async keystore read.

`_ensureLoaded` holds the **in-flight future**, not a bool. A bool set on entry
let a second caller return while `_configs` was still empty.

## Local and custom providers

Providers needing a user-supplied address are **not** registry singletons — the
address is part of the configuration. `providerForConfig(config)` builds one
bound to that endpoint. Test with `config:` so the draft address is used rather
than the saved one.

## Adding a provider

See `AI_PROVIDER_PLATFORM.md`. If it is OpenAI-compatible: add a catalogue row.

## Testing

`test/p06_provider_platform_test.dart` — 33 tests. Use `MockClient` from
`package:http/testing.dart` for transport, and mock the
`plugins.it_nomads.com/flutter_secure_storage` channel for the keystore.
