/// Model Provider abstraction for Anything v2.
///
/// This boundary ensures that business logic never requires
/// a specific AI provider (Groq, OpenAI, Gemini, etc.).
///
/// Flow:
///   Kernel -> ModelProvider -> Provider Adapter -> [Groq | OpenAI | Gemini | ...]
///
/// Provider implementations depend on contracts.
/// Contracts do not depend on provider implementations.
library;

import 'dart:async';

/// Supported model modalities.
enum ModelModality { text, vision, audio, multimodal }

/// A message in a conversation with an AI model.
class ModelMessage {
  /// Role: "system", "user", "assistant".
  final String role;

  /// Message content.
  final String content;

  const ModelMessage({required this.role, required this.content});

  const ModelMessage.system(this.content) : role = 'system';

  const ModelMessage.user(this.content) : role = 'user';

  const ModelMessage.assistant(this.content) : role = 'assistant';
}

/// Configuration for a model generation request.
class ModelRequest {
  /// The messages to send.
  final List<ModelMessage> messages;

  /// The model ID (provider-specific).
  final String? modelId;

  /// Maximum tokens to generate.
  final int? maxTokens;

  /// Temperature (0.0 to 2.0).
  final double? temperature;

  /// Whether to stream the response.
  final bool stream;

  /// Timeout for the request.
  final Duration? timeout;

  const ModelRequest({
    required this.messages,
    this.modelId,
    this.maxTokens,
    this.temperature,
    this.stream = false,
    this.timeout,
  });
}

/// The response from an AI model.
class ModelResponse {
  /// The generated text.
  final String text;

  /// Token usage information.
  final ModelUsage? usage;

  /// The model that was actually used.
  final String? modelId;

  /// Whether the response was from a fallback model.
  final bool usedFallback;

  const ModelResponse({
    required this.text,
    this.usage,
    this.modelId,
    this.usedFallback = false,
  });
}

/// Token usage information.
class ModelUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const ModelUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
}

/// Information about an available model.
class ModelInfo {
  final String id;
  final String name;
  final String provider;
  final List<ModelModality> modalities;
  final int? contextWindow;
  final int? maxOutputTokens;
  final bool isAvailable;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.provider,
    this.modalities = const [ModelModality.text],
    this.contextWindow,
    this.maxOutputTokens,
    this.isAvailable = true,
  });
}

/// Abstract interface for AI model providers.
///
/// Implementations wrap specific provider APIs (Groq, OpenAI, etc.)
/// behind this contract so that business logic never depends on
/// a specific provider.
abstract class ModelProvider {
  /// Provider identifier (e.g., "groq", "openai", "gemini").
  String get providerId;

  /// Human-readable provider name.
  String get providerName;

  /// Whether this provider is currently configured and available.
  bool get isConfigured;

  /// List available models from this provider.
  Future<List<ModelInfo>> listModels();

  /// Generate a response from the model.
  Future<ModelResponse> generate(ModelRequest request);

  /// Stream a response from the model.
  Stream<String> generateStream(ModelRequest request);

  /// Test the provider connection with the given API key.
  Future<bool> testConnection(String apiKey);

  /// Save the API key for this provider.
  Future<void> saveApiKey(String apiKey);

  /// Get the stored API key (if any).
  Future<String?> getApiKey();

  /// Delete the stored API key.
  Future<void> deleteApiKey();
}

/// Configuration for a provider stored locally.
class ProviderConfig {
  final String id;
  final String providerType;
  final String displayName;
  final String? endpoint;
  final String? preferredModel;
  final bool isDefault;
  final bool isConfigured;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// IS-P06 — when this configuration last passed a connection test.
  ///
  /// `null` means never tested, which is DIFFERENT from tested-and-failed and
  /// is shown differently. A key can stop working without the app touching it
  /// (revoked, expired, out of credit), so "configured" alone was never
  /// enough to tell the user whether it still works.
  final DateTime? lastValidatedAt;

  /// IS-P06 — the message from the most recent failed test, cleared on
  /// success. Kept so the user can come back to the screen and still see WHY
  /// it failed rather than only that it did.
  final String? lastFailureReason;

  const ProviderConfig({
    required this.id,
    required this.providerType,
    required this.displayName,
    this.endpoint,
    this.preferredModel,
    this.isDefault = false,
    this.isConfigured = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastValidatedAt,
    this.lastFailureReason,
  });

  /// IS-P05: additive serialisation so provider configuration can be
  /// PERSISTED. Before this, `AnythingProviderRegistry` held configs in a
  /// plain in-memory Map, so a configured provider vanished on every app
  /// restart -- which is a large part of why the AI provider never appeared
  /// to stay configured.
  Map<String, dynamic> toJson() => {
    'id': id,
    'providerType': providerType,
    'displayName': displayName,
    'endpoint': endpoint,
    'preferredModel': preferredModel,
    'isDefault': isDefault,
    'isConfigured': isConfigured,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastValidatedAt': lastValidatedAt?.toIso8601String(),
    'lastFailureReason': lastFailureReason,
  };

  /// Tolerant of configurations written before IS-P06 added the validation
  /// fields: absent keys read as `null`, so an existing install upgrades
  /// rather than losing its provider.
  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
    id: json['id'] as String,
    providerType: json['providerType'] as String,
    displayName: json['displayName'] as String,
    endpoint: json['endpoint'] as String?,
    preferredModel: json['preferredModel'] as String?,
    isDefault: json['isDefault'] == true,
    isConfigured: json['isConfigured'] == true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    lastValidatedAt: switch (json['lastValidatedAt']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    lastFailureReason: json['lastFailureReason'] as String?,
  );

  ProviderConfig copyWith({
    String? id,
    String? providerType,
    String? displayName,
    String? endpoint,
    String? preferredModel,
    bool? isDefault,
    bool? isConfigured,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastValidatedAt,
    String? lastFailureReason,

    /// A successful test must be able to REMOVE a stale failure message.
    /// `copyWith(lastFailureReason: null)` cannot express that, because null
    /// means "unchanged" everywhere else in this method.
    bool clearFailureReason = false,
  }) {
    return ProviderConfig(
      id: id ?? this.id,
      providerType: providerType ?? this.providerType,
      displayName: displayName ?? this.displayName,
      endpoint: endpoint ?? this.endpoint,
      preferredModel: preferredModel ?? this.preferredModel,
      isDefault: isDefault ?? this.isDefault,
      isConfigured: isConfigured ?? this.isConfigured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      lastFailureReason: clearFailureReason
          ? null
          : (lastFailureReason ?? this.lastFailureReason),
    );
  }
}

/// Abstract interface for managing multiple model providers.
abstract class ModelProviderRegistry {
  /// Get the currently active provider.
  ///
  /// Synchronous, so it reports only what the registry has already loaded.
  /// `AnythingProviderRegistry` resolves this from stored configuration by an
  /// async read, so the application awaits `initialize()` at the launch gate
  /// (`_AnythingRoot`) BEFORE any consumer exists — see IS-P07. Nothing on
  /// this interface can enforce that, which is why the gate does.
  ModelProvider? get activeProvider;

  /// Set the active provider by ID.
  Future<void> setActiveProvider(String providerId);

  /// List all registered providers.
  List<ModelProvider> get providers;

  /// Register a new provider.
  void registerProvider(ModelProvider provider);

  /// Get a provider by ID.
  ModelProvider? getProvider(String providerId);

  /// List all provider configurations.
  Future<List<ProviderConfig>> listConfigs();

  /// Save a provider configuration.
  Future<void> saveConfig(ProviderConfig config);

  /// Delete a provider configuration.
  Future<void> deleteConfig(String id);

  /// Get the default provider.
  Future<ProviderConfig?> getDefaultConfig();
}
