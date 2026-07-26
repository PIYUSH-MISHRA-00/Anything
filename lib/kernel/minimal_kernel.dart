/// Minimal Kernel implementation for Stage 3.
///
/// Accepts and validates Intents, returns typed acknowledgment.
/// Does NOT implement full planning, code generation, or Experience creation.
library;

import 'dart:async';

import '../core/contracts/intent.dart';
import '../core/contracts/model_provider.dart';

/// Result of kernel intent processing.
class KernelResult {
  final bool success;
  final Intent intent;
  final String message;
  final DateTime processedAt;

  const KernelResult({
    required this.success,
    required this.intent,
    required this.message,
    required this.processedAt,
  });
}

/// Minimal kernel that accepts and validates intents.
///
/// Stage 3: validates intent, checks provider availability,
/// returns acknowledgment. Does NOT create Experiences yet.
class MinimalKernel {
  final ModelProviderRegistry _providerRegistry;

  MinimalKernel(this._providerRegistry);

  /// Process an intent through the kernel.
  ///
  /// Returns a [KernelResult] indicating success or failure.
  Future<KernelResult> processIntent(Intent intent) async {
    // Validate intent
    if (!intent.canSubmit) {
      return KernelResult(
        success: false,
        intent: intent.copyWith(status: IntentStatus.failed),
        message: 'Intent cannot be submitted',
        processedAt: DateTime.now(),
      );
    }

    // Check if a provider is available
    final provider = _providerRegistry.activeProvider;
    if (provider == null || !provider.isConfigured) {
      return KernelResult(
        success: false,
        intent: intent.copyWith(status: IntentStatus.awaitingProvider),
        message: 'Connect an AI provider to create new things',
        processedAt: DateTime.now(),
      );
    }

    // Intent accepted — update status
    final acceptedIntent = intent.copyWith(
      status: IntentStatus.accepted,
      updatedAt: DateTime.now(),
    );

    return KernelResult(
      success: true,
      intent: acceptedIntent,
      message: 'Intent understood',
      processedAt: DateTime.now(),
    );
  }
}
