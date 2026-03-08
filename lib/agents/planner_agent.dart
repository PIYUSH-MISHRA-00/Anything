import '../services/groq_service.dart';

class PlannerAgent {
  final GroqService _groq;
  PlannerAgent(this._groq);

  /// Decomposes a complex user request into a structured plan.
  Future<String> createPlan(String userRequest) async {
    return await _groq.generateResponse(
      prompt: userRequest,
      systemPrompt: '''You are the Planner Agent for the "Anything" AI system.
Your job is to break down the user's request into clear, actionable steps.

Output a numbered plan in plain text. Each step should be one sentence.
Maximum 6 steps. Be concise and specific.

Example:
1. Research current market trends for AI startups
2. Identify top 5 competitors
3. Analyze their strengths and weaknesses
4. Generate a strategy recommendation
5. Create a summary dashboard

Output ONLY the plan, nothing else.''',
    );
  }
}
