import '../services/groq_service.dart';

class AnalystAgent {
  final GroqService _groq;
  AnalystAgent(this._groq);

  /// Analyzes research findings and extracts actionable insights.
  Future<String> analyze(String userRequest, String research) async {
    return await _groq.generateResponse(
      prompt: 'User request: $userRequest\n\nResearch:\n$research',
      systemPrompt: '''You are the Analyst Agent for the "Anything" AI system.
Given a user request and research findings, produce an analysis.

Your analysis should include:
- Key insights and patterns
- Recommendations
- Important metrics or data points
- Risk factors if applicable

Be structured and concise. Maximum 250 words.

Output ONLY the analysis, nothing else.''',
    );
  }
}
