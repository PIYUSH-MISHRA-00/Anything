import 'tool_registry.dart';
import '../services/web_search_service.dart';

class WebSearchTool extends BaseTool {
  final WebSearchService _searchService;

  WebSearchTool(this._searchService);

  @override
  String get name => 'web_search_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    try {
      final results = await _searchService.search(contextPayload);
      return {
        'query': contextPayload,
        'results': results,
        'count': results.length,
      };
    } catch (e) {
      return {'error': 'Search failed: $e', 'query': contextPayload};
    }
  }
}
