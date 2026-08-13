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

  /// IS-P22 policy: application generation REQUIRES a configured AI provider.
  /// When true (production), a records/collection/network app is NEVER built
  /// deterministically as a silent substitute for AI — the user is told to
  /// connect a provider. Trivial LOCAL tools (calculator/timer) still build.
  /// Defaults to FALSE so the large pipeline-mechanics test corpus (which drives
  /// the deterministic path with no live model) keeps working. PRODUCTION
  /// (`AppComposition.production`) opts into strict — that is the path the
  /// owner's app runs, so the policy is enforced where it matters and verified
  /// explicitly by `p22_ai_required_policy_test`.
  final bool requireProviderForGeneration;

  CompositeApplicationReasoner({
    DeterministicReasoner? deterministic,
    ModelProviderRegistry? providerRegistry,
    this.requireProviderForGeneration = false,
  }) : _deterministic = deterministic ?? const DeterministicReasoner(),
       _providerRegistry = providerRegistry;

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    final provider = _providerRegistry?.activeProvider;
    final hasProvider = provider != null && provider.isConfigured;

    // Step 1: Try deterministic reasoning
    final deterministicResult = await _deterministic.reason(context);

    // IS-P22 POLICY: application generation REQUIRES AI. A deterministic
    // records/collection/network app must NEVER be silently substituted for
    // AI generation — that is what made every app look templated. Only trivial
    // LOCAL tools (calculator, timer — tagged 'capability-shell') may be built
    // without a provider; everything else must connect an AI provider first.
    if (deterministicResult is ReasoningReady) {
      final app = deterministicResult.semanticApp;
      final isLocalTool = app.tags.contains('capability-shell');
      if (isLocalTool) return deterministicResult;
      // App generation.
      if (hasProvider) {
        final modelResult =
            await ModelApplicationReasoner(provider).reason(context);
        if (modelResult is ReasoningReady) return modelResult;
        // Model configured but failed.
        if (requireProviderForGeneration) return modelResult;
        return deterministicResult; // lenient (tests): keep the shell
      }
      // No provider.
      if (requireProviderForGeneration) return const ReasoningProviderRequired();
      return deterministicResult; // lenient (tests)
    }

    if (deterministicResult is ReasoningClarificationRequired) {
      return deterministicResult;
    }
    if (deterministicResult is ReasoningKnowledgeRequired) {
      return deterministicResult;
    }
    if (deterministicResult is ReasoningFailed) {
      return deterministicResult;
    }

    // Step 2: Deterministic returned ReasoningProviderRequired.
    if (!hasProvider) {
      if (requireProviderForGeneration) return const ReasoningProviderRequired();
      // Lenient (tests): honest best-effort records app so pipeline mechanics
      // can be exercised without a live model.
      final fallback = _deterministic.tryBestEffortPrimaryEntity(
        context.understanding.objective,
      );
      if (fallback != null) return ReasoningReady(semanticApp: fallback);
      return const ReasoningProviderRequired();
    }

    // Step 3: model reasoner. A configured-but-failing provider surfaces its
    // classified failure; only the lenient path substitutes a best-effort app.
    final modelResult = await ModelApplicationReasoner(provider).reason(context);
    if (modelResult is ReasoningFailed && !requireProviderForGeneration) {
      final fallback = _deterministic.tryBestEffortPrimaryEntity(
        context.understanding.objective,
      );
      if (fallback != null) return ReasoningReady(semanticApp: fallback);
    }
    return modelResult;
  }
}
