/// The Anything Kernel — intelligence and orchestration authority.
///
/// Processes Intents through a pipeline:
/// Intent → Classification → Understanding → Experience Resolution →
/// Reasoning (with knowledge refinement loop) →
/// Specification → Capability Resolution → Plan → Validation → Outcome
///
/// The Kernel does NOT render UI, access SQLite directly,
/// or depend on specific providers.
library;

import 'dart:async';

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/kernel/understanding/model_understanding_service.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/kernel/planning/execution_plan.dart';
import 'package:anything/kernel/resolution/experience_resolver.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:anything/synthesis/blueprint_to_spec.dart';
import 'package:anything/synthesis/blueprint_validator.dart';
import 'package:anything/software_architect/architecture_to_blueprint.dart';
import 'package:anything/software_architect/constraint_planner.dart';
import 'package:anything/software_architect/knowledge_graph.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/feature_discovery/feature_plan.dart';
import 'package:anything/feature_discovery/feature_refinement.dart';
import 'package:anything/solution_reasoning/solution_explorer.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/design_review/design_review_engine.dart';
import 'package:anything/design_review/review_approval.dart';
import 'package:anything/design_review/review_context.dart';
import 'package:anything/design_review/review_history.dart';
import 'package:anything/design_review/review_memory.dart';
import 'package:anything/evolution/evolution_context.dart';
import 'package:anything/evolution/evolution_engine.dart';
import 'package:anything/evolution/evolution_history.dart';
import 'package:anything/evolution/evolution_memory.dart';

/// Maximum knowledge refinement rounds (trusted limit).
const int _maxKnowledgeRounds = 2;

/// Maximum resources across all accumulated knowledge bundles.
const int _maxKnowledgeResources = 50;

/// Maximum total characters across all accumulated knowledge content.
const int _maxKnowledgeContentChars = 16000;

/// Maximum requirements in accumulated knowledge.
const int _maxKnowledgeRequirements = 20;

/// Maximum warnings in accumulated knowledge.
const int _maxKnowledgeWarnings = 20;

/// Consumer-safe message for knowledge loop limit exceeded.
const String _knowledgeLoopLimitMessage =
    'Unable to create this app. The system could not gather enough '
    'information to build a reliable application in this domain.';

/// Consumer-safe message for knowledge acquisition failure.
const String _knowledgeFailureMessage =
    'Unable to gather the information needed to build this app. '
    'Please try a simpler request or a different approach.';

/// The Anything Kernel.
class AnythingKernel {
  final ExperienceResolver _experienceResolver;
  final CapabilityRegistry _capabilityRegistry;
  final ModelUnderstandingService _understandingService;
  final IntentClassifier _classifier;
  final KnowledgeAcquisitionEngine _knowledgeEngine;
  final ApplicationReasoner _reasoner;
  final RequirementExtractor _requirementExtractor;
  final ConstraintPlanner _constraintPlanner;
  final FeatureDiscoveryEngine _featureDiscoveryEngine;
  final FeatureRefinement _featureRefinement;
  final SolutionExplorer _solutionExplorer;
  final DesignReviewEngine _designReviewEngine;
  final EvolutionEngine _evolutionEngine;
  final ArchitectureToBlueprintConverter _architectureToBlueprint;

  /// Every Design Review session this Kernel instance has ever run, and a
  /// memory of accepted/fixed decisions keyed by structural fingerprint —
  /// both persist for the lifetime of this Kernel instance (never reset
  /// per call), so a later request producing the same structural shape
  /// genuinely reuses prior review findings rather than re-deriving them.
  final ReviewHistory _reviewHistory = ReviewHistory();
  final ReviewMemory _reviewMemory = ReviewMemory();

  /// Every Evolution pass this Kernel instance has ever run, and a memory
  /// of accepted/rejected proposals keyed by structural fingerprint — the
  /// Vision Milestone V7 counterpart to [_reviewHistory]/[_reviewMemory],
  /// same lifetime and reuse contract.
  final EvolutionHistory _evolutionHistory = EvolutionHistory();
  final EvolutionMemory _evolutionMemory = EvolutionMemory();

  /// The knowledge accumulated by the most recent `_reasonWithKnowledgeLoop`
  /// call — read immediately afterward by `processIntent` to build the
  /// KnowledgeGraph. Never persisted, never shared across calls.
  KnowledgeBundle? _lastAcquiredKnowledge;

  AnythingKernel({
    required ModelProviderRegistry providerRegistry,
    ExperienceResolver? experienceResolver,
    CapabilityRegistry? capabilityRegistry,
    KnowledgeAcquisitionEngine? knowledgeEngine,
    ApplicationReasoner? reasoner,
    RequirementExtractor? requirementExtractor,
    ConstraintPlanner? constraintPlanner,
    FeatureDiscoveryEngine? featureDiscoveryEngine,
    FeatureRefinement? featureRefinement,
    SolutionExplorer? solutionExplorer,
    DesignReviewEngine? designReviewEngine,
    EvolutionEngine? evolutionEngine,
    ArchitectureToBlueprintConverter? architectureToBlueprint,
  }) : _requirementExtractor =
           requirementExtractor ?? const RequirementExtractor(),
       _constraintPlanner = constraintPlanner ?? const ConstraintPlanner(),
       _featureDiscoveryEngine = featureDiscoveryEngine ?? const FeatureDiscoveryEngine(),
       _featureRefinement = featureRefinement ?? const FeatureRefinement(),
       _solutionExplorer = solutionExplorer ?? const SolutionExplorer(),
       _designReviewEngine = designReviewEngine ?? const DesignReviewEngine(),
       _evolutionEngine = evolutionEngine ?? const EvolutionEngine(),
       _architectureToBlueprint =
           architectureToBlueprint ?? const ArchitectureToBlueprintConverter(),
       _experienceResolver = experienceResolver ?? ExperienceResolver(),
       _capabilityRegistry = capabilityRegistry ?? CapabilityRegistry(),
       _understandingService = ModelUnderstandingService(providerRegistry),
       _classifier = IntentClassifier(),
       _knowledgeEngine = knowledgeEngine ?? KnowledgeAcquisitionEngine(),
       _reasoner =
           reasoner ??
           CompositeApplicationReasoner(providerRegistry: providerRegistry);

  /// Process an intent through the full Kernel pipeline.
  Future<KernelOutcome> processIntent(Intent intent) async {
    try {
      // Step 1: Classify the intent
      final category = _classifier.classify(intent.expression);

      // Step 2: Check for existing Experience
      final existingResolution = _experienceResolver.resolve(intent.expression);

      // If an existing Experience matches, return it
      if (existingResolution.status == ExistingExperienceStatus.found) {
        return OpenExistingExperience(
          experienceId: existingResolution.experienceId!,
          experienceName: existingResolution.experienceName!,
          message: 'Opening ${existingResolution.experienceName}',
          timestamp: DateTime.now(),
        );
      }

      // Step 3: Understand the intent (may use model)
      final understanding = await _understandingService.understand(
        intent: intent,
        category: category,
        existingResolution: existingResolution,
        availableCapabilities: _capabilityRegistry.all,
      );

      // Step 4: Check if clarification is needed
      final criticalAmbiguities = understanding.ambiguities
          .where((a) => a.severity == AmbiguitySeverity.userInputRequired)
          .toList();

      if (criticalAmbiguities.isNotEmpty) {
        return ClarificationRequired(
          request: ClarificationRequest(
            question: criticalAmbiguities.first.description,
            reason: 'This needs your input before Anything can proceed',
            expectedResponseType: ClarificationResponseType.text,
          ),
          message: 'Need one detail',
          timestamp: DateTime.now(),
        );
      }

      // Step 5: Reason about the application with knowledge refinement loop
      final reasonResult = await _reasonWithKnowledgeLoop(understanding);

      // Handle non-success outcomes from reasoning
      switch (reasonResult) {
        case ReasoningReady():
          // Continue to step 6
          break;
        case ReasoningClarificationRequired():
          return ClarificationRequired(
            request: ClarificationRequest(
              question: reasonResult.question,
              reason: 'This needs your input',
              expectedResponseType: ClarificationResponseType.text,
            ),
            message: reasonResult.question,
            timestamp: DateTime.now(),
          );
        case ReasoningProviderRequired():
          return ProviderRequired(
            message: 'Connect an AI provider to create this kind of app',
            timestamp: DateTime.now(),
          );
        case ReasoningKnowledgeRequired():
          // Knowledge was requested but loop exhausted without resolution
          return PlanningFailed(
            error: _knowledgeFailureMessage,
            message: _knowledgeFailureMessage,
            timestamp: DateTime.now(),
          );
        case ReasoningUnsupported():
          return UnsupportedIntent(
            reason: reasonResult.reason,
            message: 'This type of app cannot be created',
            timestamp: DateTime.now(),
          );
        case ReasoningFailed():
          return PlanningFailed(
            error: reasonResult.error,
            message: 'Something went wrong during reasoning',
            timestamp: DateTime.now(),
          );
      }

      // Step 5.5: Feature Discovery Engine — Requirement Graph -> Knowledge
      // Graph -> Feature Discovery -> Feature Review -> Feature Refinement.
      // Runs before Architecture, per the Vision Milestone V4 pipeline;
      // every ReasoningReady result passes through here, no bypass.
      final requirementGraph = _requirementExtractor.extract(
        app: reasonResult.semanticApp,
        understanding: understanding,
      );
      _constraintPlanner.plan(requirementGraph);
      final knowledgeGraph = _lastAcquiredKnowledge != null
          ? KnowledgeGraphBuilder.build(_lastAcquiredKnowledge!)
          : null;
      final featureGraph = _featureDiscoveryEngine.plan(
        FeatureDiscoveryContext(
          app: reasonResult.semanticApp,
          requirements: requirementGraph,
          knowledge: knowledgeGraph,
        ),
      );
      final featurePlan = _featureRefinement.refine(featureGraph);
      if (featurePlan.outcome == FeatureRefinementOutcome.budgetExhausted &&
          featurePlan.finalReview.hasCriticalIssues) {
        return PlanningFailed(
          error:
              'Unable to produce a sound feature discovery plan after '
              'refinement — please try rephrasing or simplifying the request.',
          message: 'Feature discovery could not produce a viable design',
          timestamp: DateTime.now(),
        );
      }

      // Step 6: Multi-Solution Reasoning & Architecture Selection Engine —
      // Architecture Exploration (reuses ASAE unchanged) -> Multi-Solution
      // Generation -> Tradeoff Analysis -> Solution Review -> Solution
      // Refinement -> Solution Selection. Every ReasoningReady result
      // passes through here; there is no path from a SemanticApp to a
      // blueprint that bypasses it, and never "first candidate wins" —
      // the selected solution is chosen by SolutionSelector's scored,
      // ordered tie-break cascade.
      final dependencyGraph = const DependencyGraphBuilder().build(
        featurePlan.finalGraph.nodes.map((n) => n.candidate).toList(),
      );
      final explorationResult = _solutionExplorer.explore(
        app: reasonResult.semanticApp,
        context: SolutionExplorationContext(
          app: reasonResult.semanticApp,
          featureGraph: featurePlan.finalGraph,
          dependencyGraph: dependencyGraph,
        ),
      );
      if (explorationResult.decision == null) {
        return PlanningFailed(
          error: explorationResult.error!,
          message: 'Solution reasoning could not produce a viable design',
          timestamp: DateTime.now(),
        );
      }
      final solutionDecision = explorationResult.decision!;
      final selectedSolution = solutionDecision.selected;

      final blueprint = _architectureToBlueprint.convert(
        originalApp: reasonResult.semanticApp,
        approved: selectedSolution.architecture,
        reasonerForConversion: _reasoner,
      );

      // Step 7: Validate blueprint
      final validation = BlueprintValidator.validate(blueprint);
      if (!validation.isValid) {
        return PlanningFailed(
          error: validation.errors.join('; '),
          message: 'Blueprint validation failed',
          timestamp: DateTime.now(),
        );
      }

      // Step 7.5: Self-Critique & Autonomous Design Review Engine (SCARE)
      // — Produce -> Review -> Improve -> Review -> Improve -> Approve.
      // The first stage to see the requirement graph, feature graph,
      // dependency graph, selected solution, and blueprint all together;
      // every approved solution passes through here, and Engineering
      // cannot reach ExperienceSpec without a real ReviewApproval — fail
      // closed otherwise.
      final reviewOutcome = _designReviewEngine.review(
        ReviewContext(
          app: reasonResult.semanticApp,
          requirements: requirementGraph,
          featureGraph: featurePlan.finalGraph,
          dependencyGraph: dependencyGraph,
          solution: selectedSolution,
          blueprint: blueprint,
        ),
        memory: _reviewMemory,
        history: _reviewHistory,
      );
      if (!reviewOutcome.approved) {
        return PlanningFailed(
          error: const ReviewApproval().denialReason(reviewOutcome.session.result),
          message: 'Design review did not approve this design',
          timestamp: DateTime.now(),
        );
      }
      final reviewedContext = reviewOutcome.session.result.finalContext;

      // Step 7.6: Application Engineering Engine output. The selected,
      // now review-approved solution already carries its own real
      // EngineeringPlan (computed once during Solution Generation) —
      // reused here rather than recomputed, and reflecting any
      // conservative auto-fixes Design Review applied to its binding
      // graph.
      final engineeringPlan = reviewedContext.solution.engineeringVariation.plan;
      if (engineeringPlan.outcome == EngineeringRefinementOutcome.budgetExhausted &&
          engineeringPlan.finalReview.hasCriticalIssues) {
        return PlanningFailed(
          error:
              'Unable to produce a sound engineering plan after '
              'refinement — please try rephrasing or simplifying the request.',
          message: 'Engineering planning could not produce a viable design',
          timestamp: DateTime.now(),
        );
      }

      // Step 7.7: Autonomous Evolution Engine (Vision Milestone V7) —
      // Observe -> Estimate -> Review -> Approve -> Plan -> Predict. Every
      // approved design is observed for real, structural evolution
      // opportunities (deferred FeatureGraph nodes, missing navigation/
      // search/filtering, offline/sync posture, non-critical Design
      // Review findings) and produces a roadmap. Never blocks creation —
      // unlike Design Review, Evolution Planning cannot fail this
      // pipeline; it only ever adds a roadmap for later use, since
      // "Do NOT automatically execute" applies here even more strongly
      // than at Design Review.
      final evolutionResult = _evolutionEngine.evolve(
        EvolutionContext(reviewContext: reviewedContext, reviewSession: reviewOutcome.session),
        memory: _evolutionMemory,
        history: _evolutionHistory,
      );

      // Step 8: Convert to ExperienceSpec
      final spec = BlueprintToSpecConverter.convert(
        blueprint,
        engineeringPlan: engineeringPlan,
      );

      // Step 8: Resolve capabilities
      final capabilityIds = spec.requiredCapabilities
          .map((c) => c.capabilityId)
          .toList();
      final resolutions = _capabilityRegistry.resolve(capabilityIds);

      final unresolved = resolutions.where((r) => !r.isResolved).toList();
      if (unresolved.isNotEmpty) {
        return UnsupportedIntent(
          reason:
              'Required capabilities not available: '
              '${unresolved.map((r) => r.capabilityId).join(', ')}',
          message: 'Some requirements cannot be met yet',
          timestamp: DateTime.now(),
        );
      }

      // Step 9: Build ExecutionPlan
      final plan = _buildPlan(spec);

      // Step 10: Validate plan
      final planValidation = plan.validate();
      if (!planValidation.isValid) {
        return PlanningFailed(
          error: planValidation.errors.join('; '),
          message: 'Planning encountered issues',
          timestamp: DateTime.now(),
        );
      }

      // Step 11: Return the plan
      return ExecutionPlanReady(
        plan: plan,
        specification: spec,
        blueprint: blueprint,
        engineeringPlan: engineeringPlan,
        featurePlan: featurePlan,
        solutionDecision: solutionDecision,
        reviewSession: reviewOutcome.session,
        evolutionRoadmap: evolutionResult.roadmap,
        message: 'Ready to create',
        timestamp: DateTime.now(),
      );
    } catch (e, stack) {
      return PlanningFailed(
        error: e.toString(),
        stackTrace: stack,
        message: 'Something went wrong during planning',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Reason with knowledge refinement loop.
  ///
  /// Flow:
  /// 1. Reason with understanding
  /// 2. If knowledge required → acquire → re-reason with knowledge
  /// 3. Repeat up to max rounds
  /// 4. If still knowledge required after max rounds → fail
  Future<AppReasoningResult> _reasonWithKnowledgeLoop(
    IntentUnderstanding understanding,
  ) async {
    KnowledgeBundle? knowledgeBundle;
    _lastAcquiredKnowledge = null;
    final capabilityIds = _capabilityRegistry.all.map((c) => c.id).toList();

    for (var round = 0; round <= _maxKnowledgeRounds; round++) {
      final context = ApplicationReasoningContext(
        understanding: understanding,
        knowledge: knowledgeBundle,
        availableCapabilities: capabilityIds,
        round: round,
        maxRounds: _maxKnowledgeRounds,
      );

      final result = await _reasoner.reason(context);

      // If reasoning succeeded or needs clarification/provider/failed,
      // return immediately
      if (result is! ReasoningKnowledgeRequired) {
        return result;
      }

      // Knowledge required — check if we have budget
      if (round >= _maxKnowledgeRounds) {
        // Last round — if only optional requirements remain, try to continue
        // without them. The reasoner produced a result requesting only optional
        // knowledge; we cannot acquire it, so we return the last non-knowledge
        // result if available, or fail.
        final requiredRemaining = result.requirements
            .where((r) => r.required)
            .toList();
        if (requiredRemaining.isEmpty) {
          // Only optional requirements remain and budget is exhausted.
          // Do NOT return ReasoningKnowledgeRequired to the creation pipeline.
          // Fail gracefully — the reasoner cannot produce a valid app without
          // deciding how to handle the absence of optional knowledge.
          return const ReasoningFailed(error: _knowledgeLoopLimitMessage);
        }
        return const ReasoningFailed(error: _knowledgeLoopLimitMessage);
      }

      // Separate required and optional requirements
      final requiredRequirements = result.requirements
          .where((r) => r.required)
          .toList();
      final optionalRequirements = result.requirements
          .where((r) => !r.required)
          .toList();

      // Acquire required knowledge (mandatory)
      KnowledgeBundle? requiredBundle;
      if (requiredRequirements.isNotEmpty) {
        try {
          requiredBundle = await _knowledgeEngine.acquire(
            requirements: requiredRequirements.map((r) {
              return KnowledgeRequirement(
                objective: r.query,
                resourceType: r.resourceType,
                queryHints: r.queryHints,
              );
            }).toList(),
            queryHints: [understanding.objective],
          );

          // Required knowledge failed — do not fabricate
          if (requiredBundle.status == BundleStatus.failed ||
              requiredBundle.isEmpty) {
            return const ReasoningFailed(error: _knowledgeFailureMessage);
          }
        } catch (e) {
          return const ReasoningFailed(error: _knowledgeFailureMessage);
        }
      }

      // Attempt optional knowledge acquisition when budget permits
      KnowledgeBundle? optionalBundle;
      if (optionalRequirements.isNotEmpty) {
        try {
          optionalBundle = await _knowledgeEngine.acquire(
            requirements: optionalRequirements.map((r) {
              return KnowledgeRequirement(
                objective: r.query,
                resourceType: r.resourceType,
                queryHints: r.queryHints,
              );
            }).toList(),
            queryHints: [understanding.objective],
          );
          // Optional knowledge failure is acceptable — continue without it
        } catch (e) {
          // Optional knowledge failure — continue without it
          optionalBundle = null;
        }
      }

      // Merge knowledge bundles — always accumulate into existing bundle
      var accumulated = knowledgeBundle;
      if (requiredBundle != null) {
        accumulated = accumulated == null
            ? requiredBundle
            : accumulated.mergedWith(requiredBundle);
      }
      if (optionalBundle != null) {
        accumulated = accumulated == null
            ? optionalBundle
            : accumulated.mergedWith(optionalBundle);
      }
      knowledgeBundle = accumulated != null
          ? _enforceKnowledgeBudget(accumulated)
          : null;
      _lastAcquiredKnowledge = knowledgeBundle;
    }

    // Should not reach here, but safety fallback
    return const ReasoningFailed(error: _knowledgeLoopLimitMessage);
  }

  /// Enforce trusted budget limits on accumulated knowledge.
  ///
  /// Truncates resources, content, requirements, and warnings to ensure
  /// bounded representation reaching the model and reasoning layers.
  KnowledgeBundle _enforceKnowledgeBudget(KnowledgeBundle bundle) {
    var resources = bundle.resources;
    if (resources.length > _maxKnowledgeResources) {
      resources = resources.sublist(0, _maxKnowledgeResources);
    }

    // Truncate total content size
    var totalChars = 0;
    final truncatedResources = <dynamic>[];
    for (final r in resources) {
      final content = r.content ?? '';
      if (totalChars + content.length > _maxKnowledgeContentChars) break;
      totalChars += content.length;
      truncatedResources.add(r);
    }

    var satisfied = bundle.requirementsSatisfied;
    if (satisfied.length > _maxKnowledgeRequirements) {
      satisfied = satisfied.sublist(0, _maxKnowledgeRequirements);
    }

    var warnings = bundle.warnings;
    if (warnings.length > _maxKnowledgeWarnings) {
      warnings = warnings.sublist(0, _maxKnowledgeWarnings);
    }

    return KnowledgeBundle(
      id: bundle.id,
      status: bundle.status,
      resources: truncatedResources.cast(),
      requirementsSatisfied: satisfied,
      unresolvedRequirements: bundle.unresolvedRequirements,
      warnings: warnings,
      generatedAt: bundle.generatedAt,
    );
  }

  ExecutionPlan _buildPlan(ExperienceSpec spec) {
    final steps = <ExecutionStep>[];

    // Step 1: Validate specification
    steps.add(
      ExecutionStep(
        stepId: 'validate-spec',
        type: StepType.validateImplementation,
        description: 'Validate the experience specification',
        expectedOutputType: 'validation_result',
      ),
    );

    // Step 2: Prepare implementation
    steps.add(
      ExecutionStep(
        stepId: 'prepare-implementation',
        type: StepType.prepareImplementation,
        description: 'Prepare the experience implementation',
        dependencies: ['validate-spec'],
        expectedOutputType: 'implementation_plan',
      ),
    );

    // Step 3: Prepare storage if needed
    if (spec.storageRequirements.requiresDatabase ||
        spec.storageRequirements.requiresFileSystem) {
      steps.add(
        ExecutionStep(
          stepId: 'prepare-storage',
          type: StepType.prepareStorage,
          description: 'Prepare storage layer',
          dependencies: ['validate-spec'],
          expectedOutputType: 'storage_schema',
        ),
      );
    }

    // Step 4: Prepare interface
    steps.add(
      ExecutionStep(
        stepId: 'prepare-interface',
        type: StepType.prepareInterface,
        description: 'Prepare the user interface',
        dependencies: ['prepare-implementation'],
        expectedOutputType: 'ui_specification',
      ),
    );

    // Step 5: Validate implementation
    steps.add(
      ExecutionStep(
        stepId: 'validate-implementation',
        type: StepType.validateImplementation,
        description: 'Validate the complete implementation',
        dependencies: ['prepare-interface'],
        expectedOutputType: 'validation_result',
      ),
    );

    // Step 6: Persist experience
    steps.add(
      ExecutionStep(
        stepId: 'persist-experience',
        type: StepType.persistExperience,
        description: 'Persist the experience to local storage',
        dependencies: ['validate-implementation'],
        expectedOutputType: 'experience_record',
      ),
    );

    // Step 7: Launch experience
    steps.add(
      ExecutionStep(
        stepId: 'launch-experience',
        type: StepType.launchExperience,
        description: 'Launch the experience for the user',
        dependencies: ['persist-experience'],
        expectedOutputType: 'launch_result',
      ),
    );

    return ExecutionPlan(
      id: 'plan-${DateTime.now().millisecondsSinceEpoch}',
      specification: spec,
      steps: steps,
      createdAt: DateTime.now(),
    );
  }
}
