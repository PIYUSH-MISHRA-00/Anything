import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/groq_service.dart';

final intentEngineProvider = Provider<IntentEngine>((ref) {
  final groqService = ref.watch(groqServiceProvider);
  return IntentEngine(groqService);
});

class IntentEngine {
  final GroqService _groqService;

  IntentEngine(this._groqService);

  Future<String> analyzeIntent(String userInput) async {
    final systemPrompt = '''
You are the Intent Engine for the "Anything" application. 
The user will provide free-text input ("intent").
Your job is to analyze this input and generate a raw JSON response that the app will use to determine which tools and generative UI schema to use.
Format:
{
  "analyzed_intent": "Short summary of what the user wants",
  "category": "productivity|search|entertainment|etc",
  "suggested_workspace_type": "dashboard|form|chat|canvas",
  "tools_needed": ["tool_name_a", "tool_name_b"]
}
Reply ONLY with valid, raw JSON. Do not include markdown blocks.
''';

    return await _groqService.generateResponse(
      prompt: userInput,
      systemPrompt: systemPrompt,
    );
  }
}
