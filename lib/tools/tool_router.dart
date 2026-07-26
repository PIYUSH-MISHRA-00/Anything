import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tool_registry.dart';

final toolRouterProvider = Provider<ToolRouter>((ref) {
  final registry = ref.watch(toolRegistryProvider);
  return ToolRouter(registry);
});

class ToolRouter {
  final ToolRegistry _registry;

  ToolRouter(this._registry);

  Future<Map<String, dynamic>> executeTools(
    List<String> toolNames,
    String intentPayload,
  ) async {
    Map<String, dynamic> results = {};

    for (var toolName in toolNames) {
      final tool = _registry.getTool(toolName);
      if (tool != null) {
        try {
          // In a real implementation, intentPayload would be parsed for tool-specific arguments.
          results[toolName] = await tool.execute(intentPayload);
        } catch (e) {
          results[toolName] = {'error': e.toString()};
        }
      } else {
        results[toolName] = {'error': 'Tool not found'};
      }
    }

    return results;
  }
}
