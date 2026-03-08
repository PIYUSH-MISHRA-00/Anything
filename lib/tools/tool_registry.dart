import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/web_search_service.dart';
import 'calculator_tool.dart';
import 'web_search_tool.dart';
import 'crypto_tool.dart';
import 'file_analysis_tool.dart';

final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  final webSearch = ref.watch(webSearchServiceProvider);
  return ToolRegistry()
    ..registerTool(SearchTool())
    ..registerTool(WeatherTool())
    ..registerTool(CalculatorTool())
    ..registerTool(WebSearchTool(webSearch))
    ..registerTool(CryptoTool())
    ..registerTool(FileAnalysisTool());
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

// Built-in tools
class SearchTool extends BaseTool {
  @override
  String get name => 'search_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    return {'results': ['Mock search result 1', 'Mock search result 2']};
  }
}

class WeatherTool extends BaseTool {
  @override
  String get name => 'weather_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    return {'temperature': '22°C', 'condition': 'Sunny'};
  }
}
