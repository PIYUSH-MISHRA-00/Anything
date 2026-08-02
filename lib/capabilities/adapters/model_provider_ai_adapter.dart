/// Real AiProvider backing AiCapability, wrapping the already-real BYOK
/// `ModelProviderRegistry`/`ModelProvider` abstraction (R1: wiring two
/// already-canonical systems together, never a second AI pathway). Reads
/// `registry.activeProvider` at call time (not a snapshot), so switching
/// the active provider takes effect immediately.
library;

import '../../core/contracts/model_provider.dart';
import '../builtin/ai_capability.dart';

class ModelProviderAiAdapter implements AiProvider {
  final ModelProviderRegistry _registry;

  const ModelProviderAiAdapter(this._registry);

  @override
  Future<String> generate(String prompt, {String? systemPrompt}) async {
    final provider = _registry.activeProvider;
    if (provider == null) {
      throw StateError('No active AI provider configured.');
    }
    final messages = [
      if (systemPrompt != null) ModelMessage.system(systemPrompt),
      ModelMessage.user(prompt),
    ];
    final response = await provider.generate(ModelRequest(messages: messages));
    return response.text;
  }
}
