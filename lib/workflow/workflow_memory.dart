import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../memory/memory_manager.dart';

final workflowMemoryProvider = Provider<WorkflowMemory>((ref) {
  final memoryManager = ref.watch(memoryManagerProvider);
  return WorkflowMemory(memoryManager);
});

/// Persists workflow history and results for later retrieval.
class WorkflowMemory {
  final MemoryManager _memoryManager;

  WorkflowMemory(this._memoryManager);

  Future<void> saveWorkflow(String input, String result) async {
    await _memoryManager.saveConversation('workflow_input', input);
    await _memoryManager.saveConversation('workflow_result', result);
  }
}
