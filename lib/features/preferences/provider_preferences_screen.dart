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

/// AI Provider preferences screen.
class ProviderPreferencesScreen extends StatefulWidget {
  const ProviderPreferencesScreen({super.key});

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
    _registry = AnythingProviderRegistry();
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
                    label: 'Add Provider',
                    icon: Icons.add,
                    onPressed: _addGroqProvider,
                  ),
                ],
              ],
            ),
    );
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
          IconButton(
            onPressed: () => _showConfigureDialog(config),
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
