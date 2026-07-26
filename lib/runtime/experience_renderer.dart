/// Experience Renderer — converts declarative InterfaceDefinition to Flutter widgets.
///
/// Only known Runtime component types are supported.
/// No dynamic widget reflection or import.
library;

import 'package:flutter/material.dart';

import '../creation/experience_package.dart';
import '../design_system/tokens/spacing.dart';
import 'state_engine.dart';

/// Maps interface node types to trusted Flutter widgets.
class ExperienceRenderer {
  /// Render an InterfaceDefinition into a Widget tree.
  Widget render(
    BuildContext context,
    InterfaceDefinition interface,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    if (interface.screens.isEmpty) {
      return const Center(child: Text('No screens defined'));
    }

    final mainScreen = interface.screens.first;
    return _renderScreen(context, mainScreen, stateEngine, onEvent: onEvent);
  }

  Widget _renderScreen(
    BuildContext context,
    InterfaceScreen screen,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(screen.appBarTitle ?? screen.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AnythingPadding.regular),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: screen.children
                .map(
                  (node) =>
                      _renderNode(context, node, stateEngine, onEvent: onEvent),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _renderNode(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    switch (node.type) {
      case 'text':
        return _renderText(context, node, stateEngine);
      case 'button':
        return _renderButton(context, node, stateEngine, onEvent: onEvent);
      case 'input':
        return _renderInput(context, node, stateEngine, onEvent: onEvent);
      case 'column':
        return _renderColumn(context, node, stateEngine, onEvent: onEvent);
      case 'row':
        return _renderRow(context, node, stateEngine, onEvent: onEvent);
      case 'card':
        return _renderCard(context, node, stateEngine, onEvent: onEvent);
      case 'switch':
        return _renderSwitch(context, node, stateEngine, onEvent: onEvent);
      case 'divider':
        return const Divider();
      case 'spacer':
        return const SizedBox(height: 16);
      case 'icon':
        return _renderIcon(node);
      default:
        return _renderUnknown(node);
    }
  }

  Widget _renderText(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine,
  ) {
    final content = node.properties['content'] as String? ?? '';
    final boundValue = node.stateBinding != null
        ? stateEngine.read(node.stateBinding!)?.toString() ?? content
        : content;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(boundValue, style: Theme.of(context).textTheme.bodyLarge),
    );
  }

  Widget _renderButton(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    final label = node.properties['label'] as String? ?? 'Button';
    final actionId = node.actionBinding?.actionId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: actionId != null ? () => onEvent?.call(actionId) : null,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _renderInput(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    final hint = node.properties['hint'] as String? ?? '';
    final stateId = node.stateBinding;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: stateId != null
            ? (value) => stateEngine.write(stateId, value)
            : null,
      ),
    );
  }

  Widget _renderColumn(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: node.children
          .map(
            (child) =>
                _renderNode(context, child, stateEngine, onEvent: onEvent),
          )
          .toList(),
    );
  }

  Widget _renderRow(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    return Row(
      children: node.children
          .map(
            (child) =>
                _renderNode(context, child, stateEngine, onEvent: onEvent),
          )
          .toList(),
    );
  }

  Widget _renderCard(
    BuildContext context,
    InterfaceNode node,
    ExperienceStateEngine stateEngine, {
    void Function(String eventId, {Map<String, dynamic>? data})? onEvent,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: node.children
              .map(
                (child) =>
                    _renderNode(context, child, stateEngine, onEvent: onEvent),
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

    return Switch(
      value: currentValue,
      onChanged: stateId != null
          ? (value) {
              stateEngine.write(stateId, value);
              onEvent?.call('${node.id}_changed', data: {'value': value});
            }
          : null,
    );
  }

  Widget _renderIcon(InterfaceNode node) {
    final iconName = node.properties['icon'] as String? ?? 'help';
    final iconData = _resolveIcon(iconName);
    return Icon(iconData, size: 24);
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
    };
    return iconMap[name] ?? Icons.help;
  }
}
