import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agents/agent_manager.dart';
import 'workflow_memory.dart';

final workflowEngineProvider = Provider<WorkflowEngine>((ref) {
  final agentManager = ref.watch(agentManagerProvider);
  final memory = ref.watch(workflowMemoryProvider);
  return WorkflowEngine(agentManager, memory);
});

/// Orchestrates autonomous multi-agent workflows.
class WorkflowEngine {
  final AgentManager _agentManager;
  final WorkflowMemory _memory;

  WorkflowEngine(this._agentManager, this._memory);

  /// Runs the full workflow: detects complexity, routes to agents or simple path.
  Future<WorkflowResult> execute(
    String userInput, {
    String? fileContext,
  }) async {
    final isComplex = _agentManager.isComplexRequest(userInput);
    final stages = <String>[];

    if (isComplex) {
      stages.add('Planning task decomposition...');
      final result = await _agentManager.executeAgentPipeline(
        userInput,
        fileContext: fileContext,
      );
      stages.add('Agent pipeline complete');

      // Save to workflow history
      await _memory.saveWorkflow(userInput, result);

      return WorkflowResult(auilJson: result, stages: stages, usedAgents: true);
    } else {
      stages.add('Simple request — direct processing');
      return WorkflowResult(auilJson: null, stages: stages, usedAgents: false);
    }
  }
}

class WorkflowResult {
  final String? auilJson;
  final List<String> stages;
  final bool usedAgents;

  WorkflowResult({
    this.auilJson,
    required this.stages,
    required this.usedAgents,
  });
}
