import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/groq_service.dart';
import 'planner_agent.dart';
import 'researcher_agent.dart';
import 'analyst_agent.dart';
import 'builder_agent.dart';

final agentManagerProvider = Provider<AgentManager>((ref) {
  final groq = ref.watch(groqServiceProvider);
  return AgentManager(groq);
});

/// Coordinates multiple AI agents to complete complex multi-step tasks.
class AgentManager {
  final GroqService _groq;

  late final PlannerAgent planner;
  late final ResearcherAgent researcher;
  late final AnalystAgent analyst;
  late final BuilderAgent builder;

  AgentManager(this._groq) {
    planner = PlannerAgent(_groq);
    researcher = ResearcherAgent(_groq);
    analyst = AnalystAgent(_groq);
    builder = BuilderAgent(_groq);
  }

  /// Runs the full agent pipeline for a complex task.
  /// Returns the final AUIL schema JSON string.
  Future<String> executeAgentPipeline(
    String userRequest, {
    String? fileContext,
  }) async {
    // Step 1: Planner decomposes the task
    final plan = await planner.createPlan(userRequest);

    // Step 2: Researcher gathers information
    final research = await researcher.research(userRequest, plan);

    // Step 3: Analyst interprets findings
    final analysis = await analyst.analyze(userRequest, research);

    // Step 4: Builder produces final AUIL output
    final fileSection = fileContext != null
        ? '\nAttached file context:\n$fileContext'
        : '';
    final auil = await builder.buildOutput(
      userRequest,
      plan,
      analysis,
      fileSection,
    );

    return auil;
  }

  /// Determines if a request is complex enough to need the full agent pipeline.
  bool isComplexRequest(String input) {
    final complexPatterns = [
      'research',
      'analyze',
      'create a report',
      'pitch deck',
      'compare',
      'launch',
      'plan',
      'build a',
      'design a',
      'startup',
      'strategy',
      'workflow',
    ];
    final lower = input.toLowerCase();
    return complexPatterns.any((p) => lower.contains(p));
  }
}
