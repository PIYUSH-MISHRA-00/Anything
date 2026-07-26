/// Kernel contract for Anything v2.
///
/// The Kernel is the central orchestrator that plans and coordinates
/// all activity within Anything. It receives intents, creates execution
/// plans, invokes capabilities, and manages the overall lifecycle of
/// experiences.
///
/// The Kernel does NOT depend on Flutter widgets or UI implementations.
/// It communicates through contracts and events.
library;

import 'dart:async';

import 'capability.dart';
import 'experience.dart';
import 'intent.dart';

/// The execution plan produced by the Kernel for fulfilling an [Intent].
class ExecutionPlan {
  /// Unique identifier for this plan.
  final String id;

  /// The intent this plan fulfills.
  final IntentId intentId;

  /// Ordered list of steps to execute.
  final List<ExecutionStep> steps;

  /// Estimated total execution time.
  final Duration? estimatedDuration;

  /// When this plan was created.
  final DateTime createdAt;

  const ExecutionPlan({
    required this.id,
    required this.intentId,
    required this.steps,
    this.estimatedDuration,
    required this.createdAt,
  });
}

/// A single step in an [ExecutionPlan].
class ExecutionStep {
  /// Step number (1-indexed).
  final int order;

  /// The capability to invoke.
  final CapabilityId capabilityId;

  /// Parameters for the capability.
  final Map<String, dynamic> parameters;

  /// Description of what this step does.
  final String description;

  /// Dependencies on previous steps (step numbers).
  final List<int> dependencies;

  /// Whether this step can run in parallel with others.
  final bool canParallelize;

  const ExecutionStep({
    required this.order,
    required this.capabilityId,
    this.parameters = const {},
    required this.description,
    this.dependencies = const [],
    this.canParallelize = false,
  });
}

/// The Kernel contract.
///
/// The Kernel is responsible for:
/// - Analyzing user intents
/// - Creating execution plans
/// - Orchestrating capability invocation
/// - Managing experience lifecycle
/// - Coordinating with the Runtime
///
/// Implementations must NOT depend on Flutter widgets or UI code.
abstract class Kernel {
  /// Analyze raw user input and produce a structured [Intent].
  Future<Intent> analyzeIntent(String userInput);

  /// Create an [ExecutionPlan] for fulfilling the given [Intent].
  Future<ExecutionPlan> createPlan(Intent intent);

  /// Execute a plan, producing an Experience.
  ///
  /// Returns a stream of execution events for progress tracking.
  Stream<KernelEvent> executePlan(ExecutionPlan plan);

  /// Get all registered capabilities.
  List<Capability> getCapabilities();

  /// Register a new capability.
  void registerCapability(Capability capability);

  /// Get an experience by ID.
  Future<Experience?> getExperience(ExperienceId id);

  /// List all experiences.
  Future<List<Experience>> listExperiences();

  /// Delete an experience.
  Future<void> deleteExperience(ExperienceId id);
}

/// Events emitted by the Kernel during execution.
sealed class KernelEvent {
  /// Timestamp of the event.
  final DateTime timestamp;

  const KernelEvent({required this.timestamp});
}

/// Intent analysis started.
class IntentAnalysisStarted extends KernelEvent {
  final String rawInput;

  const IntentAnalysisStarted({
    required this.rawInput,
    required super.timestamp,
  });
}

/// Intent analysis completed.
class IntentAnalysisCompleted extends KernelEvent {
  final Intent intent;

  const IntentAnalysisCompleted({
    required this.intent,
    required super.timestamp,
  });
}

/// Execution plan created.
class PlanCreated extends KernelEvent {
  final ExecutionPlan plan;

  const PlanCreated({required this.plan, required super.timestamp});
}

/// A step in the execution plan started.
class StepStarted extends KernelEvent {
  final ExecutionStep step;

  const StepStarted({required this.step, required super.timestamp});
}

/// A step completed successfully.
class StepCompleted extends KernelEvent {
  final ExecutionStep step;
  final CapabilityResult result;

  const StepCompleted({
    required this.step,
    required this.result,
    required super.timestamp,
  });
}

/// A step failed.
class StepFailed extends KernelEvent {
  final ExecutionStep step;
  final String error;

  const StepFailed({
    required this.step,
    required this.error,
    required super.timestamp,
  });
}

/// The entire plan execution completed.
class PlanCompleted extends KernelEvent {
  final Experience experience;

  const PlanCompleted({required this.experience, required super.timestamp});
}

/// The plan execution failed.
class PlanFailed extends KernelEvent {
  final String error;

  const PlanFailed({required this.error, required super.timestamp});
}
