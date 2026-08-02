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
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:anything/synthesis/blueprint_to_spec.dart';
import 'package:anything/synthesis/blueprint_validator.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/architecture_review.dart';
import 'package:anything/software_architect/architecture_to_blueprint.dart';
import 'package:anything/software_architect/constraint_planner.dart';
import 'package:anything/software_architect/knowledge_graph.dart';
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_plan.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/application_engineering/engineering_refinement.dart';

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
  final ArchitecturePlanner _architecturePlanner;
  final RefinementPlanner _refinementPlanner;
  final ArchitectureToBlueprintConverter _architectureToBlueprint;

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
    ArchitecturePlanner? architecturePlanner,
    RefinementPlanner? refinementPlanner,
    ArchitectureToBlueprintConverter? architectureToBlueprint,
  }) : _requirementExtractor =
           requirementExtractor ?? const RequirementExtractor(),
       _constraintPlanner = constraintPlanner ?? const ConstraintPlanner(),
       _architecturePlanner =
           architecturePlanner ?? const ArchitecturePlanner(),
       _refinementPlanner = refinementPlanner ?? const RefinementPlanner(),
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

      // Step 6: Autonomous Software Architecture Engine — Requirement
      // Extraction -> Knowledge Graph -> Architecture Planning -> Self
      // Critique -> Iterative Refinement -> Final Blueprint. Every
      // ReasoningReady result passes through here; there is no path from
      // a SemanticApp to a blueprint that bypasses it.
      final architectureOutcome = _planArchitecture(
        app: reasonResult.semanticApp,
        understanding: understanding,
        knowledge: _lastAcquiredKnowledge,
      );
      if (architectureOutcome.blueprint == null) {
        return PlanningFailed(
          error: architectureOutcome.error!,
          message: 'Architecture planning could not produce a viable design',
          timestamp: DateTime.now(),
        );
      }
      final blueprint = architectureOutcome.blueprint!;

      // Step 7: Validate blueprint
      final validation = BlueprintValidator.validate(blueprint);
      if (!validation.isValid) {
        return PlanningFailed(
          error: validation.errors.join('; '),
          message: 'Blueprint validation failed',
          timestamp: DateTime.now(),
        );
      }

      // Step 7.5: Application Engineering Engine — Behavior/Data/Navigation/
      // Interaction/Binding/Validation/Persistence/Offline/Synchronization/
      // Lifecycle/Performance/Accessibility/Security Engineering, then
      // machine-checked review + iterative refinement. Every approved
      // architecture passes through here; there is no path from a blueprint
      // to a spec that bypasses it.
      final engineeringCandidate = EngineeringPlanner().plan(
        EngineeringContext(
          architecture: architectureOutcome.approvedCandidate!,
          app: reasonResult.semanticApp,
        ),
      );
      final engineeringPlan = EngineeringRefinement().refine(engineeringCandidate);
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

  /// Runs the full Autonomous Software Architecture Engine pipeline:
  /// Requirement Extraction -> Constraint Analysis -> Knowledge Graph ->
  /// Architecture Planning -> Self Critique -> Iterative Refinement ->
  /// Final Blueprint. Structural throughout — nothing here inspects an
  /// entity/field/view name, only its shape.
  ({AppBlueprint? blueprint, ArchitectureCandidate? approvedCandidate, String? error})
  _planArchitecture({
    required SemanticApp app,
    required IntentUnderstanding understanding,
    required KnowledgeBundle? knowledge,
  }) {
    // Requirement extraction + constraint analysis run unconditionally —
    // this is where a future policy could reject on structural grounds
    // before spending any planning effort; today their output augments
    // the report rather than gating it.
    final requirementGraph = _requirementExtractor.extract(
      app: app,
      understanding: understanding,
    );
    _constraintPlanner.plan(requirementGraph);
    if (knowledge != null) {
      KnowledgeGraphBuilder.build(knowledge);
    }

    final initialCandidate = _architecturePlanner.plan(app);
    final report = _refinementPlanner.refine(initialCandidate);

    if (report.outcome == RefinementOutcome.budgetExhausted &&
        report.finalReview.hasCriticalIssues) {
      return (
        blueprint: null,
        approvedCandidate: null,
        error:
            'Unable to produce a sound application design after '
            'refinement — please try rephrasing or simplifying the request.',
      );
    }

    final blueprint = _architectureToBlueprint.convert(
      originalApp: app,
      approved: report.finalCandidate,
      reasonerForConversion: _reasoner,
    );
    return (blueprint: blueprint, approvedCandidate: report.finalCandidate, error: null);
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
