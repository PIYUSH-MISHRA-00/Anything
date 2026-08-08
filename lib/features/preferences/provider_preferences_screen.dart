/// AI Provider preferences screen.
///
/// Allows users to add, configure, test, and manage AI providers.
/// BYOK (Bring Your Own Key) architecture.
library;

import 'package:flutter/material.dart';

import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/design_system/components/components.dart';
import 'package:anything/design_system/tokens/spacing.dart';
import 'package:anything/services/provider_registry.dart';
import '../../app/app_composition.dart';

/// AI Provider preferences screen.
class ProviderPreferencesScreen extends StatefulWidget {
  /// Injectable for tests; production uses the composition root's single
  /// registry so configuration is shared with the rest of the app.
  final AnythingProviderRegistry? registry;

  const ProviderPreferencesScreen({super.key, this.registry});

  @override
  State<ProviderPreferencesScreen> createState() =>
      _ProviderPreferencesScreenState();
}

class _ProviderPreferencesScreenState extends State<ProviderPreferencesScreen> {
  late final AnythingProviderRegistry _registry;
  List<ProviderConfig> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // IS-P05: was `AnythingProviderRegistry()` -- a PRIVATE registry.
    // Anything saved here went into a throwaway instance the rest of the app
    // never saw, so configuring a provider had no effect on generation. It now
    // uses the ONE registry from the composition root.
    _registry = widget.registry ?? AppComposition.production().providerRegistry;
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await _registry.listConfigs();
    setState(() {
      _configs = configs;
      _isLoading = false;
    });
  }

  Future<void> _addGroqProvider() async {
    final config = await _registry.createGroqConfig();
    await _loadConfigs();
    if (mounted) {
      _showConfigureDialog(config);
    }
  }

  void _showConfigureDialog(ProviderConfig config) {
    final apiKeyController = TextEditingController();
    bool isTesting = false;
    bool testSuccess = false;
    String? testMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final colorScheme = Theme.of(context).colorScheme;

          return Container(
            padding: EdgeInsets.fromLTRB(
              32,
              32,
              32,
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure ${config.displayName}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your API key from console.groq.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                AnythingTextField(
                  label: 'API Key',
                  hint: 'gsk_...',
                  controller: apiKeyController,
                  obscureText: true,
                ),
                if (testMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: testSuccess
                          ? Colors.green.withAlpha(26)
                          : colorScheme.errorContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          testSuccess ? Icons.check_circle : Icons.error,
                          size: 16,
                          color: testSuccess ? Colors.green : colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            testMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: testSuccess
                                  ? Colors.green
                                  : colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AnythingButton(
                        label: isTesting ? 'Testing...' : 'Test Connection',
                        isLoading: isTesting,
                        onPressed: isTesting
                            ? null
                            : () async {
                                setModalState(() {
                                  isTesting = true;
                                  testMessage = null;
                                });
                                final result = await _registry.testProvider(
                                  config.providerType,
                                  apiKeyController.text,
                                );
                                setModalState(() {
                                  isTesting = false;
                                  testSuccess = result.success;
                                  testMessage = result.message;
                                });
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AnythingGhostButton(
                        label: 'Save',
                        onPressed: () async {
                          if (apiKeyController.text.isNotEmpty) {
                            final provider = _registry.getProvider(
                              config.providerType,
                            );
                            if (provider != null) {
                              await provider.saveApiKey(apiKeyController.text);
                              await _registry.saveConfig(
                                config.copyWith(isConfigured: true),
                              );
                              await _loadConfigs();
                            }
                          }
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('AI Providers'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AnythingPadding.regular),
              children: [
                // Header
                Text(
                  'Bring Your Own Key',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Existing providers
                if (_configs.isEmpty)
                  AnythingEmptyState(
                    icon: Icons.psychology,
                    title: 'No providers configured',
                    message:
                        'Add an AI provider to start creating experiences.',
                    actionLabel: 'Add Groq',
                    onAction: _addGroqProvider,
                  )
                else ...[
                  ...(_configs.map((config) => _buildProviderCard(config))),
                  const SizedBox(height: 16),
                  AnythingButton(
                    label: 'Add Groq',
                    icon: Icons.add,
                    onPressed: _addGroqProvider,
                  ),
                ],

                // IS-P05 finding 4. The screen offered only Groq with no
                // explanation, which reads as an unfinished list rather than a
                // deliberate one. These are named as NOT AVAILABLE with the
                // real reason -- each needs an adapter implementing
                // `ModelProvider`, and none exists yet.
                const SizedBox(height: 32),
                Text(
                  'NOT AVAILABLE YET',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ..._unavailable.map(
                  (p) => _buildUnavailableCard(p, colorScheme),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Anything talks to a provider through a small adapter. '
                    'Only Groq has one today, so it is the only key that can '
                    'do anything. Adding another is a contained piece of work '
                    'and contributions are welcome.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// IS-P05 finding 4 — providers a user will look for and cannot use yet.
  /// Each carries the real reason, so the list reads as a deliberate state
  /// rather than an unfinished one.
  static const List<({String name, String why})> _unavailable = [
    (name: 'OpenAI', why: 'No adapter implemented yet'),
    (name: 'Anthropic', why: 'No adapter implemented yet'),
    (name: 'Google Gemini', why: 'No adapter implemented yet'),
    (name: 'Ollama (on-device)', why: 'Needs local model support'),
  ];

  Widget _buildUnavailableCard(
    ({String name, String why}) provider,
    ColorScheme colorScheme,
  ) {
    return Semantics(
      // Announced as disabled, so a screen-reader user is told the same thing
      // the greying-out tells a sighted one.
      enabled: false,
      label: '${provider.name}, not available. ${provider.why}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withAlpha(102),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 18,
                color: colorScheme.onSurfaceVariant.withAlpha(153),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.why,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withAlpha(179),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// IS-P05 finding 6 — removing a provider.
  ///
  /// Every configuration is removable: none is architecturally required, and
  /// the app degrades honestly to `ProviderRequired` with none configured.
  /// Deleting also removes the stored API key, so no orphaned credential is
  /// left in the keystore.
  Future<void> _deleteConfig(ProviderConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${config.displayName}?'),
        content: const Text(
          'The stored API key is deleted from this device as well. Apps you '
          'have already created are not affected, but you will not be able to '
          'create new ones until a provider is configured again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _registry.deleteConfig(config.id);
    await _loadConfigs();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${config.displayName} removed')));
  }

  Widget _buildProviderCard(ProviderConfig config) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnythingCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.psychology, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.isConfigured ? 'Configured' : 'Not configured',
                  style: TextStyle(
                    fontSize: 14,
                    color: config.isConfigured
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (config.isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Default',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          const SizedBox(width: 8),
          // IS-P05 finding 6: a remove action, with confirmation.
          IconButton(
            onPressed: () => _deleteConfig(config),
            tooltip: 'Remove ${config.displayName}',
            icon: Icon(
              Icons.delete_outline,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () => _showConfigureDialog(config),
            // ACCESSIBILITY (IS-P03 Phase 5). An icon-only control with no
            // tooltip has NO accessible name -- a screen reader announces
            // "button" and nothing else. The provider name is included
            // because several of these appear in one list.
            tooltip: 'Configure ${config.displayName}',
            icon: Icon(
              Icons.settings,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
