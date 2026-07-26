/// The Anything Kernel — intelligence and orchestration authority.
///
/// Processes Intents through a pipeline:
/// Intent → Classification → Understanding → Experience Resolution →
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
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:anything/synthesis/synthesis_planner.dart';
import 'package:anything/synthesis/blueprint_to_spec.dart';
import 'package:anything/synthesis/blueprint_validator.dart';

/// The Anything Kernel.
class AnythingKernel {
  final ExperienceResolver _experienceResolver;
  final CapabilityRegistry _capabilityRegistry;
  final ModelUnderstandingService _understandingService;
  final IntentClassifier _classifier;
  final KnowledgeAcquisitionEngine _knowledgeEngine;
  final ApplicationReasoner _reasoner;

  AnythingKernel({
    required ModelProviderRegistry providerRegistry,
    ExperienceResolver? experienceResolver,
    CapabilityRegistry? capabilityRegistry,
    KnowledgeAcquisitionEngine? knowledgeEngine,
    ApplicationReasoner? reasoner,
  }) : _experienceResolver = experienceResolver ?? ExperienceResolver(),
       _capabilityRegistry = capabilityRegistry ?? CapabilityRegistry(),
       _understandingService = ModelUnderstandingService(providerRegistry),
       _classifier = IntentClassifier(),
       _knowledgeEngine = knowledgeEngine ?? KnowledgeAcquisitionEngine(),
       _reasoner = reasoner ?? const DeterministicReasoner();

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

      // Step 5: Reason about the application (new synthesis path)
      final planner = SynthesisPlanner(_reasoner);
      final synthesisResult = await planner.plan(understanding);

      // Check if reasoning needs a provider
      if (synthesisResult.notes.any((n) => n.contains('Provider required'))) {
        return ProviderRequired(
          message: 'Connect an AI provider to create this kind of app',
          timestamp: DateTime.now(),
        );
      }

      // Step 6: Validate blueprint
      final validation = BlueprintValidator.validate(synthesisResult.blueprint);
      if (!validation.isValid) {
        return PlanningFailed(
          error: validation.errors.join('; '),
          message: 'Blueprint validation failed',
          timestamp: DateTime.now(),
        );
      }

      // Step 7: Convert to ExperienceSpec
      final spec = BlueprintToSpecConverter.convert(synthesisResult.blueprint);

      // Step 8: Acquire knowledge if needed
      if (spec.knowledgeRequirements.isNotEmpty) {
        await _knowledgeEngine.acquire(
          requirements: spec.knowledgeRequirements,
          queryHints: [understanding.objective],
        );
      }

      // Step 9: Resolve capabilities
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

      // Step 10: Build ExecutionPlan
      final plan = _buildPlan(spec);

      // Step 11: Validate plan
      final planValidation = plan.validate();
      if (!planValidation.isValid) {
        return PlanningFailed(
          error: planValidation.errors.join('; '),
          message: 'Planning encountered issues',
          timestamp: DateTime.now(),
        );
      }

      // Step 12: Return the plan
      return ExecutionPlanReady(
        plan: plan,
        specification: spec,
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
