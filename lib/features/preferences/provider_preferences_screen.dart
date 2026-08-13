/// AI Provider preferences — Implementation Specification IS-P06.
///
/// BYOK (Bring Your Own Key). The screen browses `ProviderCatalogue`, so the
/// list is generated from the same declaration the registry instantiates from.
/// Before IS-P06 the "not available" names were a hand-written list in this
/// file, which is how a settings screen drifts out of step with what the app
/// can actually do.
library;

import 'package:flutter/material.dart';

import '../../ai/provider_catalogue.dart';
import '../../app/app_composition.dart';
import '../../core/contracts/model_provider.dart';
import '../../design_system/components/components.dart';
import '../../design_system/tokens/spacing.dart';
import '../../services/provider_registry.dart';
import 'provider_configuration_sheet.dart';

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
  final TextEditingController _searchController = TextEditingController();

  List<ProviderConfig> _configs = const [];
  bool _isLoading = true;
  String _query = '';
  ProviderCategory? _categoryFilter;

  @override
  void initState() {
    super.initState();
    // IS-P05: was `AnythingProviderRegistry()` — a PRIVATE registry, so
    // anything saved here went into a throwaway instance the rest of the app
    // never saw. It now uses the ONE registry from the composition root.
    _registry = widget.registry ?? AppComposition.production().providerRegistry;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final configs = await _registry.listConfigs();
    if (!mounted) return;
    setState(() {
      _configs = configs;
      _isLoading = false;
    });
  }

  ProviderConfig? _configFor(String providerId) {
    for (final c in _configs) {
      if (c.providerType == providerId) return c;
    }
    return null;
  }

  Future<void> _open(ProviderDescriptor descriptor) async {
    if (!descriptor.isImplemented) {
      _explainUnavailable(descriptor);
      return;
    }

    var config = _configFor(descriptor.id);
    config ??= await _registry.createConfig(descriptor);
    await _load();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderConfigurationSheet(
        config: config!,
        descriptor: descriptor,
        registry: _registry,
        onChanged: _load,
      ),
    );
    await _load();
  }

  /// A deferred provider explains itself rather than doing nothing.
  void _explainUnavailable(ProviderDescriptor descriptor) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descriptor.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                descriptor.summary,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'NOT AVAILABLE YET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                descriptor.unavailableReason ??
                    'No adapter has been written for this provider yet.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Anything talks to a provider through a small adapter. '
                'Adding one is a contained piece of work and contributions '
                'are welcome.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              AnythingGhostButton(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(ProviderConfig config) async {
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
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(showCloseIcon: true, content: Text('${config.displayName} removed')));
  }

  // ------------------------------------------------------------------- build

  List<ProviderDescriptor> get _visible {
    var list = ProviderCatalogue.search(_query);
    if (_categoryFilter != null) {
      list = list.where((p) => p.category == _categoryFilter).toList();
    }
    return list;
  }

  /// Configured providers, most recently touched first.
  List<ProviderConfig> get _recentlyUsed {
    final configured = _configs.where((c) => c.isConfigured).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return configured;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visible = _visible;

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
                Text(
                  'Bring your own key. Keys are stored in this phone’s '
                  'keystore and are never uploaded.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                AnythingTextField(
                  hint: 'Search providers',
                  controller: _searchController,
                  prefixIcon: Icons.search,
                  onChanged: (v) => setState(() => _query = v),
                  semanticsLabel: 'Search AI providers',
                ),
                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _categoryFilter == null,
                        onSelected: () =>
                            setState(() => _categoryFilter = null),
                      ),
                      for (final c in ProviderCategory.values)
                        _FilterChip(
                          label: c.label,
                          selected: _categoryFilter == c,
                          onSelected: () => setState(() => _categoryFilter = c),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_recentlyUsed.isNotEmpty && _query.isEmpty) ...[
                  _SectionLabel('YOUR PROVIDERS'),
                  const SizedBox(height: 8),
                  for (final config in _recentlyUsed)
                    _ConfiguredCard(
                      config: config,
                      descriptor: ProviderCatalogue.byId(config.providerType),
                      isActive:
                          _registry.activeProvider?.providerId ==
                          config.providerType,
                      onOpen: () {
                        final d = ProviderCatalogue.byId(config.providerType);
                        if (d != null) _open(d);
                      },
                      onDelete: () => _delete(config),
                    ),
                  const SizedBox(height: 24),
                ],

                if (visible.isEmpty)
                  AnythingEmptyState(
                    icon: Icons.search_off,
                    title: 'No providers match',
                    message: 'Try a different search or clear the filter.',
                  )
                else
                  ..._grouped(visible),

                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Most of these speak the same OpenAI-compatible protocol, '
                    'so Anything reaches them through one adapter. Groq is the '
                    'one tested against a live account; the rest are marked '
                    'experimental honestly rather than promised.',
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

  List<Widget> _grouped(List<ProviderDescriptor> visible) {
    final widgets = <Widget>[];
    for (final category in ProviderCategory.values) {
      final inCategory = visible.where((p) => p.category == category).toList();
      if (inCategory.isEmpty) continue;
      widgets
        ..add(_SectionLabel(category.label.toUpperCase()))
        ..add(const SizedBox(height: 8));
      for (final descriptor in inCategory) {
        widgets.add(
          _CatalogueCard(
            descriptor: descriptor,
            config: _configFor(descriptor.id),
            onTap: () => _open(descriptor),
          ),
        );
      }
      widgets.add(const SizedBox(height: 20));
    }
    return widgets;
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

/// A provider the user has already configured.
class _ConfiguredCard extends StatelessWidget {
  final ProviderConfig config;
  final ProviderDescriptor? descriptor;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ConfiguredCard({
    required this.config,
    required this.descriptor,
    required this.isActive,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final model = config.preferredModel;

    return AnythingCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        config.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      _Badge(text: 'Active', color: colorScheme.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  model == null || model.isEmpty
                      ? 'No model chosen'
                      : 'Model: $model',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (config.lastValidatedAt != null)
                  Text(
                    'Verified',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  )
                else if (config.lastFailureReason != null)
                  Text(
                    'Last test failed',
                    style: TextStyle(fontSize: 12, color: colorScheme.error),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Remove ${config.displayName}',
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: onOpen,
            tooltip: 'Configure ${config.displayName}',
            icon: Icon(
              Icons.settings,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A provider from the catalogue.
class _CatalogueCard extends StatelessWidget {
  final ProviderDescriptor descriptor;
  final ProviderConfig? config;
  final VoidCallback onTap;

  const _CatalogueCard({
    required this.descriptor,
    required this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final comingSoon = !descriptor.isImplemented;

    return Semantics(
      button: true,
      label:
          '${descriptor.name}. ${descriptor.status.label}. '
          '${comingSoon ? descriptor.unavailableReason ?? '' : descriptor.summary}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withAlpha(
                  comingSoon ? 102 : 255,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                descriptor.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(descriptor: descriptor),
                            if (config?.isConfigured == true) ...[
                              const SizedBox(width: 6),
                              _Badge(text: 'Configured', color: Colors.green),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          comingSoon
                              ? descriptor.unavailableReason ??
                                    descriptor.summary
                              : descriptor.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    comingSoon ? Icons.info_outline : Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ProviderDescriptor descriptor;

  const _StatusBadge({required this.descriptor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (text, color) = switch (descriptor.status) {
      ProviderStatus.available => ('Tested', Colors.green),
      ProviderStatus.experimental => ('Experimental', colorScheme.tertiary),
      ProviderStatus.comingSoon => (
        'Coming soon',
        colorScheme.onSurfaceVariant,
      ),
    };
    return _Badge(text: text, color: color);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(31),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
