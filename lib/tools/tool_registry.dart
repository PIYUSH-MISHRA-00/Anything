import 'package:flutter_riverpod/flutter_riverpod.dart';

final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return ToolRegistry()
    ..registerTool(SearchTool())
    ..registerTool(WeatherTool());
});

abstract class BaseTool {
  String get name;
  Future<dynamic> execute(String contextPayload);
}

class ToolRegistry {
  final Map<String, BaseTool> _tools = {};

  void registerTool(BaseTool tool) {
    _tools[tool.name] = tool;
  }

  BaseTool? getTool(String name) {
    return _tools[name];
  }

  List<String> get availableTools => _tools.keys.toList();
}

// Example Mock Tools
class SearchTool extends BaseTool {
  @override
  String get name => 'search_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    // Stub for actual web search
    return {'results': ['Mock search result 1', 'Mock search result 2']};
  }
}

class WeatherTool extends BaseTool {
  @override
  String get name => 'weather_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    // Stub for actual weather API
    return {'temperature': '22°C', 'condition': 'Sunny'};
  }
}
