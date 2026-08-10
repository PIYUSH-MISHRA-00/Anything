/// Experience Renderer — converts declarative InterfaceDefinition to Flutter widgets.
///
/// Canonical production renderer. Uses RuntimeComponentRegistry for trusted
/// component resolution and RuntimeComponentContext for event dispatch.
/// No dynamic widget reflection or import.
library;

import 'package:flutter/material.dart';

import '../creation/experience_package.dart';
import '../design_system/tokens/spacing.dart';
import 'bound_text_field.dart';
import 'component_registry.dart';
import 'form_controller.dart';
import 'remote_image.dart';
import 'runtime_context.dart';
import 'state_engine.dart';

/// Maps interface node types to trusted Flutter widgets.
class ExperienceRenderer {
  final RuntimeComponentRegistry _registry;

  ExperienceRenderer({RuntimeComponentRegistry? registry})
    : _registry = registry ?? RuntimeComponentRegistry.defaults();

  RuntimeComponentRegistry get registry => _registry;

  /// Renders an entire interface as a standalone surface.
  ///
  /// This entry point supplies its own [Scaffold] because it has no host to
  /// sit inside; it renders the first screen as a complete page. [renderScreen]
  /// deliberately does NOT, because the runtime host already provides the
  /// Scaffold, AppBar and navigation around it — nesting a second set is what
  /// gave generated Experiences two title bars and two back arrows.
  Widget render(
    BuildContext context,
    InterfaceDefinition interface,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    if (interface.screens.isEmpty) {
      return const Center(child: Text('No screens defined'));
    }

    final mainScreen = interface.screens.first;
    // Standalone entry: one AppBar is correct here because there is no host.
    // Hosted Experiences must call [renderScreen], which intentionally has none.
    return Scaffold(
      appBar: AppBar(title: Text(mainScreen.appBarTitle ?? mainScreen.title)),
      body: _renderScreen(
        context,
        mainScreen,
        stateEngine,
        onEvent: onEvent,
        runtimeContext: runtimeContext,
        data: data,
      ),
    );
  }

  /// Render a specific screen by ID.
  Widget renderScreen(
    BuildContext context,
    String screenId,
    InterfaceDefinition interface,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final screen = interface.screens.where((s) => s.id == screenId).firstOrNull;
    if (screen == null) {
      return Center(child: Text('Screen not found: $screenId'));
    }
    return _renderScreen(
      context,
      screen,
      stateEngine,
      onEvent: onEvent,
      runtimeContext: runtimeContext,
      data: data,
    );
  }

  Widget _renderScreen(
    BuildContext context,
    InterfaceScreen screen,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    // IS-P08: content only — no Scaffold, no AppBar.
    //
    // This used to return a full Scaffold with its own AppBar, rendered into
    // the BODY of the host's Scaffold. Two AppBars stacked, so the user saw
    // two titles and TWO back arrows, and because both sat under the same
    // MaterialPageRoute both back arrows did the same thing: pop the route
    // and leave the Experience entirely. The inner one could not go back one
    // screen, which is the only thing a second back arrow could have meant.
    //
    // The host owns the chrome; the renderer draws the screen.
    final hasPad = screen.children.any(
      (c) => c.type == 'calculationPad' || c.type == 'timingPad',
    );
    if (hasPad) {
      // IS-P11/P13: calculation + timing Experiences need a BOUNDED Column so
      // Expanded / expandChildren rows receive finite height. Inside a
      // SingleChildScrollView those controls collapse (owner: stopwatch with
      // no usable Start/Stop).
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AnythingPadding.regular),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final node in screen.children)
                if (node.type == 'calculationPad' || node.type == 'timingPad')
                  Expanded(
                    child: _renderNode(
                      context,
                      node,
                      stateEngine,
                      onEvent: onEvent,
                      runtimeContext: runtimeContext,
                      data: data,
                    ),
                  )
                else
                  _renderNode(
                    context,
                    node,
                    stateEngine,
                    onEvent: onEvent,
                    runtimeContext: runtimeContext,
                    data: data,
                  ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AnythingPadding.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: screen.children
              .map(
                (node) => _renderNode(
                  context,
                  node,
                  stateEngine,
                  onEvent: onEvent,
                  runtimeContext: runtimeContext,
                  data: data,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _renderNode(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    // Resolve state-bound content
    final resolvedProperties = _resolveBindings(node.properties, stateEngine);

    // Try data-driven component types first
    switch (node.type) {
      case 'entityList':
        return _renderEntityList(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'entityGrid':
        return _renderEntityGrid(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'entityDetail':
        return _renderEntityDetail(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'entityForm':
        return _renderEntityForm(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'dashboardMetrics':
        return _renderDashboardMetrics(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'referenceSelector':
        return _renderReferenceSelector(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
        );
      case 'chart':
        return _renderChart(
          context,
          node,
          stateEngine,
          runtimeContext: runtimeContext,
        );
      case 'remoteImage':
      case 'image':
        return _renderRemoteImage(
          context,
          node,
          stateEngine,
          resolvedProperties,
        );
    }

    // IS-P11: row/input must use legacy renderers. Registry `row` cannot
    // see per-child width:expand (children are already Widgets), and older
    // registry `input` omitted state binding — Search then ran with empty
    // query while the TextFormField collapsed in an unbounded Row.
    if (node.type == 'row' || node.type == 'input') {
      return _renderLegacyNode(
        context,
        node,
        stateEngine,
        resolvedProperties,
        onEvent: onEvent,
        runtimeContext: runtimeContext,
        data: data,
      );
    }

    // Try registry for standard components
    if (_registry.isRegistered(node.type)) {
      final children = node.children
          .map(
            (child) => _renderNode(
              context,
              child,
              stateEngine,
              onEvent: onEvent,
              runtimeContext: runtimeContext,
              data: data,
            ),
          )
          .toList();

      // Inject action binding into properties for registry components
      final propsWithAction = Map<String, dynamic>.from(resolvedProperties);
      if (node.actionBinding != null) {
        propsWithAction['_actionBinding'] = node.actionBinding;
        propsWithAction['_onPressed'] = node.actionBinding != null
            ? () => onEvent?.call(
                node.actionBinding!.actionId,
                data: node.actionBinding!.parameters,
              )
            : null;
      }
      if (onEvent != null) {
        propsWithAction['_onEvent'] = onEvent;
      }
      if (runtimeContext != null) {
        propsWithAction['_runtimeContext'] = runtimeContext;
      }
      if (node.stateBinding != null) {
        propsWithAction['_stateValue'] = stateEngine.read(node.stateBinding!);
        propsWithAction['_onStateChanged'] = (dynamic value) {
          stateEngine.write(node.stateBinding!, value);
          onEvent?.call('${node.id}_changed', data: {'value': value});
        };
      }

      final widget = _registry.buildComponent(
        context,
        node.type,
        propsWithAction,
        children,
      );
      if (widget != null) return widget;
    }

    // Fallback to legacy rendering for known types
    return _renderLegacyNode(
      context,
      node,
      stateEngine,
      resolvedProperties,
      onEvent: onEvent,
      runtimeContext: runtimeContext,
      data: data,
    );
  }

  Widget _renderLegacyNode(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine,
    Map<String, dynamic> resolvedProperties, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    switch (node.type) {
      case 'text':
        return _renderText(context, node, resolvedProperties);
      case 'button':
        return _renderButton(
          context,
          node,
          resolvedProperties,
          onEvent: onEvent,
          stateEngine: stateEngine,
        );
      case 'input':
        return _renderInput(context, node, stateEngine, onEvent: onEvent);
      case 'column':
        return _renderColumn(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'row':
        return _renderRow(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'calculationPad':
        return _renderCalculationPad(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'timingPad':
        return _renderTimingPad(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'card':
        return _renderCard(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
          data: data,
        );
      case 'switch':
        return _renderSwitch(context, node, stateEngine, onEvent: onEvent);
      case 'divider':
        return const Divider();
      case 'spacer':
        final height = resolvedProperties['height'];
        return SizedBox(height: height is num ? height.toDouble() : 16);
      case 'icon':
        return _renderIcon(resolvedProperties);
      case 'searchField':
        return _renderSearchField(
          context,
          node,
          stateEngine,
          onEvent: onEvent,
          runtimeContext: runtimeContext,
        );
      case 'filterField':
        return _renderFilterField(context, node, stateEngine, onEvent: onEvent);
      case 'sortField':
        return _renderSortField(context, node, stateEngine, onEvent: onEvent);
      case 'remoteImage':
      case 'image':
        return _renderRemoteImage(
          context,
          node,
          stateEngine,
          resolvedProperties,
        );
      default:
        return _renderUnknown(node);
    }
  }

  Widget _renderRemoteImage(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine,
    Map<String, dynamic> resolvedProperties,
  ) {
    final bound = node.stateBinding != null
        ? stateEngine.read(node.stateBinding!)?.toString()
        : null;
    final raw = (bound != null && bound.isNotEmpty)
        ? bound
        : resolvedProperties['url']?.toString();
    final url = RemoteImageUrl.sanitize(raw);
    final height = resolvedProperties['height'] is num
        ? (resolvedProperties['height'] as num).toDouble()
        : 180.0;
    final width = resolvedProperties['width'] is num
        ? (resolvedProperties['width'] as num).toDouble()
        : double.infinity;
    final label =
        resolvedProperties['semanticLabel']?.toString() ??
        resolvedProperties['label']?.toString() ??
        'Image';
    final scheme = Theme.of(context).colorScheme;
    final showPlaceholder = resolvedProperties['showPlaceholder'] == true;
    // Empty URL: hide by default (news often has no media). Never show raw URL.
    if (url == null) {
      if (!showPlaceholder) return const SizedBox.shrink();
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          color: scheme.outline,
          size: 40,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        semanticLabel: label,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            color: scheme.surfaceContainerHighest,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stack) {
          return Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            color: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              color: scheme.outline,
              size: 40,
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _resolveBindings(
    Map<String, dynamic> properties,
    ExperienceStateEngine stateEngine,
  ) {
    final resolved = <String, dynamic>{};
    for (final entry in properties.entries) {
      if (entry.value is String &&
          entry.value.toString().startsWith('\$state.')) {
        final stateId = entry.value.toString().substring(7);
        resolved[entry.key] = stateEngine.read(stateId) ?? entry.value;
      } else {
        resolved[entry.key] = entry.value;
      }
    }
    return resolved;
  }

  // ── Data-driven renderers ──────────────────────────────────

  Widget _renderEntityList(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final entityId = node.properties['entityId'] as String? ?? '';
    final titleField = node.properties['titleField'] as String? ?? 'name';
    final subtitleField = node.properties['subtitleField'] as String?;

    // Use pre-loaded data if available, otherwise query from runtimeContext
    final preloadedRecords = data?['_records'] as List?;
    if (preloadedRecords != null) {
      return _buildEntityListView(
        context,
        node,
        preloadedRecords,
        titleField,
        subtitleField,
        onEvent: onEvent,
        runtimeContext: runtimeContext,
      );
    }

    // Query records from runtimeContext
    if (runtimeContext != null) {
      return StreamBuilder<dynamic>(
        stream: stateEngine.watch('searchTerm'),
        builder: (context, searchTermSnapshot) {
          final searchTerm = (searchTermSnapshot.data as String?) ?? '';
          return StreamBuilder<dynamic>(
            stream: stateEngine.watch('filterValue'),
            builder: (context, filterSnapshot) {
              final filterValue = (filterSnapshot.data as String?) ?? '';
              return StreamBuilder<dynamic>(
                stream: stateEngine.watch('sortField'),
                builder: (context, sortSnapshot) {
                  final sortField =
                      (sortSnapshot.data as String?) ??
                      (node.properties['sortFieldId'] as String? ?? '');
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: runtimeContext.queryRecords(entityId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }
                      var records = snapshot.data ?? [];
                      if (searchTerm.isNotEmpty) {
                        final lowerSearch = searchTerm.toLowerCase();
                        records = records.where((r) {
                          return r.values.any(
                            (v) => v.toString().toLowerCase().contains(
                              lowerSearch,
                            ),
                          );
                        }).toList();
                      }
                      if (filterValue.isNotEmpty) {
                        final fromState =
                            stateEngine.read('filterFieldId') as String?;
                        final filterFieldId =
                            (fromState != null && fromState.isNotEmpty)
                            ? fromState
                            : (node.properties['filterFieldId'] as String? ??
                                  '');
                        if (filterFieldId.isNotEmpty) {
                          records = records
                              .where(
                                (r) =>
                                    (r[filterFieldId] ?? '')
                                        .toString()
                                        .toLowerCase() ==
                                    filterValue.toLowerCase(),
                              )
                              .toList();
                        }
                      }
                      if (sortField.isNotEmpty) {
                        records = List<Map<String, dynamic>>.from(records)
                          ..sort((a, b) {
                            final av = a[sortField];
                            final bv = b[sortField];
                            if (av is num && bv is num) {
                              return av.compareTo(bv);
                            }
                            return (av?.toString() ?? '').compareTo(
                              bv?.toString() ?? '',
                            );
                          });
                      }
                      return _buildEntityListView(
                        context,
                        node,
                        records,
                        titleField,
                        subtitleField,
                        onEvent: onEvent,
                        runtimeContext: runtimeContext,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    }

    // No data source — show empty
    return _buildEmptyState(context, node);
  }

  Widget _buildEntityListView(
    BuildContext context,
    InterfaceNode node,
    List records,
    String titleField,
    String? subtitleField, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
  }) {
    if (records.isEmpty) {
      return _buildEmptyState(context, node);
    }

    final entityId = node.properties['entityId'] as String? ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(records.length, (index) {
        final record = records[index] as Map<String, dynamic>;
        final title = record[titleField]?.toString() ?? 'Record ${index + 1}';
        final subtitle = subtitleField != null
            ? record[subtitleField]?.toString()
            : null;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(title),
            subtitle: subtitle != null ? Text(subtitle) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // One navigation path only — see Edit button. Dual push left
              // an extra detail on the stack so Back did not reach the list.
              onEvent?.call(
                'openDetail',
                data: {'entityId': entityId, 'recordId': record['id']},
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context, InterfaceNode node) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No ${node.properties['emptyTitle'] ?? 'items'} yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (node.properties['emptyMessage'] != null)
                Text(
                  node.properties['emptyMessage'] as String,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderEntityGrid(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final columns = node.properties['columns'] as int? ?? 2;
    final entityId = node.properties['entityId'] as String? ?? '';
    final titleField = node.properties['titleField'] as String? ?? 'name';
    final itemCount = (data?['_records'] as List?)?.length ?? 0;

    if (itemCount == 0) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.grid_view,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${node.properties['emptyTitle'] ?? 'items'} yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: List.generate(itemCount, (index) {
        final record =
            (data?['_records'] as List)[index] as Map<String, dynamic>;
        final title = record[titleField]?.toString() ?? 'Item ${index + 1}';

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // One navigation path only — see Edit button. Dual push left
              // an extra detail on the stack so Back did not reach the list.
              onEvent?.call(
                'openDetail',
                data: {'entityId': entityId, 'recordId': record['id']},
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _renderEntityDetail(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final record = data?['_currentRecord'] as Map<String, dynamic>?;
    final entityId = node.properties['entityId'] as String? ?? '';
    final fields =
        (node.properties['fields'] as List?)?.cast<String>() ??
        record?.keys.toList() ??
        [];

    if (record == null) {
      return const Center(child: Text('Record not found'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...fields.map((fieldId) {
          final value = record[fieldId]?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    fieldId,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                Expanded(child: Text(value)),
              ],
            ),
          );
        }),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // IS-P08: only notify the host. Calling navigate() here as
                  // well pushed the edit screen twice — Save's single pop
                  // then left the user on a second copy of the same form,
                  // with Delete unreachable underneath.
                  onEvent?.call(
                    'editRecord',
                    data: {'entityId': entityId, 'recordId': record['id']},
                  );
                },
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    onEvent?.call(
                      'deleteRecord',
                      data: {'entityId': entityId, 'recordId': record['id']},
                    );
                  }
                },
                child: const Text('Delete'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _renderEntityForm(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final entityId = node.properties['entityId'] as String? ?? '';
    final mode = node.properties['mode'] as String? ?? 'create';
    final fields =
        (node.properties['fields'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    if (fields.isEmpty) {
      return const Center(child: Text('No form fields defined'));
    }

    final fieldDefinitions = fields
        .map(
          (f) => FormFieldDefinition(
            id: f['id'] as String? ?? '',
            name: f['name'] as String? ?? f['id'] as String? ?? '',
            type: f['type'] as String? ?? 'string',
            required: f['required'] as bool? ?? false,
            minLength: f['minLength'] as int?,
            maxLength: f['maxLength'] as int?,
            minimum: f['minimum'] as num?,
            maximum: f['maximum'] as num?,
            allowedValues: (f['allowedValues'] as List?)?.cast<String>(),
            referenceEntityId: f['referenceEntityId'] as String?,
            hint: f['hint'] as String?,
          ),
        )
        .toList();

    final recordMap = data != null ? data['_currentRecord'] : null;
    final currentRecord = recordMap is Map<String, dynamic>
        ? recordMap
        : <String, dynamic>{};

    // Edit-mode forms load their record asynchronously; the FIRST build
    // happens before that record arrives (currentRecord == {}). Without a
    // key that changes once the record loads, Flutter reuses the same
    // State object across that transition and _EntityFormWidgetState's
    // initState() -- which seeds the form controller's initial values,
    // and each field's uncontrolled TextFormField.initialValue -- never
    // reruns, permanently baking in empty values even after the correct
    // record arrives. Keying on the loaded record's id (or "new" while
    // unloaded/creating) forces a fresh State, and fresh initState(),
    // exactly once the real data is available.
    return _EntityFormWidget(
      key: ValueKey('${entityId}_${mode}_${currentRecord['id'] ?? 'new'}'),
      entityId: entityId,
      mode: mode,
      fields: fields,
      fieldDefinitions: fieldDefinitions,
      currentRecord: currentRecord,
      stateEngine: stateEngine,
      onEvent: onEvent,
      runtimeContext: runtimeContext,
    );
  }

  static Widget _buildFormField(
    BuildContext context, {
    required String fieldId,
    required String fieldName,
    required String fieldType,
    required bool required,
    String? hintText,
    List<String>? allowedValues,
    String? referenceEntityId,
    dynamic initialValue,
    RuntimeComponentContext? runtimeContext,
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    final stateId = 'form_$fieldId';
    if (initialValue != null) {
      // Write initial value if state is empty
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Will be set by the state engine on first build
      });
    }

    switch (fieldType) {
      case 'reference':
        return _buildReferenceField(
          context,
          fieldId: fieldId,
          fieldName: fieldName,
          required: required,
          referenceEntityId: referenceEntityId ?? '',
          runtimeContext: runtimeContext,
        );

      case 'boolean':
        return SwitchListTile(
          title: Text('$fieldName${required ? ' *' : ''}'),
          value: initialValue == true,
          onChanged: (value) {
            runtimeContext?.updateFormField(fieldId, value);
            runtimeContext?.updateState(stateId, value);
          },
        );

      case 'enum':
      case 'select':
        final currentVal =
            initialValue?.toString() ??
            (allowedValues?.isNotEmpty == true ? allowedValues!.first : null);
        return DropdownButtonFormField<String>(
          initialValue: currentVal,
          decoration: InputDecoration(
            labelText: '$fieldName${required ? ' *' : ''}',
            hintText: hintText,
          ),
          items: (allowedValues ?? [])
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (value) {
            runtimeContext?.updateFormField(fieldId, value);
            runtimeContext?.updateState(stateId, value);
          },
        );

      case 'integer':
        return TextFormField(
          initialValue: initialValue?.toString() ?? '',
          decoration: InputDecoration(
            labelText: '$fieldName${required ? ' *' : ''}',
            hintText: hintText,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final parsed = int.tryParse(value);
            runtimeContext?.updateFormField(fieldId, parsed ?? value);
            runtimeContext?.updateState(stateId, parsed ?? value);
          },
        );

      case 'decimal':
        return TextFormField(
          initialValue: initialValue?.toString() ?? '',
          decoration: InputDecoration(
            labelText: '$fieldName${required ? ' *' : ''}',
            hintText: hintText,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            final parsed = double.tryParse(value);
            runtimeContext?.updateFormField(fieldId, parsed ?? value);
            runtimeContext?.updateState(stateId, parsed ?? value);
          },
        );

      case 'date':
        return TextFormField(
          initialValue: initialValue?.toString() ?? '',
          decoration: InputDecoration(
            labelText: '$fieldName${required ? ' *' : ''}',
            hintText: hintText ?? 'YYYY-MM-DD',
          ),
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              final dateStr = date.toIso8601String().split('T').first;
              runtimeContext?.updateFormField(fieldId, dateStr);
              runtimeContext?.updateState(stateId, dateStr);
            }
          },
        );

      case 'multiline':
        return TextFormField(
          initialValue: initialValue?.toString() ?? '',
          decoration: InputDecoration(
            labelText: '$fieldName${required ? ' *' : ''}',
            hintText: hintText,
          ),
          maxLines: 3,
          onChanged: (value) {
            runtimeContext?.updateFormField(fieldId, value);
            runtimeContext?.updateState(stateId, value);
          },
        );

      default: // string
        return TextFormField(
          initialValue: initialValue?.toString() ?? '',
          decoration: InputDecoration(
            labelText: '$fieldName${required ? ' *' : ''}',
            hintText: hintText,
          ),
          onChanged: (value) {
            runtimeContext?.updateFormField(fieldId, value);
            runtimeContext?.updateState(stateId, value);
          },
        );
    }
  }

  static Widget _buildReferenceField(
    BuildContext context, {
    required String fieldId,
    required String fieldName,
    required bool required,
    required String referenceEntityId,
    RuntimeComponentContext? runtimeContext,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: runtimeContext?.queryRecords(referenceEntityId),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        final stateId = 'form_$fieldId';
        final rawValue = runtimeContext?.readState(stateId)?.toString();
        // A reference may dangle (its target record was deleted after this
        // value was set — no cascade/restrict is enforced on delete).
        // DropdownButtonFormField requires initialValue to match one of its
        // items or be null; passing a dangling ID through unchanged throws.
        // Deterministic, safe fallback: render as unselected rather than
        // crash (see docs/security/RUNTIME_LIMITS.md "Relationships").
        final currentValue = records.any((r) => r['id']?.toString() == rawValue)
            ? rawValue
            : null;

        return DropdownButtonFormField<String>(
          initialValue: currentValue,
          decoration: InputDecoration(
            labelText: '$fieldName${required ? ' *' : ''}',
          ),
          items: records
              .map(
                (r) => DropdownMenuItem(
                  value: r['id']?.toString(),
                  child: Text(
                    runtimeContext?.getRecordLabel(r) ?? r['id'].toString(),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            runtimeContext?.updateFormField(fieldId, value);
            runtimeContext?.updateState(stateId, value);
          },
        );
      },
    );
  }

  Widget _renderDashboardMetrics(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final metrics =
        (node.properties['metrics'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final records =
        (data?['_records'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: metrics.map((metric) {
        final label = metric['label'] as String? ?? '';
        final operation = metric['operation'] as String? ?? 'count';
        final fieldId = metric['fieldId'] as String?;

        dynamic value;
        switch (operation) {
          case 'count':
            value = records.length;
            break;
          case 'sum':
            if (fieldId != null) {
              num sum = 0;
              for (final r in records) {
                final v = r[fieldId];
                if (v is num) sum += v;
              }
              value = sum;
            }
            break;
          case 'average':
            if (fieldId != null) {
              num sum = 0;
              int count = 0;
              for (final r in records) {
                final v = r[fieldId];
                if (v is num) {
                  sum += v;
                  count++;
                }
              }
              value = count > 0 ? sum / count : 0;
            }
            break;
          case 'min':
            if (fieldId != null) {
              dynamic min;
              for (final r in records) {
                final v = r[fieldId];
                if (v is num && (min == null || v < (min as num))) min = v;
              }
              value = min;
            }
            break;
          case 'max':
            if (fieldId != null) {
              dynamic max;
              for (final r in records) {
                final v = r[fieldId];
                if (v is num && (max == null || v > (max as num))) max = v;
              }
              value = max;
            }
            break;
        }

        return SizedBox(
          width: 150,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value?.toString() ?? '0',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _renderReferenceSelector(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
  }) {
    final entityId = node.properties['entityId'] as String? ?? '';
    final label = node.properties['label'] as String? ?? 'Select';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: runtimeContext?.queryRecords(entityId),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        final selectedId = stateEngine.read('${node.id}_selected');

        return DropdownButtonFormField<String>(
          initialValue: selectedId?.toString(),
          decoration: InputDecoration(labelText: label),
          items: records
              .map(
                (r) => DropdownMenuItem(
                  value: r['id']?.toString(),
                  child: Text(
                    runtimeContext?.getRecordLabel(r) ?? r['id'].toString(),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            stateEngine.write('${node.id}_selected', value);
            onEvent?.call(
              '${node.id}_selected',
              data: {'entityId': entityId, 'recordId': value},
            );
          },
        );
      },
    );
  }

  Widget _renderChart(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    RuntimeComponentContext? runtimeContext,
  }) {
    final chartType = node.properties['chartType'] as String? ?? 'bar';
    final records =
        (stateEngine.read('chartData') as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final labelField = node.properties['labelField'] as String? ?? 'label';
    final valueField = node.properties['valueField'] as String? ?? 'value';
    final maxPoints = node.properties['maxPoints'] as int? ?? 20;

    final dataPoints = records.take(maxPoints).toList();
    final maxVal = dataPoints.fold<num>(0, (prev, r) {
      final v = r[valueField];
      return v is num && v > prev ? v : prev;
    });

    return SizedBox(
      height: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: chartType == 'bar'
              ? _buildBarChart(
                  context,
                  dataPoints,
                  labelField,
                  valueField,
                  maxVal,
                )
              : _buildLineChart(
                  context,
                  dataPoints,
                  labelField,
                  valueField,
                  maxVal,
                ),
        ),
      ),
    );
  }

  Widget _buildBarChart(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String labelField,
    String valueField,
    num maxVal,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Text('No data', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((d) {
        final value = d[valueField];
        final height = maxVal > 0 && value is num
            ? (value / maxVal) * 150.0
            : 0.0;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                value?.toString() ?? '0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                d[labelField]?.toString() ?? '',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLineChart(
    BuildContext context,
    List<Map<String, dynamic>> data,
    String labelField,
    String valueField,
    num maxVal,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Text('No data', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return CustomPaint(
      size: const Size(double.infinity, 150),
      painter: _LineChartPainter(
        data: data,
        labelField: labelField,
        valueField: valueField,
        maxVal: maxVal,
        primaryColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // ── Legacy renderers (backward compatible) ────────────────

  Widget _renderText(
    BuildContext context,
    InterfaceNode node,
    Map<String, dynamic> resolvedProperties,
  ) {
    final content = resolvedProperties['content']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(content, style: Theme.of(context).textTheme.bodyLarge),
    );
  }

  Widget _renderButton(
    BuildContext context,
    InterfaceNode node,
    Map<String, dynamic> resolvedProperties, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    ExperienceStateEngine? stateEngine,
  }) {
    final label = resolvedProperties['label']?.toString() ?? 'Button';
    final actionId = node.actionBinding?.actionId;
    final expand = resolvedProperties['width'] == 'expand';
    final accent = resolvedProperties['accent'] == true;
    final primary = resolvedProperties['primary'] == true;
    final scheme = Theme.of(context).colorScheme;

    final button = ElevatedButton(
      onPressed: actionId != null
          ? () {
              final base = Map<String, dynamic>.from(
                node.actionBinding?.parameters ?? const {},
              );
              // SearchAction: ensure the typed query reaches the provider even
              // if the last keystroke race lost to a rebuild.
              final isSearch =
                  actionId == 'search' ||
                  actionId == 'SearchAction' ||
                  actionId == 'searchAction' ||
                  actionId == 'refreshData';
              if (isSearch &&
                  stateEngine != null &&
                  (base['query'] == null ||
                      base['query'].toString().trim().isEmpty)) {
                final q = stateEngine.read('query')?.toString() ?? '';
                if (q.trim().isNotEmpty) base['query'] = q.trim();
              }
              onEvent?.call(actionId, data: base.isEmpty ? null : base);
            }
          : null,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(expand ? 48 : 0, expand ? 48 : 40),
        backgroundColor: primary
            ? scheme.primary
            : accent
            ? scheme.secondaryContainer
            : null,
        foregroundColor: primary
            ? scheme.onPrimary
            : accent
            ? scheme.onSecondaryContainer
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(expand ? 16 : 9999),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: expand ? 8 : 24,
          vertical: expand ? 8 : 12,
        ),
        // Expand rows (timingPad Start/Pause/Resume) share width; 22sp ellipsized
        // "Pause"/"Resume" to "Pau"/"Res" on ~360dp phones. Scale down instead.
        textStyle: TextStyle(
          fontSize: expand ? 18 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: expand
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, textAlign: TextAlign.center),
            )
          : Text(label),
    );
    if (expand) {
      return SizedBox.expand(child: button);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: button,
    );
  }

  Widget _renderInput(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    final hint = node.properties['hint'] as String? ?? '';
    final label = node.properties['label'] as String? ?? '';
    final stateId = node.stateBinding;
    final expand = node.properties['width'] == 'expand';

    Widget field;
    if (stateId != null) {
      field = BoundTextField(
        key: ValueKey('bound_$stateId'),
        stateEngine: stateEngine,
        stateId: stateId,
        label: label,
        hint: hint,
        onSubmitted: (value) {
          // Generic search submit — carry query so stale/empty state cannot win.
          onEvent?.call('search', data: {'query': value});
        },
      );
    } else {
      field = TextField(
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: label.isEmpty ? null : label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (_) => onEvent?.call('search'),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: expand ? field : field,
    );
  }

  Widget _renderSearchField(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
  }) {
    final hint = node.properties['hint'] as String? ?? 'Search...';
    final entityId = node.properties['entityId'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          filled: true,
        ),
        onChanged: (value) {
          stateEngine.write('searchTerm', value);
          if (entityId != null) {
            onEvent?.call(
              'searchChanged',
              data: {'entityId': entityId, 'term': value},
            );
          }
        },
      ),
    );
  }

  Widget _renderFilterField(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    final hint = node.properties['hint'] as String? ?? 'Filter...';
    final fieldId = node.properties['fieldId'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.filter_list),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          filled: true,
        ),
        onChanged: (value) {
          stateEngine.write('filterValue', value);
          if (fieldId.isNotEmpty) {
            stateEngine.write('filterFieldId', fieldId);
          }
          onEvent?.call(
            'filterChanged',
            data: {'fieldId': fieldId, 'value': value},
          );
        },
      ),
    );
  }

  Widget _renderSortField(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    final hint = node.properties['hint'] as String? ?? 'Sort field';
    final fieldId = node.properties['fieldId'] as String? ?? 'name';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.sort),
        label: Text(hint),
        onPressed: () {
          stateEngine.write('sortField', fieldId);
          onEvent?.call('sortChanged', data: {'fieldId': fieldId});
        },
      ),
    );
  }

  Widget _renderColumn(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: node.children
          .map(
            (child) => _renderNode(
              context,
              child,
              stateEngine,
              onEvent: onEvent,
              runtimeContext: runtimeContext,
              data: data,
            ),
          )
          .toList(),
    );
  }

  Widget _renderRow(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final expandAll = node.properties['expandChildren'] == true;
    final stretch = node.properties['stretchCrossAxis'] == true || expandAll;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        // IS-P11: stretch only for equal-height keypad rows. Weather query
        // rows must stay intrinsic height — stretch + Expanded inside a
        // scrollable Column made Search a full-viewport slab and hid results.
        crossAxisAlignment: stretch
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < node.children.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Builder(
              builder: (context) {
                final child = node.children[i];
                final flex = (child.properties['flex'] is num)
                    ? (child.properties['flex'] as num).toInt()
                    : 1;
                final rendered = _renderNode(
                  context,
                  child,
                  stateEngine,
                  onEvent: onEvent,
                  runtimeContext: runtimeContext,
                  data: data,
                );
                // IS-P13: TextField without Expanded in a Row takes infinite
                // width and collapses sibling Search buttons to 0×0 bounds.
                final wantsExpand =
                    expandAll ||
                    child.properties['width'] == 'expand' ||
                    (child.type == 'input' &&
                        child.properties['width'] != 'intrinsic');
                if (!wantsExpand) return rendered;
                return Expanded(flex: flex <= 0 ? 1 : flex, child: rendered);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderCalculationPad(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = node.children.where((c) => c.type == 'row').toList();
        final rowCount = rows.isEmpty ? 1 : rows.length;
        final rowHeight = (constraints.maxHeight / rowCount).clamp(52.0, 96.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              SizedBox(
                height: rowHeight,
                child: _renderRow(
                  context,
                  row,
                  stateEngine,
                  onEvent: onEvent,
                  runtimeContext: runtimeContext,
                  data: data,
                ),
              ),
          ],
        );
      },
    );
  }

  /// IS-P13: bounded layout for stopwatch/timer controls.
  Widget _renderTimingPad(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    final rows = node.children.where((c) => c.type == 'row').toList();
    final others = node.children.where((c) => c.type != 'row').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in others)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _renderNode(
              context,
              child,
              stateEngine,
              onEvent: onEvent,
              runtimeContext: runtimeContext,
              data: data,
            ),
          ),
        const Spacer(),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 56,
              child: _renderRow(
                context,
                row,
                stateEngine,
                onEvent: onEvent,
                runtimeContext: runtimeContext,
                data: data,
              ),
            ),
          ),
      ],
    );
  }

  Widget _renderCard(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
    RuntimeComponentContext? runtimeContext,
    Map<String, dynamic>? data,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: node.children
              .map(
                (child) => _renderNode(
                  context,
                  child,
                  stateEngine,
                  onEvent: onEvent,
                  runtimeContext: runtimeContext,
                  data: data,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _renderSwitch(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    final stateId = node.stateBinding;
    final currentValue = stateId != null
        ? (stateEngine.read(stateId) as bool? ?? false)
        : false;

    // Accessibility (Vision Milestone V10): a bare Switch has no textual
    // label for screen readers — the visible widget alone announces only
    // "on"/"off", never WHAT it controls. Wrap with the same label the
    // field/node already carries (real data already present on this
    // node, never fabricated).
    final label = node.properties['label']?.toString();
    final switchWidget = Switch(
      value: currentValue,
      onChanged: stateId != null
          ? (value) {
              stateEngine.write(stateId, value);
              onEvent?.call('${node.id}_changed', data: {'value': value});
            }
          : null,
    );
    return label == null
        ? switchWidget
        : Semantics(
            label: label,
            toggled: currentValue,
            child: ExcludeSemantics(child: switchWidget),
          );
  }

  Widget _renderIcon(Map<String, dynamic> properties) {
    final iconName = properties['icon'] as String? ?? 'help';
    final iconData = _resolveIcon(iconName);
    // Accessibility (Vision Milestone V10): a bare Icon conveys nothing to
    // a screen reader by default. Use the icon's own semantic name — the
    // one real, already-available description of what it represents —
    // rather than fabricating a description or leaving it silent.
    return Icon(iconData, size: 24, semanticLabel: iconName);
  }

  Widget _renderUnknown(InterfaceNode node) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Unsupported: ${node.type}',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  IconData _resolveIcon(String name) {
    const iconMap = {
      'home': Icons.home,
      'settings': Icons.settings,
      'person': Icons.person,
      'add': Icons.add,
      'delete': Icons.delete,
      'edit': Icons.edit,
      'search': Icons.search,
      'check': Icons.check,
      'close': Icons.close,
      'arrow_back': Icons.arrow_back,
      'arrow_forward': Icons.arrow_forward,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'share': Icons.share,
      'info': Icons.info,
      'warning': Icons.warning,
      'error': Icons.error,
      'success': Icons.check_circle,
      'list': Icons.list,
      'grid': Icons.grid_view,
      'refresh': Icons.refresh,
      'chevron_right': Icons.chevron_right,
    };
    return iconMap[name] ?? Icons.help;
  }
}

/// Simple line chart painter.
class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final String labelField;
  final String valueField;
  final num maxVal;
  final Color primaryColor;

  _LineChartPainter({
    required this.data,
    required this.labelField,
    required this.valueField,
    required this.maxVal,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final value = data[i][valueField];
      final x = (i / (data.length - 1).clamp(1, data.length - 1)) * size.width;
      final y = maxVal > 0 && value is num
          ? size.height - (value / maxVal) * size.height
          : size.height;
      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = primaryColor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// StatefulWidget for entity forms with validation.
class _EntityFormWidget extends StatefulWidget {
  final String entityId;
  final String mode;
  final List<Map<String, dynamic>> fields;
  final List<FormFieldDefinition> fieldDefinitions;
  final Map<String, dynamic> currentRecord;
  final ExperienceStateEngine stateEngine;
  final void Function(String eventId, {Map<String, dynamic>? data})? onEvent;
  final RuntimeComponentContext? runtimeContext;

  const _EntityFormWidget({
    super.key,
    required this.entityId,
    required this.mode,
    required this.fields,
    required this.fieldDefinitions,
    required this.currentRecord,
    required this.stateEngine,
    this.onEvent,
    this.runtimeContext,
  });

  @override
  State<_EntityFormWidget> createState() => _EntityFormWidgetState();
}

class _EntityFormWidgetState extends State<_EntityFormWidget> {
  late final ExperienceFormController _formController;
  late final RuntimeComponentContext? _formBoundContext;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final initialValues = <String, dynamic>{};
    if (widget.mode == 'edit') {
      for (final f in widget.fields) {
        final fieldId = f['id'] as String;
        initialValues[fieldId] = widget.currentRecord[fieldId];
      }
    }
    _formController = ExperienceFormController(
      entityId: widget.entityId,
      mode: widget.mode == 'edit' ? FormMode.edit : FormMode.create,
      initialValues: initialValues,
      fieldDefinitions: widget.fieldDefinitions,
    );
    _formBoundContext = widget.runtimeContext?.withForm(
      _formController,
      widget.entityId,
    );
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final isValid = _formController.validate();
    final errors = <String, String>{};
    for (final f in widget.fieldDefinitions) {
      final err = _formController.getFieldError(f.id);
      if (err != null) errors[f.id] = err;
    }
    setState(() => _errors = errors);
    if (!isValid) return;

    final formData = <String, dynamic>{};
    for (final f in widget.fields) {
      final fieldId = f['id'] as String;
      final value = _formController.getValue(fieldId);
      if (value != null) formData[fieldId] = value;
    }
    widget.onEvent?.call(
      'submitForm',
      data: {
        'entityId': widget.entityId,
        'mode': widget.mode,
        'values': formData,
        if (widget.mode == 'edit' && widget.currentRecord.isNotEmpty)
          'recordId': widget.currentRecord['id'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.fields.map((fieldDef) {
          final fieldId = fieldDef['id'] as String? ?? '';
          final fieldName = fieldDef['name'] as String? ?? fieldId;
          final fieldType = fieldDef['type'] as String? ?? 'string';
          final required = fieldDef['required'] as bool? ?? false;
          final hintText = fieldDef['hint'] as String?;
          final allowedValues = (fieldDef['allowedValues'] as List?)
              ?.cast<String>();
          final referenceEntityId = fieldDef['referenceEntityId'] as String?;
          final initialValue = widget.mode == 'edit'
              ? widget.currentRecord[fieldId]
              : null;
          final error = _errors[fieldId];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExperienceRenderer._buildFormField(
                  context,
                  fieldId: fieldId,
                  fieldName: fieldName,
                  fieldType: fieldType,
                  required: required,
                  hintText: hintText,
                  allowedValues: allowedValues,
                  referenceEntityId: referenceEntityId,
                  initialValue: initialValue,
                  runtimeContext: _formBoundContext,
                  onEvent: widget.onEvent,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.onEvent?.call(
                    'cancelForm',
                    data: {'entityId': widget.entityId},
                  );
                  widget.runtimeContext?.navigateBack();
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _validateAndSubmit,
                child: Text(widget.mode == 'edit' ? 'Save' : 'Create'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
