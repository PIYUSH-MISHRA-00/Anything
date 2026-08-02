/// Provider registry implementation.
///
/// Manages multiple AI providers and their configurations.
/// Resolves the active provider from local configuration.
library;

import 'package:uuid/uuid.dart';

import '../core/contracts/model_provider.dart';
import '../legacy/groq_adapter.dart';
import '../security/credential_vault.dart';

/// Concrete implementation of [ModelProviderRegistry].
class AnythingProviderRegistry implements ModelProviderRegistry {
  final Map<String, ModelProvider> _providers = {};
  final Map<String, ProviderConfig> _configs = {};
  String? _activeProviderId;

  /// [credentialVault] is the canonical, shared credential store
  /// (Implementation Milestone R1) — routed to every built-in provider
  /// that needs one, rather than each provider constructing its own raw
  /// secure-storage instance (MIS-1 Part 2/3's "BYOK Assessment").
  AnythingProviderRegistry({CredentialVault? credentialVault}) {
    final vault = credentialVault ?? CredentialVault();
    // Register built-in providers
    final groq = GroqModelProvider(credentialVault: vault);
    _providers[groq.providerId] = groq;
  }

  @override
  ModelProvider? get activeProvider {
    if (_activeProviderId == null) return null;
    return _providers[_activeProviderId];
  }

  @override
  Future<void> setActiveProvider(String providerId) async {
    if (!_providers.containsKey(providerId)) return;
    _activeProviderId = providerId;
  }

  @override
  List<ModelProvider> get providers => _providers.values.toList();

  @override
  void registerProvider(ModelProvider provider) {
    _providers[provider.providerId] = provider;
  }

  @override
  ModelProvider? getProvider(String providerId) {
    return _providers[providerId];
  }

  @override
  Future<List<ProviderConfig>> listConfigs() async {
    return _configs.values.toList();
  }

  @override
  Future<void> saveConfig(ProviderConfig config) async {
    _configs[config.id] = config;
  }

  @override
  Future<void> deleteConfig(String id) async {
    _configs.remove(id);
  }

  @override
  Future<ProviderConfig?> getDefaultConfig() async {
    for (final config in _configs.values) {
      if (config.isDefault) return config;
    }
    return _configs.values.isNotEmpty ? _configs.values.first : null;
  }

  /// Create a new Groq provider configuration.
  Future<ProviderConfig> createGroqConfig({
    String? displayName,
    String? preferredModel,
  }) async {
    final config = ProviderConfig(
      id: const Uuid().v4(),
      providerType: 'groq',
      displayName: displayName ?? 'Groq',
      preferredModel: preferredModel,
      isDefault: _configs.isEmpty,
      isConfigured: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
    return config;
  }

  /// Test a provider connection.
  Future<ProviderTestResult> testProvider(
    String providerId,
    String apiKey,
  ) async {
    final provider = _providers[providerId];
    if (provider == null) {
      return ProviderTestResult(success: false, message: 'Unknown provider');
    }

    try {
      final success = await provider.testConnection(apiKey);
      if (success) {
        return ProviderTestResult(
          success: true,
          message: 'Connection successful',
        );
      } else {
        return ProviderTestResult(
          success: false,
          message: 'Invalid API key or configuration',
        );
      }
    } catch (e) {
      return ProviderTestResult(
        success: false,
        message: 'Connection failed: ${e.toString()}',
      );
    }
  }
}

/// Result of a provider connection test.
class ProviderTestResult {
  final bool success;
  final String message;

  const ProviderTestResult({required this.success, required this.message});
}
