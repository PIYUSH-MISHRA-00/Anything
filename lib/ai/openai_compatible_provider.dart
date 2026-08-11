/// The one OpenAI-compatible provider adapter — Implementation
/// Specification IS-P06.
///
/// WHY ONE ADAPTER.
///
/// Groq, OpenAI, xAI, Mistral, OpenRouter, Together, Fireworks, Cerebras,
/// SambaNova, Nebius, DeepInfra, Ollama, LM Studio, LocalAI, llama.cpp and
/// vLLM all speak the same wire protocol. They differ by base URL. Writing
/// sixteen adapters would be sixteen places for the same bug.
///
/// THE BUG THIS FIXES.
///
/// `GroqModelProvider.testConnection` validated an API key by POSTing a chat
/// completion to a HARDCODED model. When Groq decommissioned that model, every
/// valid key started failing with HTTP 400 — see `GROQ_ROOT_CAUSE_ANALYSIS.md`.
///
/// Key validation here uses `GET /models`, which authenticates without naming
/// a model. A credential check that depends on a model is a credential check
/// that rots when the model list changes, and model lists change constantly.
///
/// OWNERSHIP: this class MOVES bytes and SERIALISES requests. It does not
/// classify failures (`ProviderErrors` does) and does not decide which
/// provider is active (`AnythingProviderRegistry` does).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/contracts/model_provider.dart';
import '../diagnostics/log_entry.dart';
import '../diagnostics/structured_logger.dart';
import '../security/credential_vault.dart';
import 'provider_catalogue.dart';
import 'provider_error.dart';

class OpenAiCompatibleProvider implements ModelProvider {
  final ProviderDescriptor descriptor;
  final CredentialVault _vault;
  final http.Client _client;

  /// Where this adapter reports what it did (IS-P07).
  ///
  /// Optional so that constructing a provider directly — which many tests do
  /// — needs no logging setup. Production passes the composition's one
  /// logger.
  final StructuredLogger? _logger;

  /// Distinguishes concurrent calls in the log. Per-instance and
  /// non-persistent: it correlates lines within a session, it is not an
  /// identifier anything stores.
  int _requestCounter = 0;

  String _nextRequestId() => '${descriptor.id}-${++_requestCounter}';

  /// Overrides [ProviderDescriptor.baseUrl] for providers whose address the
  /// user supplies (local servers, custom endpoints).
  final String? endpointOverride;

  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _testTimeout = Duration(seconds: 15);

  OpenAiCompatibleProvider({
    required this.descriptor,
    CredentialVault? credentialVault,
    http.Client? client,
    this.endpointOverride,
    StructuredLogger? logger,
  }) : _vault = credentialVault ?? CredentialVault(),
       _client = client ?? http.Client(),
       _logger = logger;

  @override
  String get providerId => descriptor.id;

  @override
  String get providerName => descriptor.name;

  /// Credentials are namespaced per provider, so configuring OpenAI cannot
  /// overwrite a Groq key.
  String get _keyPurpose => '${descriptor.id}_api_key';

  String? _cachedApiKey;

  /// The in-flight or completed keystore read.
  ///
  /// IS-P07: this was a `bool _primed` set BEFORE the read. If the read never
  /// completed — a real possibility, since a platform channel with no
  /// implementation behind it does not throw, it simply never answers — the
  /// provider was permanently marked primed with a null key, so a configured
  /// provider reported `isConfigured == false` for the rest of the session.
  /// Holding the future instead means an abandoned read is retried and
  /// concurrent callers share one read.
  Future<void>? _priming;

  /// The base URL actually in use.
  ///
  /// Throws rather than guessing: a local server has no sensible default from
  /// a phone's point of view, and inventing `localhost` would point the
  /// request at the handset itself.
  String get baseUrl {
    final url = endpointOverride?.trim().isNotEmpty == true
        ? endpointOverride!.trim()
        : descriptor.baseUrl;
    if (url == null || url.isEmpty) {
      throw ProviderException(
        ProviderFailure.incorrectEndpoint,
        '${descriptor.name} needs an endpoint address before it can be used.',
      );
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  @override
  bool get isConfigured =>
      !descriptor.requiresApiKey || (_cachedApiKey?.isNotEmpty ?? false);

  /// Loads the stored key into the cache.
  ///
  /// IS-P06: `isConfigured` is a SYNCHRONOUS getter on the contract, but the
  /// key lives in the platform keystore behind an async read. Before this,
  /// nothing populated the cache at startup, so `isConfigured` reported
  /// `false` for a provider whose key was sitting in the keystore — the app
  /// could not tell it was configured until something happened to call
  /// `getApiKey()`. The registry primes every provider on load.
  Future<void> prime() => _priming ??= _readStoredKey();

  Future<void> _readStoredKey() async {
    try {
      _cachedApiKey = await _vault.get(_keyPurpose);
    } catch (_) {
      // A keystore that cannot be read must not stop the app starting.
    }
  }

  Map<String, String> _headers(String? apiKey, {bool json = false}) => {
    if (descriptor.requiresApiKey && apiKey != null && apiKey.isNotEmpty)
      'Authorization': 'Bearer $apiKey',
    if (json) 'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // -------------------------------------------------------------- validation

  @override
  /// Validates a credential WITHOUT naming a model.
  ///
  /// The contract returns `bool`, so callers above are unchanged. `false`
  /// means exactly one thing — the key was rejected. Every other outcome
  /// throws a [ProviderException] carrying a sentence the user can act on.
  Future<bool> testConnection(String apiKey) async {
    final key = apiKey.trim();
    if (descriptor.requiresApiKey && key.isEmpty) {
      throw const ProviderException(
        ProviderFailure.missingApiKey,
        'No API key was entered.',
      );
    }

    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$baseUrl/models'), headers: _headers(key))
          .timeout(_testTimeout);
    } on ProviderException {
      rethrow;
    } catch (e) {
      throw ProviderErrors.fromException(e, providerName: descriptor.name);
    }

    if (response.statusCode == 200) {
      // A 200 from something that is not an OpenAI-compatible API (a captive
      // portal, a proxy login page) would otherwise read as success.
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['data'] is! List) {
          throw const ProviderException(
            ProviderFailure.incorrectEndpoint,
            'That address answered, but not like an OpenAI-compatible API. '
            'Check the endpoint URL.',
          );
        }
      } on ProviderException {
        rethrow;
      } catch (_) {
        throw const ProviderException(
          ProviderFailure.incorrectEndpoint,
          'That address answered, but not like an OpenAI-compatible API. '
          'Check the endpoint URL.',
        );
      }
      return true;
    }

    if (response.statusCode == 401) return false;

    throw ProviderErrors.fromResponse(
      statusCode: response.statusCode,
      body: response.body,
      providerName: descriptor.name,
    );
  }

  // ---------------------------------------------------------------- discovery

  @override
  /// Lists hosted models.
  ///
  /// IS-P06: this used to be wrapped in `catch (_) {}` returning `[]`, so a
  /// rejected key and a provider with no models looked identical. It now
  /// throws a classified failure; the caller decides how to present it.
  Future<List<ModelInfo>> listModels() async {
    final apiKey = await getApiKey();
    if (descriptor.requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
      throw const ProviderException(
        ProviderFailure.missingApiKey,
        'Add an API key before listing models.',
      );
    }

    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$baseUrl/models'), headers: _headers(apiKey))
          .timeout(_testTimeout);
    } on ProviderException {
      rethrow;
    } catch (e) {
      throw ProviderErrors.fromException(e, providerName: descriptor.name);
    }

    if (response.statusCode != 200) {
      throw ProviderErrors.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
        providerName: descriptor.name,
      );
    }

    try {
      final data = jsonDecode(response.body) as Map;
      final entries = (data['data'] as List).whereType<Map>();
      final models = <ModelInfo>[
        for (final m in entries)
          if (m['id'] is String)
            ModelInfo(
              id: m['id'] as String,
              name: m['id'] as String,
              provider: descriptor.id,
              contextWindow: _asInt(m['context_window'] ?? m['context_length']),
            ),
      ];
      models.sort((a, b) => a.id.compareTo(b.id));
      return models;
    } catch (e) {
      throw ProviderErrors.fromException(
        FormatException('Model list could not be read: $e'),
        providerName: descriptor.name,
      );
    }
  }

  static int? _asInt(Object? v) => v is int ? v : null;

  // --------------------------------------------------------------- generation

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    final requestId = _nextRequestId();
    final started = Stopwatch()..start();

    final apiKey = await getApiKey();
    if (descriptor.requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
      _logger?.error(
        LogCategory.aiProvider,
        'generation failed before sending: no API key for ${descriptor.name}',
        requestId: requestId,
      );
      throw ProviderException(
        ProviderFailure.missingApiKey,
        'Add a ${descriptor.name} API key in Settings before creating '
        'anything.',
      );
    }

    final modelId = request.modelId ?? descriptor.defaultModel;
    if (modelId == null || modelId.isEmpty) {
      _logger?.error(
        LogCategory.aiProvider,
        'generation failed before sending: no model chosen for '
        '${descriptor.name}',
        requestId: requestId,
      );
      throw ProviderException(
        ProviderFailure.missingModel,
        'Choose a model for ${descriptor.name} in Settings first.',
      );
    }

    _logger?.info(
      LogCategory.aiProvider,
      'generation requested: ${descriptor.name}/$modelId, '
      '${request.messages.length} message(s)',
      requestId: requestId,
    );

    final http.Response response;
    try {
      // Host only, never the path with any query, and never the key.
      _logger?.debug(
        LogCategory.aiProvider,
        'POST ${Uri.parse(baseUrl).host}/chat/completions',
        requestId: requestId,
      );
      response = await _client
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: _headers(apiKey, json: true),
            body: jsonEncode({
              'model': modelId,
              'messages': [
                for (final m in request.messages)
                  {'role': m.role, 'content': m.content},
              ],
              if (request.maxTokens != null) 'max_tokens': request.maxTokens,
              if (request.temperature != null)
                'temperature': request.temperature,
            }),
          )
          .timeout(request.timeout ?? _timeout);
    } on ProviderException {
      rethrow;
    } catch (e) {
      final classified = ProviderErrors.fromException(
        e,
        providerName: descriptor.name,
      );
      _logger?.error(
        LogCategory.aiProvider,
        'generation failed after ${started.elapsedMilliseconds}ms: '
        '${classified.failure.name}',
        requestId: requestId,
      );
      throw classified;
    }

    if (response.statusCode != 200) {
      // IS-P06: the previous implementation retried EVERY non-200 against a
      // hardcoded fallback model. That turned one rejected key into two
      // rejected requests and surfaced the SECOND failure, hiding the real
      // cause. Errors are now reported as they happen.
      final classified = ProviderErrors.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
        providerName: descriptor.name,
      );
      _logger?.error(
        LogCategory.aiProvider,
        'generation failed after ${started.elapsedMilliseconds}ms: '
        'HTTP ${response.statusCode}, ${classified.failure.name}',
        requestId: requestId,
      );
      throw classified;
    }

    try {
      final data = jsonDecode(response.body) as Map;
      final text =
          ((data['choices'] as List).first as Map)['message']['content']
              as String;
      final usage = data['usage'];
      final modelUsage = usage is Map
          ? ModelUsage(
              promptTokens: _asInt(usage['prompt_tokens']) ?? 0,
              completionTokens: _asInt(usage['completion_tokens']) ?? 0,
              totalTokens: _asInt(usage['total_tokens']) ?? 0,
            )
          : null;
      _logger?.info(
        LogCategory.aiProvider,
        'generation complete in ${started.elapsedMilliseconds}ms, '
        '${text.length} chars'
        '${modelUsage == null ? '' : ', ${modelUsage.totalTokens} tokens'}',
        requestId: requestId,
      );
      return ModelResponse(text: text, modelId: modelId, usage: modelUsage);
    } catch (e) {
      _logger?.error(
        LogCategory.aiProvider,
        'generation failed: the response could not be read',
        requestId: requestId,
      );
      throw ProviderErrors.fromException(
        FormatException('Response could not be read: $e'),
        providerName: descriptor.name,
      );
    }
  }

  /// Streams a completion as server-sent events.
  ///
  /// IS-P07 made this real. It previously awaited [generate] and yielded the
  /// whole answer as a single event, which satisfies the type and none of the
  /// point: there was no first-token latency to observe and nothing to cancel
  /// early.
  ///
  /// HONEST SCOPE. Nothing in the creation pipeline consumes this yet, and
  /// that is deliberate rather than unfinished. Intent understanding and
  /// application reasoning both parse a COMPLETE JSON document; showing a
  /// user half-formed JSON as it arrives would be worse than a progress
  /// indicator, not better. This exists so that a consumer which genuinely
  /// benefits — a conversational surface, a long-form explanation — has a
  /// correct implementation to call rather than a stub to discover.
  @override
  Stream<String> generateStream(ModelRequest request) async* {
    final requestId = _nextRequestId();
    final started = Stopwatch()..start();

    final apiKey = await getApiKey();
    if (descriptor.requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
      throw ProviderException(
        ProviderFailure.missingApiKey,
        'Add a ${descriptor.name} API key in Settings before creating '
        'anything.',
      );
    }

    final modelId = request.modelId ?? descriptor.defaultModel;
    if (modelId == null || modelId.isEmpty) {
      throw ProviderException(
        ProviderFailure.missingModel,
        'Choose a model for ${descriptor.name} in Settings first.',
      );
    }

    final httpRequest =
        http.Request('POST', Uri.parse('$baseUrl/chat/completions'))
          ..headers.addAll(_headers(apiKey, json: true))
          ..body = jsonEncode({
            'model': modelId,
            'stream': true,
            'messages': [
              for (final m in request.messages)
                {'role': m.role, 'content': m.content},
            ],
            if (request.maxTokens != null) 'max_tokens': request.maxTokens,
            if (request.temperature != null) 'temperature': request.temperature,
          });

    final http.StreamedResponse response;
    try {
      _logger?.info(
        LogCategory.aiProvider,
        'streaming started: ${descriptor.name}/$modelId',
        requestId: requestId,
      );
      response = await _client
          .send(httpRequest)
          .timeout(request.timeout ?? _timeout);
    } on ProviderException {
      rethrow;
    } catch (e) {
      _logger?.error(
        LogCategory.aiProvider,
        'streaming failed to start',
        requestId: requestId,
      );
      throw ProviderErrors.fromException(e, providerName: descriptor.name);
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      final classified = ProviderErrors.fromResponse(
        statusCode: response.statusCode,
        body: body,
        providerName: descriptor.name,
      );
      _logger?.error(
        LogCategory.aiProvider,
        'streaming rejected: HTTP ${response.statusCode}, '
        '${classified.failure.name}',
        requestId: requestId,
      );
      throw classified;
    }

    var chunks = 0;

    // `yield*` rather than `await for`. The difference is cancellation, and it
    // is not cosmetic: an `async*` generator suspended at an `await` — which
    // is exactly where an `await for` sits between server-sent events — does
    // not act on `cancel()` until that await completes. A caller abandoning a
    // stalled generation would have held the socket open until the provider
    // sent another byte or the timeout expired. Delegating with `yield*`
    // forwards the cancel to the response stream immediately.
    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .takeWhile((line) => !_isTerminator(line))
        .map(_deltaFrom)
        .where((delta) => delta != null && delta.isNotEmpty)
        .cast<String>()
        .map((delta) {
          chunks++;
          return delta;
        });

    _logger?.info(
      LogCategory.aiProvider,
      'streaming finished in ${started.elapsedMilliseconds}ms, '
      '$chunks chunk(s)',
      requestId: requestId,
    );
  }

  /// The end-of-stream sentinel is a literal, not JSON.
  static bool _isTerminator(String line) =>
      line.startsWith('data:') && line.substring(5).trim() == '[DONE]';

  /// The text carried by one server-sent event, or null if it carries none.
  ///
  /// Returns null rather than throwing for malformed frames: providers emit
  /// keep-alive and metadata frames, and one unreadable event must not abort a
  /// transfer that is otherwise producing usable output.
  static String? _deltaFrom(String line) {
    if (!line.startsWith('data:')) return null;
    final payload = line.substring(5).trim();
    if (payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      final choices = decoded is Map ? decoded['choices'] : null;
      final first = choices is List && choices.isNotEmpty
          ? choices.first
          : null;
      final content = first is Map ? (first['delta']?['content']) : null;
      return content is String ? content : null;
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------- credentials

  @override
  Future<void> saveApiKey(String apiKey) async {
    // Cache first so Test / model refresh can use the key even when the
    // Android keystore is wedged (vault save would otherwise block BYOK).
    _cachedApiKey = apiKey;
    _priming = Future<void>.value();
    await _vault.save(_keyPurpose, apiKey);
  }

  @override
  Future<String?> getApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey;
    await prime();
    return _cachedApiKey;
  }

  @override
  Future<void> deleteApiKey() async {
    await _vault.delete(_keyPurpose);
    _cachedApiKey = null;
    _priming = Future<void>.value();
  }
}
