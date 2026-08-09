/// Composite Application Reasoner — orchestrates deterministic and model reasoning.
///
/// Flow:
/// 1. DeterministicReasoner attempts structural reasoning
/// 2. If ReasoningProviderRequired → resolve ModelProvider from registry
/// 3. ModelApplicationReasoner handles complex/novel requests
/// 4. If no provider configured → ReasoningProviderRequired
///
/// This is the production entry point for application reasoning.
library;

import '../core/contracts/model_provider.dart';
import 'application_reasoner.dart';
import 'deterministic_reasoner.dart';
import 'model_reasoner.dart';

/// Composite reasoner that orchestrates deterministic and model-backed reasoning.
///
/// The Kernel should use this as its default reasoner. It automatically
/// falls back to model reasoning when the deterministic reasoner cannot
/// safely handle the intent.
class CompositeApplicationReasoner implements ApplicationReasoner {
  final DeterministicReasoner _deterministic;
  final ModelProviderRegistry? _providerRegistry;

  CompositeApplicationReasoner({
    DeterministicReasoner? deterministic,
    ModelProviderRegistry? providerRegistry,
  }) : _deterministic = deterministic ?? const DeterministicReasoner(),
       _providerRegistry = providerRegistry;

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    // Step 1: Try deterministic reasoning
    final deterministicResult = await _deterministic.reason(context);

    // If deterministic succeeded, use it
    if (deterministicResult is ReasoningReady) {
      return deterministicResult;
    }

    // If deterministic needs clarification, pass through
    if (deterministicResult is ReasoningClarificationRequired) {
      return deterministicResult;
    }

    // If deterministic requests knowledge, pass through
    if (deterministicResult is ReasoningKnowledgeRequired) {
      return deterministicResult;
    }

    // If deterministic failed (not just provider required), propagate error
    if (deterministicResult is ReasoningFailed) {
      return deterministicResult;
    }

    // Step 2: Deterministic returned ReasoningProviderRequired — try model
    final provider = _providerRegistry?.activeProvider;
    if (provider == null || !provider.isConfigured) {
      return const ReasoningProviderRequired();
    }

    // Step 3: Use model reasoner
    //
    // IS-P07: this used to overwrite EVERY failure with "Unable to create
    // this type of app. Please try rephrasing." The redaction was right in
    // intent and wrong in reach — `ModelApplicationReasoner` now performs it
    // at the only place raw exception text exists, and returns a curated
    // sentence for classified provider failures. Overwriting again here
    // discards the one thing the user needed to know.
    return ModelApplicationReasoner(provider).reason(context);
  }
}
