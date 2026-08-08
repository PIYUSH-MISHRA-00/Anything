/// Provider registry implementation.
///
/// Manages multiple AI providers and their configurations.
/// Resolves the active provider from local configuration.
library;

import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../core/contracts/model_provider.dart';
import '../legacy/groq_adapter.dart';
import '../security/credential_vault.dart';
import '../storage/durable_collection_store.dart';

/// Concrete implementation of [ModelProviderRegistry].
class AnythingProviderRegistry implements ModelProviderRegistry {
  final Map<String, ModelProvider> _providers = {};
  final Map<String, ProviderConfig> _configs = {};
  String? _activeProviderId;

  /// IS-P05: configuration is now DURABLE.
  ///
  /// It lived in the in-memory `_configs` map alone, so a provider configured
  /// by the user disappeared on the next app start. Persistence goes through
  /// `DurableCollectionStore` -- the ONE SharedPreferences owner (IS-R56) --
  /// rather than a second storage path.
  ///
  /// Only configuration is stored here. THE API KEY IS NOT: that stays in
  /// `CredentialVault`, backed by the platform keystore.
  final DurableCollectionStore _store;
  static const String _storageKey = 'anything.provider_configs';
  bool _loaded = false;

  /// [credentialVault] is the canonical, shared credential store
  /// (Implementation Milestone R1) — routed to every built-in provider
  /// that needs one, rather than each provider constructing its own raw
  /// secure-storage instance (MIS-1 Part 2/3's "BYOK Assessment").
  AnythingProviderRegistry({
    CredentialVault? credentialVault,
    DurableCollectionStore store = const DurableCollectionStore(),
  }) : _store = store {
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

  /// Reads persisted configuration once per instance, then serves from memory.
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read(_storageKey);
      if (raw == null || raw.isEmpty) return;
      for (final j in (jsonDecode(raw) as List)) {
        final c = ProviderConfig.fromJson(j as Map<String, dynamic>);
        _configs[c.id] = c;
      }
    } catch (_) {
      // Corrupt or unreadable configuration must not stop the app starting.
      // The user simply sees no providers and can add one again.
    }
  }

  Future<void> _persist() async {
    try {
      // `update` is the store's only write path (IS-R56): it reads and writes
      // inside one critical section, so a concurrent save cannot interleave.
      await _store.update<void>(
        _storageKey,
        (_) => (
          value: jsonEncode([for (final c in _configs.values) c.toJson()]),
          result: null,
        ),
      );
    } catch (_) {
      // Best effort: failing to persist must not lose the in-memory state the
      // user is currently looking at.
    }
  }

  @override
  Future<List<ProviderConfig>> listConfigs() async {
    await _ensureLoaded();
    return _configs.values.toList();
  }

  @override
  Future<void> saveConfig(ProviderConfig config) async {
    await _ensureLoaded();
    _configs[config.id] = config;
    await _persist();
  }

  @override
  Future<void> deleteConfig(String id) async {
    await _ensureLoaded();
    final removed = _configs.remove(id);
    if (removed == null) return;

    // Removing a configuration must remove its key too. Leaving an orphaned
    // credential in the keystore for a provider the user just deleted is
    // exactly the kind of residue a privacy-focused app must not create.
    try {
      await _providers[removed.providerType]?.deleteApiKey();
    } catch (_) {
      // The config is gone either way; a keystore failure must not block it.
    }
    await _persist();
  }

  @override
  Future<ProviderConfig?> getDefaultConfig() async {
    await _ensureLoaded();
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

    // IS-P05 finding 5. `testConnection` now returns `false` for exactly one
    // reason -- the key was rejected -- and throws for everything else, so
    // these messages can finally be specific. Before, every failure collapsed
    // into "Invalid API key or configuration", which was often wrong and never
    // told the user what to do.
    try {
      final accepted = await provider.testConnection(apiKey);
      return accepted
          ? const ProviderTestResult(
              success: true,
              message: 'Connected. This key works.',
            )
          : const ProviderTestResult(
              success: false,
              message:
                  'That key was rejected by the provider. Check you copied '
                  'all of it, and that it has not been revoked.',
            );
    } on FormatException catch (e) {
      return ProviderTestResult(success: false, message: e.message);
    } on SocketException catch (e) {
      return ProviderTestResult(
        success: false,
        message:
            '${e.message} Check your connection and try again -- this is not '
            'necessarily a problem with your key.',
      );
    } on HttpException catch (e) {
      return ProviderTestResult(success: false, message: e.message);
    } catch (e) {
      return ProviderTestResult(
        success: false,
        message: 'Could not reach the provider: $e',
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
