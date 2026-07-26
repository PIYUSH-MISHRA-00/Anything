/// Provider registry implementation.
///
/// Manages multiple AI providers and their configurations.
/// Resolves the active provider from local configuration.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/contracts/model_provider.dart';
import '../legacy/groq_adapter.dart';

/// Concrete implementation of [ModelProviderRegistry].
class AnythingProviderRegistry implements ModelProviderRegistry {
  final FlutterSecureStorage _secureStorage;
  final Map<String, ModelProvider> _providers = {};
  final Map<String, ProviderConfig> _configs = {};
  String? _activeProviderId;

  AnythingProviderRegistry({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    // Register built-in providers
    final groq = GroqModelProvider(secureStorage: _secureStorage);
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
