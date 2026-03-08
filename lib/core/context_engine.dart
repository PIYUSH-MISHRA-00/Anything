import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../memory/memory_manager.dart';

final contextEngineProvider = Provider<ContextEngine>((ref) {
  final memoryManager = ref.watch(memoryManagerProvider);
  return ContextEngine(memoryManager);
});

class ContextEngine {
  final MemoryManager _memoryManager;

  ContextEngine(this._memoryManager);

  Future<String> compileContext() async {
    // Check if personal context learning is enabled
    final isEnabledStr = await _memoryManager.getPreference('personal_context_learning_enabled');
    final isEnabled = isEnabledStr == 'true';

    if (!isEnabled) {
      return 'Context learning disabled by user.';
    }

    // Ideally, we would fetch frequent workflows, preferred tools, etc.
    final recentMemories = await _memoryManager.getConversations();
    if (recentMemories.isEmpty) {
      return 'No historical context available.';
    }

    // Return string summary of context
    return 'User prefers visual dashboards. Recently asked about: ${recentMemories.last['content']}';
  }
}
