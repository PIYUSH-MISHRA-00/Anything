# AI Provider System Architecture

## Overview

Anything uses a BYOK (Bring Your Own Key) architecture. Users configure their own AI provider credentials. No Anything server sits between the app and providers.

## Architecture

```
User configures provider in Preferences
    ↓
ProviderConfig stored locally (non-secret metadata)
    ↓
API key stored in platform secure storage
    ↓
ModelProviderRegistry resolves active provider
    ↓
ModelProvider adapter handles API communication
    ↓
Kernel uses provider for intent processing
```

## Components

### ProviderConfig
Local configuration model:
- `id`: Unique identifier
- `providerType`: "groq", "openai", etc.
- `displayName`: Human-readable name
- `endpoint`: Optional custom endpoint
- `preferredModel`: Optional model preference
- `isDefault`: Whether this is the default provider
- `isConfigured`: Whether API key is stored
- `createdAt`/`updatedAt`: Timestamps

### ModelProvider (Contract)
Abstract interface for AI providers:
- `providerId`: Provider identifier
- `providerName`: Human-readable name
- `isConfigured`: Whether ready to use
- `listModels()`: Available models
- `generate()`: Generate response
- `testConnection()`: Validate credentials
- `saveApiKey()`/`getApiKey()`/`deleteApiKey()`: Secret management

### ModelProviderRegistry
Manages multiple providers:
- Register/unregister providers
- Set/get active provider
- Manage configurations
- Resolve default provider

### GroqModelProvider (Implementation)
First production adapter:
- Wraps Groq API behind ModelProvider contract
- Uses FlutterSecureStorage for API key
- Supports model fallback
- Minimal connection test

## Security

- API keys stored in platform secure storage (FlutterSecureStorage)
- Never stored in SharedPreferences or plain SQLite
- Never logged or printed
- Never included in error messages
- Never committed to source control
- UI shows masked state ("Configured") not full keys

## Privacy

- Provider requests go directly from app to provider
- No Anything server proxy
- No telemetry
- No account required
- User controls all data
