import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/groq_service.dart';
import 'intent_engine.dart';
import 'context_engine.dart';

final reasoningEngineProvider = Provider<ReasoningEngine>((ref) {
  final groqService = ref.watch(groqServiceProvider);
  final intentEngine = ref.watch(intentEngineProvider);
  final contextEngine = ref.watch(contextEngineProvider);
  return ReasoningEngine(groqService, intentEngine, contextEngine);
});

class ReasoningEngine {
  final GroqService _groqService;
  final IntentEngine _intentEngine;
  final ContextEngine _contextEngine;

  ReasoningEngine(this._groqService, this._intentEngine, this._contextEngine);

  Future<String> evaluateAndGenerateAUIL(
    String userInput,
    Map<String, dynamic> toolResults, {
    String? fileContext,
  }) async {
    final intentJson = await _intentEngine.analyzeIntent(userInput);
    final contextData = await _contextEngine.compileContext();

    final fileSection = fileContext != null
        ? '\nAttached File Content:\n$fileContext\n'
        : '';

    final systemPrompt =
        '''
You are the Generative UI Reasoning Engine for the "Anything" application.
Your goal is to output a structured AUIL (Anything UI Language) schema.

Input Context:
User Intent: $intentJson
Personal Context: $contextData
Tool Execution Results: $toolResults
$fileSection
Output requirements:
Return ONLY a valid JSON object matching the AUIL schema. No markdown blocks.

Example output:
{
  "layout": "dashboard",
  "components": [
    { "type": "header", "content": "Your Trip to Japan" },
    { "type": "text_block", "content": "Summary of your plan" },
    { "type": "metric_card", "data": { "title": "Budget", "value": "\$2000" } }
  ]
}
''';

    return await _groqService.generateResponse(
      prompt: 'Generate AUIL for user input: $userInput',
      systemPrompt: systemPrompt,
    );
  }
}
