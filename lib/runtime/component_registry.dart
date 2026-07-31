/// Runtime Component Registry — maps declarative component types
/// to trusted Flutter widgets.
///
/// Unknown component types fail safely with a controlled boundary.
/// Never dynamically instantiate arbitrary Dart classes from strings.
library;

import 'package:flutter/material.dart';

/// Component rendering function.
typedef ComponentBuilder =
    Widget Function(
      BuildContext context,
      Map<String, dynamic> properties,
      List<Widget> children,
    );

/// A registered component type.
class ComponentRegistration {
  final String type;
  final ComponentBuilder builder;
  final String description;

  const ComponentRegistration({
    required this.type,
    required this.builder,
    required this.description,
  });
}

/// Registry of trusted component types.
class RuntimeComponentRegistry {
  final Map<String, ComponentRegistration> _registrations = {};

  /// Maximum component tree depth (security budget).
  static const int maxDepth = 20;

  /// Maximum children per component (security budget).
  static const int maxChildrenPerNode = 50;

  /// Maximum total components in a tree (security budget).
  static const int maxTotalComponents = 500;

  /// Register a component type.
  void register(ComponentRegistration registration) {
    _registrations[registration.type] = registration;
  }

  /// Check if a component type is registered.
  bool isRegistered(String type) => _registrations.containsKey(type);

  /// Get a component builder by type.
  ComponentBuilder? getBuilder(String type) {
    return _registrations[type]?.builder;
  }

  /// Get all registered types.
  List<String> get registeredTypes => _registrations.keys.toList();

  /// Build a widget from a component type.
  Widget? buildComponent(
    BuildContext context,
    String type,
    Map<String, dynamic> properties,
    List<Widget> children,
  ) {
    final builder = getBuilder(type);
    if (builder == null) return null;
    return builder(context, properties, children);
  }

  RuntimeComponentRegistry._();

  /// Create the default registry with standard components.
  factory RuntimeComponentRegistry.defaults() {
    final registry = RuntimeComponentRegistry._();

    // Text
    registry.register(
      ComponentRegistration(
        type: 'text',
        description: 'Text display',
        builder: (ctx, props, children) {
          final stateValue = props['_stateValue'];
          final content =
              (stateValue != null && stateValue.toString().isNotEmpty)
              ? stateValue.toString()
              : (props['content']?.toString() ?? '');
          return Text(
            content,
            style: TextStyle(
              fontSize: _parseDouble(props['fontSize']),
              fontWeight: _parseFontWeight(props['fontWeight']),
              color: _parseColor(props['color']),
            ),
            textAlign: _parseTextAlign(props['textAlign']),
          );
        },
      ),
    );

    // Heading
    registry.register(
      ComponentRegistration(
        type: 'heading',
        description: 'Heading text with hierarchy',
        builder: (ctx, props, children) {
          final content = props['content']?.toString() ?? '';
          final level = _parseInt(props['level']) ?? 1;
          final theme = Theme.of(ctx);
          TextStyle? style;
          switch (level) {
            case 1:
              style = theme.textTheme.headlineLarge;
            case 2:
              style = theme.textTheme.headlineMedium;
            case 3:
              style = theme.textTheme.titleMedium;
            default:
              style = theme.textTheme.bodyLarge;
          }
          return Text(content, style: style);
        },
      ),
    );

    // Button
    registry.register(
      ComponentRegistration(
        type: 'button',
        description: 'Action button',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          final isPrimary = props['primary'] == true;
          final isDanger = props['danger'] == true;
          final isCompact = props['compact'] == true;
          final onPressed = props['_onPressed'] as VoidCallback?;

          if (isDanger) {
            return ElevatedButton(
              onPressed: onPressed ?? () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
                minimumSize: Size(0, isCompact ? 36 : 48),
              ),
              child: Text(label),
            );
          }

          if (isPrimary) {
            return ElevatedButton(
              onPressed: onPressed ?? () {},
              style: ElevatedButton.styleFrom(
                minimumSize: Size(0, isCompact ? 36 : 48),
              ),
              child: Text(label),
            );
          }

          return ElevatedButton(
            onPressed: onPressed ?? () {},
            style: ElevatedButton.styleFrom(
              minimumSize: Size(0, isCompact ? 36 : 48),
            ),
            child: Text(label),
          );
        },
      ),
    );

    // Icon Button
    registry.register(
      ComponentRegistration(
        type: 'iconButton',
        description: 'Icon-only action button',
        builder: (ctx, props, children) {
          final icon = _parseIcon(props['icon']);
          final onPressed = props['_onPressed'] as VoidCallback?;
          return IconButton(icon: Icon(icon), onPressed: onPressed ?? () {});
        },
      ),
    );

    // Card
    registry.register(
      ComponentRegistration(
        type: 'card',
        description: 'Card container',
        builder: (ctx, props, children) {
          final padding = _parseEdgeInsets(props['padding']);
          return Card(
            child: padding != null
                ? Padding(padding: padding, child: _buildColumn(children))
                : _buildColumn(children),
          );
        },
      ),
    );

    // Column
    registry.register(
      ComponentRegistration(
        type: 'column',
        description: 'Vertical layout',
        builder: (ctx, props, children) {
          final spacing = _parseDouble(props['spacing']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: spacing != null
                ? _addSpacing(children, spacing)
                : children,
          );
        },
      ),
    );

    // Row
    registry.register(
      ComponentRegistration(
        type: 'row',
        description: 'Horizontal layout',
        builder: (ctx, props, children) {
          final spacing = _parseDouble(props['spacing']);
          return Row(
            children: spacing != null
                ? _addSpacing(children, spacing)
                : children,
          );
        },
      ),
    );

    // Container
    registry.register(
      ComponentRegistration(
        type: 'container',
        description: 'Generic container',
        builder: (ctx, props, children) {
          final padding = _parseEdgeInsets(props['padding']);
          final margin = _parseEdgeInsets(props['margin']);
          return Container(
            padding: padding,
            margin: margin,
            child: _buildColumn(children),
          );
        },
      ),
    );

    // Divider
    registry.register(
      ComponentRegistration(
        type: 'divider',
        description: 'Horizontal divider',
        builder: (ctx, props, children) => const Divider(),
      ),
    );

    // Spacer
    registry.register(
      ComponentRegistration(
        type: 'spacer',
        description: 'Flexible space',
        builder: (ctx, props, children) {
          final height = _parseDouble(props['height']);
          return SizedBox(height: height ?? 16);
        },
      ),
    );

    // Chip
    registry.register(
      ComponentRegistration(
        type: 'chip',
        description: 'Chip for labels/filters',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          final selected = props['selected'] == true;
          return Chip(
            label: Text(label),
            backgroundColor: selected
                ? Theme.of(ctx).colorScheme.primaryContainer
                : null,
          );
        },
      ),
    );

    // Badge
    registry.register(
      ComponentRegistration(
        type: 'badge',
        description: 'Numeric/text badge',
        builder: (ctx, props, children) {
          final value = props['value']?.toString() ?? '';
          return Badge(label: Text(value));
        },
      ),
    );

    // Input
    registry.register(
      ComponentRegistration(
        type: 'input',
        description: 'Text input field',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          final hint = props['hint']?.toString() ?? '';
          final maxLines = _parseInt(props['maxLines']) ?? 1;
          return TextFormField(
            decoration: InputDecoration(labelText: label, hintText: hint),
            maxLines: maxLines,
          );
        },
      ),
    );

    // Number Input
    registry.register(
      ComponentRegistration(
        type: 'numberInput',
        description: 'Numeric input field',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          return TextFormField(
            decoration: InputDecoration(labelText: label),
            keyboardType: TextInputType.number,
          );
        },
      ),
    );

    // Date Input
    registry.register(
      ComponentRegistration(
        type: 'dateInput',
        description: 'Date picker input',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          return TextFormField(
            decoration: InputDecoration(labelText: label),
            readOnly: true,
          );
        },
      ),
    );

    // Switch
    registry.register(
      ComponentRegistration(
        type: 'switch',
        description: 'Boolean toggle',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          final stateValue = props['_stateValue'];
          final onStateChanged = props['_onStateChanged'] as Function(dynamic)?;
          final boolValue = stateValue == true;
          return SwitchListTile(
            title: Text(label),
            value: boolValue,
            onChanged: onStateChanged != null
                ? (value) => onStateChanged(value)
                : (_) {},
          );
        },
      ),
    );

    // Search Field
    registry.register(
      ComponentRegistration(
        type: 'searchField',
        description: 'Search input with icon',
        builder: (ctx, props, children) {
          final hint = props['hint']?.toString() ?? 'Search...';
          final entityId = props['entityId']?.toString();
          final onEvent = props['_onEvent']
              as void Function(String, {Map<String, dynamic>? data})?;
          final onStateChanged = props['_onStateChanged'] as void Function(dynamic)?;
          return TextField(
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              filled: true,
            ),
            onChanged: (value) {
              onStateChanged?.call(value);
              if (entityId != null) {
                onEvent?.call(
                  'searchChanged',
                  data: {'entityId': entityId, 'term': value},
                );
              }
            },
          );
        },
      ),
    );

    // List
    registry.register(
      ComponentRegistration(
        type: 'list',
        description: 'List container',
        builder: (ctx, props, children) {
          return Column(mainAxisSize: MainAxisSize.min, children: children);
        },
      ),
    );

    // List Item
    registry.register(
      ComponentRegistration(
        type: 'listItem',
        description: 'List item with title/subtitle',
        builder: (ctx, props, children) {
          final title = props['title']?.toString() ?? '';
          final subtitle = props['subtitle']?.toString();
          final trailing = props['trailing']?.toString();
          return ListTile(
            title: Text(title),
            subtitle: subtitle != null ? Text(subtitle) : null,
            trailing: trailing != null ? Text(trailing) : null,
          );
        },
      ),
    );

    // Empty State
    registry.register(
      ComponentRegistration(
        type: 'emptyState',
        description: 'Empty state placeholder',
        builder: (ctx, props, children) {
          final title = props['title']?.toString() ?? 'No data';
          final message = props['message']?.toString();
          final icon = _parseIcon(props['icon']);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: Theme.of(ctx).colorScheme.outline),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
                ],
              ],
            ),
          );
        },
      ),
    );

    // Progress Indicator
    registry.register(
      ComponentRegistration(
        type: 'progress',
        description: 'Loading progress indicator',
        builder: (ctx, props, children) {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );

    // Metric Card
    registry.register(
      ComponentRegistration(
        type: 'metric',
        description: 'Dashboard metric display',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          final value = props['value']?.toString() ?? '0';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(ctx).textTheme.headlineMedium),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Tab Bar
    registry.register(
      ComponentRegistration(
        type: 'tabBar',
        description: 'Tab navigation',
        builder: (ctx, props, children) {
          return TabBar(tabs: children.map((c) => Tab(child: c)).toList());
        },
      ),
    );

    // Tab
    registry.register(
      ComponentRegistration(
        type: 'tab',
        description: 'Tab content',
        builder: (ctx, props, children) {
          final label = props['label']?.toString() ?? '';
          return Center(child: Text(label));
        },
      ),
    );

    // Grid
    registry.register(
      ComponentRegistration(
        type: 'grid',
        description: 'Grid layout',
        builder: (ctx, props, children) {
          final columns = _parseInt(props['columns']) ?? 2;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          );
        },
      ),
    );

    return registry;
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static Widget _buildColumn(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static List<Widget> _addSpacing(List<Widget> children, double spacing) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static FontWeight? _parseFontWeight(dynamic value) {
    if (value == null) return null;
    switch (value.toString().toLowerCase()) {
      case 'bold':
        return FontWeight.bold;
      case 'w600':
        return FontWeight.w600;
      case 'w500':
        return FontWeight.w500;
      default:
        return null;
    }
  }

  static TextAlign? _parseTextAlign(dynamic value) {
    if (value == null) return null;
    switch (value.toString().toLowerCase()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is int) return Color(value);
    if (value is String) {
      final hex = value.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    return null;
  }

  static EdgeInsets? _parseEdgeInsets(dynamic value) {
    if (value == null) return null;
    if (value is num) return EdgeInsets.all(value.toDouble());
    if (value is Map) {
      return EdgeInsets.only(
        top: _parseDouble(value['top']) ?? 0,
        bottom: _parseDouble(value['bottom']) ?? 0,
        left: _parseDouble(value['left']) ?? 0,
        right: _parseDouble(value['right']) ?? 0,
      );
    }
    return null;
  }

  static IconData _parseIcon(dynamic value) {
    if (value == null) return Icons.help_outline;
    switch (value.toString().toLowerCase()) {
      case 'add':
        return Icons.add;
      case 'edit':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'search':
        return Icons.search;
      case 'home':
        return Icons.home;
      case 'list':
        return Icons.list;
      case 'grid':
        return Icons.grid_view;
      case 'settings':
        return Icons.settings;
      case 'person':
        return Icons.person;
      case 'check':
        return Icons.check;
      case 'close':
        return Icons.close;
      case 'chevron_right':
        return Icons.chevron_right;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'refresh':
        return Icons.refresh;
      default:
        return Icons.help_outline;
    }
  }
}
