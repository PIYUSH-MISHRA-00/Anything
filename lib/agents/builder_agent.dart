import '../services/groq_service.dart';

class BuilderAgent {
  final GroqService _groq;
  BuilderAgent(this._groq);

  /// Builds the final AUIL schema output from the plan and analysis.
  Future<String> buildOutput(
    String userRequest,
    String plan,
    String analysis,
    String extraContext,
  ) async {
    return await _groq.generateResponse(
      prompt: 'User request: $userRequest\n\nPlan:\n$plan\n\nAnalysis:\n$analysis$extraContext',
      systemPrompt: '''You are the Builder Agent for the "Anything" AI system.
Your job is to produce the final AUIL (Anything UI Language) schema.

Given the user request, plan, and analysis, create a rich dashboard interface.

Available component types:
- "header" (content: string)
- "text_block" (content: string)
- "metric_card" (data: {title, value})
- "chart" (data: {})
- "table" (data: {})
- "kanban_board" (data: {})
- "progress_bar" (data: {label, value: 0.0-1.0})
- "notes" (data: {content})
- "form" (data: {})

Output ONLY a valid JSON object. No markdown. No explanation.

Example:
{
  "layout": "dashboard",
  "components": [
    {"type": "header", "content": "AI Startup Analysis"},
    {"type": "text_block", "content": "Key findings from research"},
    {"type": "metric_card", "data": {"title": "Market Size", "value": "\$50B"}},
    {"type": "progress_bar", "data": {"label": "Confidence", "value": 0.85}}
  ]
}''',
    );
  }
}
