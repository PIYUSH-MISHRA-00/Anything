import 'tool_registry.dart';

class FileAnalysisTool extends BaseTool {
  @override
  String get name => 'file_analysis_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    // Analyze provided file context
    final lines = contextPayload.split('\n');
    final wordCount = contextPayload.split(RegExp(r'\s+')).length;
    final charCount = contextPayload.length;

    return {
      'line_count': lines.length,
      'word_count': wordCount,
      'character_count': charCount,
      'preview': contextPayload.length > 200
          ? '${contextPayload.substring(0, 200)}...'
          : contextPayload,
      'type': 'text_analysis',
    };
  }
}
