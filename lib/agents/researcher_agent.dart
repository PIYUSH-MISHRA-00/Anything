import '../services/groq_service.dart';

class ResearcherAgent {
  final GroqService _groq;
  ResearcherAgent(this._groq);

  /// Researches information based on the user request and plan.
  Future<String> research(String userRequest, String plan) async {
    return await _groq.generateResponse(
      prompt: 'User request: $userRequest\n\nPlan:\n$plan',
      systemPrompt: '''You are the Research Agent for the "Anything" AI system.
Given a user request and a plan, gather relevant knowledge and information.

Provide structured research findings as bullet points organized by topic.
Include key facts, data points, and relevant context.
Be thorough but concise. Maximum 300 words.

Output ONLY the research findings, nothing else.''',
    );
  }
}
