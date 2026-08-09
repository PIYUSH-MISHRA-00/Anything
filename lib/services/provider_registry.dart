/// Provider registry implementation.
///
/// Manages AI providers and their configurations, and resolves the active
/// provider from local configuration.
///
/// IS-P06 CHANGED THREE THINGS HERE, ONE OF THEM SEVERE.
///
/// 1. THE ACTIVE PROVIDER WAS NEVER SET. `setActiveProvider` existed, was
///    implemented, and was called from NOWHERE in `lib/` — only from test
///    doubles. `_activeProviderId` therefore stayed `null` for the lifetime of
///    every session, so `activeProvider` always returned `null`. Every
///    consumer degraded silently: `ModelProviderAiAdapter` threw
///    "No active AI provider configured", and `ModelUnderstandingService` fell
///    through to heuristic understanding. A user could enter a perfectly valid
///    key and the app would still never call a model. The active provider is
///    now resolved on load and PERSISTED.
///
/// 2. Providers came from a hardcoded `GroqModelProvider` construction. They
///    now come from `ProviderCatalogue`, so adding a provider is adding a row.
///
/// 3. `isConfigured` lied on a cold start, because the key sits behind an
///    async keystore read and nothing primed it. Providers are primed on load.
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../ai/openai_compatible_provider.dart';
import '../ai/provider_catalogue.dart';
import '../ai/provider_error.dart';
import '../core/contracts/model_provider.dart';
import '../diagnostics/log_entry.dart';
import '../diagnostics/structured_logger.dart';
import '../legacy/groq_adapter.dart';
import '../security/credential_vault.dart';
import '../storage/durable_collection_store.dart';

/// Concrete implementation of [ModelProviderRegistry].
class AnythingProviderRegistry implements ModelProviderRegistry {
  final Map<String, ModelProvider> _providers = {};
  final Map<String, ProviderConfig> _configs = {};
  String? _activeProviderId;

  final CredentialVault _vault;

  /// Configuration is DURABLE (IS-P05) through `DurableCollectionStore` — the
  /// ONE SharedPreferences owner (IS-R56).
  ///
  /// Only configuration is stored here. THE API KEY IS NOT: that stays in
  /// `CredentialVault`, backed by the platform keystore.
  final DurableCollectionStore _store;
  static const String _storageKey = 'anything.provider_configs';
  static const String _activeKey = 'anything.active_provider';
  static const String _modelCacheKey = 'anything.provider_models';

  /// The in-flight or completed load.
  ///
  /// IS-P06: this was a plain `bool _loaded`, set to `true` on ENTRY to the
  /// loader. A second caller arriving while the first was still awaiting
  /// storage saw `true` and returned immediately — with `_configs` still
  /// empty. Holding the future instead means every caller awaits the SAME
  /// load and sees the same result.
  Future<void>? _loading;

  /// [credentialVault] is the canonical, shared credential store
  /// (Implementation Milestone R1) — routed to every built-in provider rather
  /// than each provider constructing its own raw secure-storage instance.
  /// Where provider selection, verification and model choice are reported
  /// (IS-P07). Optional, so a directly-constructed registry needs no setup.
  final StructuredLogger? _logger;

  AnythingProviderRegistry({
    CredentialVault? credentialVault,
    DurableCollectionStore store = const DurableCollectionStore(),
    StructuredLogger? logger,
  }) : _store = store,
       _logger = logger,
       _vault = credentialVault ?? CredentialVault() {
    // Groq keeps its named class so the R1 composition-root test and the
    // credential purpose `groq_api_key` are unchanged; it is the same
    // OpenAI-compatible adapter underneath.
    final groq = GroqModelProvider(credentialVault: _vault, logger: logger);
    _providers[groq.providerId] = groq;

    for (final descriptor in ProviderCatalogue.implemented) {
      if (descriptor.id == ProviderCatalogue.groq.id) continue;
      // Providers needing a user-supplied endpoint are instantiated per
      // configuration in `_providerFor`, since the address is part of the
      // configuration rather than the catalogue.
      if (descriptor.requiresEndpoint) continue;
      _providers[descriptor.id] = OpenAiCompatibleProvider(
        descriptor: descriptor,
        credentialVault: _vault,
        logger: logger,
      );
    }
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
    _logger?.info(LogCategory.aiProvider, 'provider selected: $providerId');
    try {
      await _store.update<void>(
        _activeKey,
        (_) => (value: providerId, result: null),
      );
    } catch (_) {
      // The in-memory choice still holds for this session.
    }
  }

  @override
  List<ModelProvider> get providers => _providers.values.toList();

  @override
  void registerProvider(ModelProvider provider) {
    _providers[provider.providerId] = provider;
  }

  @override
  ModelProvider? getProvider(String providerId) => _providers[providerId];

  /// Returns a provider bound to this configuration's endpoint.
  ///
  /// Local and custom providers carry their address in the CONFIGURATION, not
  /// the catalogue, so they cannot be shared singletons.
  ModelProvider? providerForConfig(ProviderConfig config) {
    final descriptor = ProviderCatalogue.byId(config.providerType);
    if (descriptor == null) return _providers[config.providerType];
    if (!descriptor.requiresEndpoint) return _providers[descriptor.id];
    if (config.endpoint == null || config.endpoint!.isEmpty) return null;
    return OpenAiCompatibleProvider(
      descriptor: descriptor,
      credentialVault: _vault,
      endpointOverride: config.endpoint,
      logger: _logger,
    );
  }

  /// Reads persisted state once per instance, then serves from memory.
  ///
  /// This is where the active provider is RESOLVED — the fix for the defect
  /// described at the top of this file.
  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _store.read(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        for (final j in (jsonDecode(raw) as List)) {
          final c = ProviderConfig.fromJson(j as Map<String, dynamic>);
          _configs[c.id] = c;
        }
      }
    } catch (_) {
      // Corrupt configuration must not stop the app starting. The user sees
      // no providers and can add one again.
    }

    try {
      final stored = await _store.read(_activeKey);
      if (stored != null && _providers.containsKey(stored)) {
        _activeProviderId = stored;
      }
    } catch (_) {
      // Falls through to derivation below.
    }

    // Nothing stored (or a stale id): derive it from configuration rather than
    // leaving the app with no active provider — the state that made every
    // configured key useless before IS-P06.
    if (_activeProviderId == null) {
      final configured = _configs.values.where((c) => c.isConfigured).toList();
      final chosen =
          configured.where((c) => c.isDefault).firstOrNull ??
          configured.firstOrNull;
      if (chosen != null && _providers.containsKey(chosen.providerType)) {
        _activeProviderId = chosen.providerType;
      }
    }

    // `isConfigured` is a synchronous getter over an async keystore read, so
    // it reports `false` until primed. Consumers check it before generating.
    //
    // IS-P07 CHANGED THIS IN TWO WAYS, both because the launch gate now
    // AWAITS this method.
    //
    // Concurrently, not one provider at a time: this is ~16 independent
    // keystore reads and serialising them made launch wait for their sum.
    //
    // And BOUNDED. A platform channel with no implementation behind it does
    // not fail, it simply never answers — reproduced in
    // `flutter_test`, where an unmocked `flutter_secure_storage` read hangs
    // forever. Without a bound, launch would hang on a blank screen with no
    // error and no way out. The reads are not cancelled by the timeout, so a
    // slow keystore still populates the cache a moment later; the app simply
    // stops waiting for it.
    await Future.wait([
      for (final provider in _providers.values)
        if (provider is OpenAiCompatibleProvider) provider.prime(),
    ]).timeout(_primeTimeout, onTimeout: () => const <void>[]);
  }

  /// How long launch will wait for the keystore before starting anyway.
  ///
  /// A real read is single-digit milliseconds; this only bounds the
  /// pathological case.
  static const Duration _primeTimeout = Duration(seconds: 2);

  /// Loads persisted state, resolving the active provider.
  ///
  /// IS-P07: awaited by `_AnythingRoot` before the app shell is built, so no
  /// consumer can read [activeProvider] while it still reports `null` for a
  /// provider the user has configured. Idempotent — every caller awaits the
  /// same in-flight load.
  Future<void> initialize() => _ensureLoaded();

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
    final previous = _configs[config.id];
    _configs[config.id] = config;
    if (config.preferredModel != null &&
        config.preferredModel != previous?.preferredModel) {
      _logger?.info(
        LogCategory.aiProvider,
        'model selected for ${config.providerType}: ${config.preferredModel}',
      );
    }
    await _persist();

    // A configuration that is ready to use becomes the active provider when
    // there is no other. Without this, saving a key still left the app with
    // no active provider.
    if (config.isConfigured && _activeProviderId == null) {
      await setActiveProvider(config.providerType);
    }
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

    // Do not leave the app pointing at a provider that no longer exists.
    if (_activeProviderId == removed.providerType) {
      _activeProviderId = null;
      try {
        await _store.clear(_activeKey);
      } catch (_) {
        // Non-fatal; nothing resolves to the removed provider either way.
      }
      final next = _configs.values.where((c) => c.isConfigured).firstOrNull;
      if (next != null) await setActiveProvider(next.providerType);
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

  /// Creates a configuration for any catalogue provider.
  Future<ProviderConfig> createConfig(
    ProviderDescriptor descriptor, {
    String? displayName,
    String? preferredModel,
    String? endpoint,
  }) async {
    await _ensureLoaded();
    final config = ProviderConfig(
      id: const Uuid().v4(),
      providerType: descriptor.id,
      displayName: displayName ?? descriptor.name,
      endpoint: endpoint ?? descriptor.baseUrl,
      preferredModel: preferredModel ?? descriptor.defaultModel,
      isDefault: _configs.isEmpty,
      isConfigured: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveConfig(config);
    return config;
  }

  /// Create a new Groq provider configuration.
  ///
  /// Retained as the named convenience it always was; it now delegates to the
  /// catalogue-driven path rather than hardcoding Groq's fields.
  Future<ProviderConfig> createGroqConfig({
    String? displayName,
    String? preferredModel,
  }) => createConfig(
    ProviderCatalogue.groq,
    displayName: displayName,
    preferredModel: preferredModel,
  );

  /// Tests a provider connection.
  ///
  /// IS-P06: the result now carries the CLASSIFIED failure, so the UI can
  /// distinguish "your key is wrong" from "that model was retired" from
  /// "you are offline" — the distinction whose absence produced the
  /// unactionable "The provider returned HTTP 400."
  Future<ProviderTestResult> testProvider(
    String providerId,
    String apiKey, {
    ProviderConfig? config,
  }) async {
    final provider = config != null
        ? providerForConfig(config)
        : _providers[providerId];
    if (provider == null) {
      return const ProviderTestResult(
        success: false,
        message: 'That provider needs an endpoint address first.',
        failure: ProviderFailure.incorrectEndpoint,
      );
    }

    try {
      final accepted = await provider.testConnection(apiKey);
      _logger?.info(
        LogCategory.aiProvider,
        'provider verification for ${provider.providerId}: '
        '${accepted ? 'accepted' : 'key rejected'}',
      );
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
              failure: ProviderFailure.invalidApiKey,
            );
    } catch (e) {
      final classified = ProviderErrors.fromException(
        e,
        providerName: provider.providerName,
      );
      _logger?.warning(
        LogCategory.aiProvider,
        'provider verification for ${provider.providerId} failed: '
        '${classified.failure.name}',
      );
      return ProviderTestResult(
        success: false,
        message: classified.message,
        failure: classified.failure,
        detail: classified.providerDetail,
      );
    }
  }

  /// Records the outcome of a test against the configuration, so the screen
  /// can show when a key last worked and why it last failed.
  Future<ProviderConfig> recordTestResult(
    ProviderConfig config,
    ProviderTestResult result,
  ) async {
    final updated = result.success
        ? config.copyWith(
            lastValidatedAt: DateTime.now(),
            clearFailureReason: true,
          )
        : config.copyWith(lastFailureReason: result.message);
    await saveConfig(updated);
    return updated;
  }

  // ------------------------------------------------------------- model cache

  /// Cached model IDs per provider, so the picker opens instantly and an
  /// offline user still sees what they had.
  ///
  /// Deliberately NOT time-expiring: a stale list is visibly refreshable, and
  /// silently re-fetching on a timer would spend a user's rate limit without
  /// them asking.
  Future<List<String>> cachedModels(String providerId) async {
    try {
      final raw = await _store.read(_modelCacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = map[providerId];
      return entry is List ? entry.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  /// Fetches models from the provider and caches them.
  ///
  /// Throws a [ProviderException] on failure — the caller shows the message.
  Future<List<String>> refreshModels(ProviderConfig config) async {
    final provider = providerForConfig(config);
    if (provider == null) {
      throw const ProviderException(
        ProviderFailure.incorrectEndpoint,
        'That provider needs an endpoint address first.',
      );
    }

    final models = (await provider.listModels()).map((m) => m.id).toList();

    try {
      await _store.update<void>(_modelCacheKey, (raw) {
        final map = <String, dynamic>{};
        if (raw != null && raw.isNotEmpty) {
          try {
            map.addAll(jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            // Replace an unreadable cache rather than failing the refresh.
          }
        }
        map[config.providerType] = models;
        return (value: jsonEncode(map), result: null);
      });
    } catch (_) {
      // The list is still returned; only the cache is best effort.
    }

    return models;
  }
}

/// Result of a provider connection test.
class ProviderTestResult {
  final bool success;
  final String message;

  /// IS-P06 — what kind of failure this was, for callers that need to branch
  /// rather than only display. `null` on success.
  final ProviderFailure? failure;

  /// The provider's own error text, for Developer Mode. Never shown on the
  /// configuration screen.
  final String? detail;

  const ProviderTestResult({
    required this.success,
    required this.message,
    this.failure,
    this.detail,
  });
}
