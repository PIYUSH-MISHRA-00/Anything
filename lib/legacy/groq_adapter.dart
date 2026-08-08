/// Groq adapter — wraps legacy GroqService behind ModelProvider contract.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/contracts/model_provider.dart';
import '../security/credential_vault.dart';

/// Groq API configuration.
class _GroqConfig {
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String modelsEndpoint = '$baseUrl/models';
  static const String chatEndpoint = '$baseUrl/chat/completions';
  static const String defaultMainModel = 'openai/gpt-oss-120b';
  static const String defaultFallbackModel = 'gemma2-9b-it';
  static const Duration defaultTimeout = Duration(seconds: 30);
}

/// Groq implementation of the [ModelProvider] contract.
class GroqModelProvider implements ModelProvider {
  final CredentialVault _credentialVault;
  static const String _apiKeyPurpose = 'groq_api_key';

  /// [credentialVault] routes credential storage through the canonical,
  /// purpose-scoped `CredentialVault` (Implementation Milestone R1).
  /// REALITY before R1: this class read/wrote a raw `FlutterSecureStorage`
  /// key (`GROQ_API_KEY`) directly — MIS-1 Part 2/3 identified this as the
  /// one live credential-storage mechanism bypassing the already-correct
  /// `CredentialVault`. Migration note: an API key saved before R1 was
  /// stored under the raw key `GROQ_API_KEY`; after R1 it is stored under
  /// `CredentialVault`'s namespaced key (`credential_$_apiKeyPurpose`).
  /// This repository has never been tagged/released (pubspec.yaml still
  /// carries Flutter's template `1.0.0+1`, per MIS-1 Part 1), so no
  /// production credential exists to migrate; a real release would need a
  /// one-time read-old-key-if-new-key-absent migration, out of scope here.
  GroqModelProvider({CredentialVault? credentialVault})
    : _credentialVault = credentialVault ?? CredentialVault();

  @override
  String get providerId => 'groq';

  @override
  String get providerName => 'Groq';

  @override
  bool get isConfigured => _cachedApiKey != null;

  String? _cachedApiKey;

  @override
  Future<List<ModelInfo>> listModels() async {
    final apiKey = await getApiKey();
    if (apiKey == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse(_GroqConfig.modelsEndpoint),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['data'] as List)
            .map(
              (m) => ModelInfo(
                id: m['id'],
                name: m['id'],
                provider: 'groq',
                modalities: [ModelModality.text],
              ),
            )
            .toList();
        return models;
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not configured.');
    }

    final modelId = request.modelId ?? _GroqConfig.defaultMainModel;
    final messages = request.messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    Future<http.Response> attempt(String model) {
      return http.post(
        Uri.parse(_GroqConfig.chatEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'model': model, 'messages': messages}),
      );
    }

    var response = await attempt(
      modelId,
    ).timeout(request.timeout ?? _GroqConfig.defaultTimeout);

    bool usedFallback = false;
    if (response.statusCode != 200) {
      response = await attempt(
        _GroqConfig.defaultFallbackModel,
      ).timeout(request.timeout ?? _GroqConfig.defaultTimeout);
      usedFallback = true;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['choices'][0]['message']['content'] as String;
      final usage = data['usage'] != null
          ? ModelUsage(
              promptTokens: data['usage']['prompt_tokens'] ?? 0,
              completionTokens: data['usage']['completion_tokens'] ?? 0,
              totalTokens: data['usage']['total_tokens'] ?? 0,
            )
          : null;

      return ModelResponse(
        text: text,
        usage: usage,
        modelId: usedFallback ? _GroqConfig.defaultFallbackModel : modelId,
        usedFallback: usedFallback,
      );
    } else {
      throw Exception('Failed to generate response: ${response.body}');
    }
  }

  @override
  Stream<String> generateStream(ModelRequest request) async* {
    final response = await generate(request);
    yield response.text;
  }

  @override
  /// IS-P05 finding 5 — WHY "Test Connection" APPEARED NOT TO VALIDATE.
  ///
  /// This method used to end in `catch (_) { return false; }`, so a rejected
  /// key, an expired key, a rate limit, a DNS failure, a timeout and an
  /// aeroplane-mode phone ALL produced the same bare `false`. The registry
  /// then rendered one message -- "Invalid API key or configuration" -- which
  /// was frequently untrue and never actionable. The validation worked; the
  /// reporting made it useless.
  ///
  /// The contract still returns `bool`, so nothing above changes shape.
  /// `false` now means exactly one thing: THE KEY WAS REJECTED. Everything
  /// else THROWS, and `AnythingProviderRegistry.testProvider` turns the
  /// exception into a sentence a person can act on.
  Future<bool> testConnection(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw const FormatException('No API key was entered.');
    }

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_GroqConfig.chatEndpoint),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _GroqConfig.defaultFallbackModel,
              'messages': [
                {'role': 'user', 'content': 'Reply with: OK'},
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const SocketException(
        'The provider did not respond within 15 seconds.',
      );
    }

    switch (response.statusCode) {
      case 200:
        return true;
      // The only case that genuinely means "this key is not accepted".
      case 401:
      case 403:
        return false;
      case 429:
        throw const HttpException(
          'Rate limited by the provider. Wait a moment and try again.',
        );
      default:
        throw HttpException(
          'The provider returned HTTP ${response.statusCode}.',
        );
    }
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    await _credentialVault.save(_apiKeyPurpose, apiKey);
    _cachedApiKey = apiKey;
  }

  @override
  Future<String?> getApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey;
    _cachedApiKey = await _credentialVault.get(_apiKeyPurpose);
    return _cachedApiKey;
  }

  @override
  Future<void> deleteApiKey() async {
    await _credentialVault.delete(_apiKeyPurpose);
    _cachedApiKey = null;
  }
}
