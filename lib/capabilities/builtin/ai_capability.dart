/// AI capability — trusted ModelProvider access for Experiences.
library;

import '../platform/capability_platform.dart';

/// AI provider abstraction for capability use.
abstract class AiProvider {
  Future<String> generate(String prompt, {String? systemPrompt});
}

/// Fake AI provider for testing.
class FakeAiProvider implements AiProvider {
  final String _response;
  int _callCount = 0;

  FakeAiProvider({String response = 'AI response'}) : _response = response;

  int get callCount => _callCount;

  @override
  Future<String> generate(String prompt, {String? systemPrompt}) async {
    _callCount++;
    return _response;
  }
}

/// AI capability for Experiences.
class AiCapability extends PlatformCapability {
  final AiProvider _provider;

  AiCapability({required AiProvider provider, required String experienceId})
    : _provider = provider,
      super(
        id: 'ai',
        name: 'AI',
        description: 'AI inference capabilities',
        supportedOperations: ['generate'],
      );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    if (operation != 'generate') {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unknown AI operation: $operation',
      );
    }

    final prompt = params['prompt'] as String?;
    if (prompt == null || prompt.isEmpty) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.invalidArguments,
        error: 'Prompt required',
      );
    }

    try {
      final result = await _provider.generate(prompt);
      return CapabilityInvocationResult.success(data: {'response': result});
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }
}
