/// Provider configuration — Implementation Specification IS-P06.
///
/// One sheet that handles the whole life of a provider configuration:
/// requirements, endpoint, API key, connection test, model selection and
/// removal.
///
/// WHAT CHANGED AND WHY.
///
/// The previous dialog offered an empty password box and a "Test Connection"
/// button. It could not show the key it had stored, could not tell the user
/// what the provider needed before they pasted a secret into it, could not
/// pick a model, and reported every failure as one sentence. Manual testing
/// hit the worst case: a valid key, an HTTP 400 caused by a retired model, and
/// a message that blamed the key.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/provider_catalogue.dart';
import '../../ai/provider_error.dart';
import '../../core/contracts/model_provider.dart';
import '../../design_system/components/components.dart';
import '../../services/provider_registry.dart';

class ProviderConfigurationSheet extends StatefulWidget {
  final ProviderConfig config;
  final ProviderDescriptor descriptor;
  final AnythingProviderRegistry registry;

  /// Called after any change that the list behind this sheet must reflect.
  final VoidCallback onChanged;

  const ProviderConfigurationSheet({
    super.key,
    required this.config,
    required this.descriptor,
    required this.registry,
    required this.onChanged,
  });

  @override
  State<ProviderConfigurationSheet> createState() =>
      _ProviderConfigurationSheetState();
}

class _ProviderConfigurationSheetState
    extends State<ProviderConfigurationSheet> {
  late final TextEditingController _keyController;
  late final TextEditingController _endpointController;
  late final TextEditingController _modelController;

  late ProviderConfig _config;

  /// IS-P06 — the key is masked by default and revealable on request.
  ///
  /// Masked-only made a mistyped key impossible to check, which is a common
  /// reason a key "does not work". Revealing is deliberate, per-view, and
  /// never persisted.
  bool _revealKey = false;
  bool _isTesting = false;
  bool _isLoadingModels = false;
  ProviderTestResult? _testResult;
  List<String> _models = const [];
  String? _modelError;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _keyController = TextEditingController();
    _endpointController = TextEditingController(
      text: _config.endpoint ?? widget.descriptor.baseUrl ?? '',
    );
    _modelController = TextEditingController(
      text: _config.preferredModel ?? widget.descriptor.defaultModel ?? '',
    );
    _loadExistingKey();
    _loadCachedModels();
  }

  /// Loads the stored key so the sheet can EDIT rather than only replace.
  ///
  /// Before this, the field opened empty every time, so saving with an
  /// untouched field looked like it kept the key and actually did nothing —
  /// and there was no way to confirm which key was stored.
  Future<void> _loadExistingKey() async {
    if (!widget.descriptor.requiresApiKey) return;
    try {
      final provider = widget.registry.providerForConfig(_config);
      final existing = await provider?.getApiKey();
      if (existing != null && existing.isNotEmpty && mounted) {
        _keyController.text = existing;
      }
    } catch (_) {
      // A key that cannot be read is left blank; the user can paste a new one.
    }
  }

  Future<void> _loadCachedModels() async {
    final cached = await widget.registry.cachedModels(_config.providerType);
    if (mounted && cached.isNotEmpty) setState(() => _models = cached);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ actions

  Future<void> _test() async {
    final key = _keyController.text.trim();
    if (widget.descriptor.requiresApiKey && key.isEmpty) {
      setState(
        () => _testResult = const ProviderTestResult(
          success: false,
          message: 'Enter an API key before testing.',
          failure: ProviderFailure.missingApiKey,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final draft = _draftConfig();
    String? persistWarning;
    try {
      // Best-effort persist. Never block the live connection test on a wedged
      // Android keystore — saveApiKey caches the key in memory first.
      try {
        await _saveKeyOnly();
      } catch (e) {
        persistWarning = e is StateError
            ? e.message
            : 'Could not store the API key securely on this device.';
      }

      final result = await widget.registry.testProvider(
        _config.providerType,
        key,
        config: draft,
      );

      final message = persistWarning == null
          ? result.message
          : '${result.message}\n\nNote: $persistWarning';

      final updated = await widget.registry.recordTestResult(
        draft.copyWith(isConfigured: result.success),
        ProviderTestResult(
          success: result.success,
          message: message,
          failure: result.failure,
        ),
      );

      if (!mounted) return;
      setState(() {
        _testResult = ProviderTestResult(
          success: result.success,
          message: message,
          failure: result.failure,
        );
        _config = updated;
      });
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  ProviderConfig _draftConfig() => _config.copyWith(
    endpoint: _endpointController.text.trim().isEmpty
        ? null
        : _endpointController.text.trim(),
    preferredModel: _modelController.text.trim().isEmpty
        ? null
        : _modelController.text.trim(),
  );

  Future<void> _refreshModels() async {
    final key = _keyController.text.trim();
    if (widget.descriptor.requiresApiKey && key.isEmpty) {
      setState(() => _modelError = 'Enter an API key before refreshing models.');
      return;
    }

    setState(() {
      _isLoadingModels = true;
      _modelError = null;
    });
    try {
      // Cache key for discovery; ignore keystore persist failures.
      try {
        await _saveKeyOnly();
      } catch (_) {}
      final models = await widget.registry.refreshModels(_draftConfig());
      if (!mounted) return;
      setState(() {
        _models = models;
        if (models.isEmpty) {
          _modelError = 'That provider reported no models.';
        }
      });
    } on ProviderException catch (e) {
      if (!mounted) return;
      setState(() => _modelError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelError = ProviderErrors.fromException(
          e,
          providerName: widget.descriptor.name,
        ).message;
      });
    } finally {
      if (mounted) setState(() => _isLoadingModels = false);
    }
  }

  Future<void> _saveKeyOnly() async {
    final key = _keyController.text.trim();
    if (key.isEmpty || !widget.descriptor.requiresApiKey) return;
    final provider = widget.registry.providerForConfig(_draftConfig());
    if (provider == null) {
      throw StateError('That provider is not available yet.');
    }
    await provider.saveApiKey(key);
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    final needsKey = widget.descriptor.requiresApiKey;

    if (needsKey && key.isEmpty) {
      setState(
        () => _testResult = const ProviderTestResult(
          success: false,
          message: 'Enter an API key before saving.',
          failure: ProviderFailure.missingApiKey,
        ),
      );
      return;
    }
    if (widget.descriptor.requiresEndpoint &&
        _endpointController.text.trim().isEmpty) {
      setState(
        () => _testResult = const ProviderTestResult(
          success: false,
          message: 'Enter the endpoint address before saving.',
          failure: ProviderFailure.incorrectEndpoint,
        ),
      );
      return;
    }

    String? persistWarning;
    try {
      await _saveKeyOnly();
    } catch (e) {
      // Still activate the provider for this session — cache is set before
      // the vault write — but tell the user persistence may not survive
      // process death.
      persistWarning = e is StateError
          ? e.message
          : 'Could not store the API key securely on this device.';
    }

    final saved = _draftConfig().copyWith(isConfigured: true);
    await widget.registry.saveConfig(saved);
    // Always make a successfully saved provider the active one — not only
    // when none was active (replacing a stale active id after reconfigure).
    await widget.registry.setActiveProvider(saved.providerType);
    widget.onChanged();
    if (!mounted) return;
    if (persistWarning != null) {
      setState(
        () => _testResult = ProviderTestResult(
          success: true,
          message:
              'Saved for this session. $persistWarning',
          failure: ProviderFailure.unknown,
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty — copy your key first')),
      );
      return;
    }
    // Never log clipboard contents.
    setState(() {
      _keyController.text = text;
      _keyController.selection = TextSelection.collapsed(offset: text.length);
      _revealKey = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API key pasted')));
  }

  Future<void> _copyKey() async {
    final text = _keyController.text;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API key copied')));
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final d = widget.descriptor;

    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 16;
    final keyboardPad = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardPad),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // Pin Test/Save outside the scroll body so a tall form / OEM nav
          // bar cannot bury the only actions that complete BYOK.
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withAlpha(77),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      d.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.summary,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _RequirementsPanel(descriptor: d),
                    if (_config.lastValidatedAt != null ||
                        _config.lastFailureReason != null) ...[
                      const SizedBox(height: 16),
                      _ValidationHistory(config: _config),
                    ],
                    if (d.requiresEndpoint || d.baseUrl != null) ...[
                      const SizedBox(height: 24),
                      AnythingTextField(
                        label: d.requiresEndpoint
                            ? 'Endpoint address (required)'
                            : 'Endpoint address',
                        hint: 'https://192.168.1.10:11434/v1',
                        controller: _endpointController,
                        keyboardType: TextInputType.url,
                      ),
                      if (d.category == ProviderCategory.local) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Use your computer’s address on the network, not '
                          'localhost — localhost from a phone means the phone.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                    if (d.requiresApiKey) ...[
                      const SizedBox(height: 20),
                      AnythingTextField(
                        label: 'API key',
                        hint: d.keyHint ?? 'Paste your key',
                        controller: _keyController,
                        obscureText: !_revealKey,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        suffixIcon: _revealKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _revealKey = !_revealKey),
                        semanticsLabel: _revealKey
                            ? 'API key, visible. Tap the icon to hide it.'
                            : 'API key, hidden. Tap the icon to reveal it.',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _pasteKey,
                            icon: const Icon(
                              Icons.content_paste_outlined,
                              size: 16,
                            ),
                            label: const Text('Paste'),
                          ),
                          TextButton.icon(
                            onPressed:
                                _keyController.text.isEmpty ? null : _copyKey,
                            icon: const Icon(Icons.copy_all_outlined, size: 16),
                            label: const Text('Copy'),
                          ),
                          const Spacer(),
                          if (d.consoleUrl != null)
                            Flexible(
                              child: Text(
                                d.consoleUrl!,
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (_testResult != null) ...[
                      const SizedBox(height: 12),
                      _TestResultPanel(result: _testResult!),
                    ],
                    const SizedBox(height: 24),
                    _ModelSection(
                      controller: _modelController,
                      models: _models,
                      isLoading: _isLoadingModels,
                      error: _modelError,
                      supportsDiscovery: d.capabilities.modelDiscovery,
                      onRefresh: _isLoadingModels ? null : _refreshModels,
                      onPick: (m) =>
                          setState(() => _modelController.text = m),
                    ),
                  ],
                ),
              ),
              Material(
                elevation: 6,
                color: colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnythingButton(
                        label: _isTesting ? 'Testing…' : 'Test connection',
                        isLoading: _isTesting,
                        onPressed: _isTesting ? null : _test,
                      ),
                      const SizedBox(height: 8),
                      AnythingButton(label: 'Save', onPressed: _save),
                      const SizedBox(height: 8),
                      AnythingGhostButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// States plainly what the provider needs BEFORE the user pastes a secret.
class _RequirementsPanel extends StatelessWidget {
  final ProviderDescriptor descriptor;

  const _RequirementsPanel({required this.descriptor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = <String>[
      descriptor.requiresApiKey
          ? 'An API key from ${descriptor.name}'
          : 'No API key needed',
      if (descriptor.requiresEndpoint)
        'The address of your server, reachable from this phone',
      if (descriptor.defaultModel != null)
        'A model — ${descriptor.defaultModel} is used unless you choose another'
      else
        'A model — you must choose one, as this provider has no fixed default',
      descriptor.capabilities.localExecution
          ? 'Your prompts stay on your own network'
          : 'Your prompts are sent to ${descriptor.name}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT THIS NEEDS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (descriptor.status == ProviderStatus.experimental) ...[
            const SizedBox(height: 6),
            Text(
              'Experimental: this provider speaks the same protocol as Groq, '
              'but the integration has not been tested against a live '
              'account by the maintainers.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// When the key last worked, and why it last failed.
class _ValidationHistory extends StatelessWidget {
  final ProviderConfig config;

  const _ValidationHistory({required this.config});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final validated = config.lastValidatedAt;
    final failure = config.lastFailureReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (validated != null)
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 15, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Last worked ${_ago(validated)}',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ),
            ],
          ),
        if (failure != null) ...[
          if (validated != null) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Last failure: $failure',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

/// The outcome of a connection test, coloured by whether it succeeded.
class _TestResultPanel extends StatelessWidget {
  final ProviderTestResult result;

  const _TestResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ok = result.success;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ok
              ? Colors.green.withAlpha(26)
              : colorScheme.errorContainer.withAlpha(51),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                ok ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: ok ? Colors.green : colorScheme.error,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: ok ? Colors.green : colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Model discovery, manual entry and selection.
class _ModelSection extends StatelessWidget {
  final TextEditingController controller;
  final List<String> models;
  final bool isLoading;
  final String? error;
  final bool supportsDiscovery;
  final VoidCallback? onRefresh;
  final ValueChanged<String> onPick;

  const _ModelSection({
    required this.controller,
    required this.models,
    required this.isLoading,
    required this.error,
    required this.supportsDiscovery,
    required this.onRefresh,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'MODEL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (supportsDiscovery)
              TextButton.icon(
                onPressed: onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(isLoading ? 'Loading…' : 'Refresh list'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Always a free-text field, never a dropdown alone: discovery can fail,
        // and a user who knows the model ID must not be blocked by that.
        AnythingTextField(
          label: 'Model ID',
          hint: 'llama-3.3-70b-versatile',
          controller: controller,
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colorScheme.error,
            ),
          ),
        ],
        if (models.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${models.length} available — tap to use',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in models)
                    ActionChip(label: Text(m), onPressed: () => onPick(m)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
