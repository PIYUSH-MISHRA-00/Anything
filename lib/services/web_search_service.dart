import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'groq_service.dart';

final webSearchServiceProvider = Provider<WebSearchService>((ref) {
  final groq = ref.watch(groqServiceProvider);
  return WebSearchService(groq);
});

/// Web search service that uses AI to synthesize search results.
/// In production, integrate with a real search API (SerpAPI, Brave Search, etc.)
class WebSearchService {
  final GroqService _groq;

  WebSearchService(this._groq);

  Future<List<Map<String, String>>> search(String query) async {
    // Use AI to generate simulated search results based on knowledge
    final response = await _groq.generateResponse(
      prompt: 'Search query: $query',
      systemPrompt: '''You are a search results generator. Given a query, provide 3-5 relevant search results.

Output ONLY a valid JSON array. No markdown. No explanation.

Format:
[
  {"title": "Result title", "snippet": "Brief description", "url": "https://example.com"},
  {"title": "Another result", "snippet": "Description", "url": "https://example.com"}
]''',
    );

    try {
      final startIdx = response.indexOf('[');
      final endIdx = response.lastIndexOf(']');
      if (startIdx != -1 && endIdx != -1) {
        final jsonStr = response.substring(startIdx, endIdx + 1);
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((item) => Map<String, String>.from(
          (item as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
        )).toList();
      }
    } catch (_) {}

    return [
      {'title': 'Search result for: $query', 'snippet': 'AI-generated result', 'url': ''},
    ];
  }
}
