/// Groq adapter.
///
/// IS-P06: THIS CLASS NO LONGER CONTAINS AN IMPLEMENTATION.
///
/// It used to carry its own HTTP client, its own error handling and its own
/// hardcoded model IDs. That is precisely how the reported defect arose: the
/// key-validation path POSTed a chat completion to a hardcoded
/// `gemma2-9b-it`, Groq decommissioned that model on 2025-10-08, and from
/// that day every valid API key failed "Test Connection" with HTTP 400. See
/// `GROQ_ROOT_CAUSE_ANALYSIS.md`.
///
/// Groq's API is served at `https://api.groq.com/openai/v1` — it is
/// OpenAI-compatible. So Groq is now a ROW IN THE CATALOGUE served by the one
/// `OpenAiCompatibleProvider`, exactly like the other fifteen
/// OpenAI-compatible providers. There is no Groq-specific request code left to
/// rot.
///
/// The class name survives because `AnythingProviderRegistry` and the R1
/// composition-root test refer to it, and because the credential purpose it
/// implies (`groq_api_key`) is unchanged — a rename would strand every key
/// already in a user's keystore.
library;

import 'package:http/http.dart' as http;

import '../ai/openai_compatible_provider.dart';
import '../ai/provider_catalogue.dart';
import '../security/credential_vault.dart';

/// Groq, bound to the shared OpenAI-compatible adapter.
///
/// [credentialVault] routes credential storage through the canonical,
/// purpose-scoped `CredentialVault` (Implementation Milestone R1) rather than
/// a raw secure-storage key. Keys saved before R1 lived under `GROQ_API_KEY`;
/// this repository has never been released, so no production credential needs
/// migrating.
class GroqModelProvider extends OpenAiCompatibleProvider {
  // ignore: use_super_parameters
  GroqModelProvider({CredentialVault? credentialVault, http.Client? client})
    : super(
        descriptor: ProviderCatalogue.groq,
        credentialVault: credentialVault,
        client: client,
      );
}
