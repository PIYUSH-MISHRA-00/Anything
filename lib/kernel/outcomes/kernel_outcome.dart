/// Typed Kernel outcome types.
///
/// The Kernel returns one of these after processing an Intent.
/// UI maps these to human-friendly messages.
library;

import '../../application_engineering/engineering_plan.dart';
import '../../backend_engineering/backend_engineering_plan.dart';
import '../../implementation_model/canonical_implementation_model.dart';
import '../../solution_architecture/solution_architecture.dart';
import '../../execution_planning/execution_strategy.dart';
import '../../design_review/review_history.dart' show ReviewSession;
import '../../evolution/evolution_roadmap.dart' show EvolutionRoadmap;
import '../../feature_discovery/feature_plan.dart';
import '../../software_architect/requirement_graph.dart';
import '../../solution_reasoning/solution_decision.dart';
import '../../synthesis/app_blueprint.dart';
import '../specification/experience_spec.dart';
import '../planning/execution_plan.dart';
import '../understanding/intent_understanding.dart';

/// Base class for all Kernel outcomes.
sealed class KernelOutcome {
  final String message;
  final DateTime timestamp;

  const KernelOutcome({required this.message, required this.timestamp});
}

/// An existing Experience was found and opened.
class OpenExistingExperience extends KernelOutcome {
  final String experienceId;
  final String experienceName;

  const OpenExistingExperience({
    required this.experienceId,
    required this.experienceName,
    required super.message,
    required super.timestamp,
  });
}

/// Experience specification is ready for planning.
class ExperienceSpecificationReady extends KernelOutcome {
  final ExperienceSpec specification;
  final IntentUnderstanding understanding;

  const ExperienceSpecificationReady({
    required this.specification,
    required this.understanding,
    required super.message,
    required super.timestamp,
  });
}

/// Execution plan is ready for the Runtime.
class ExecutionPlanReady extends KernelOutcome {
  final ExecutionPlan plan;
  final ExperienceSpec specification;
  final AppBlueprint? blueprint;

  /// The Application Engineering Engine's output for this creation
  /// (Vision Milestone V3), null only for outcomes that never reach
  /// engineering planning (there are none on the production path — the
  /// Kernel always populates this alongside [blueprint]).
  final EngineeringPlan? engineeringPlan;

  /// The Feature Discovery Engine's output for this creation (Vision
  /// Milestone V4) — the approved FeatureGraph that shaped Architecture
  /// and Engineering. Null only for outcomes that never reach feature
  /// discovery (there are none on the production path).
  final FeaturePlan? featurePlan;

  /// The Multi-Solution Reasoning & Architecture Selection Engine's
  /// output for this creation (Vision Milestone V5) — the selected
  /// SolutionCandidate plus every rejected alternative and why. [blueprint]
  /// and [engineeringPlan] above are both derived from
  /// `solutionDecision.selected`, never independently computed. Null only
  /// for outcomes that never reach solution reasoning (there are none on
  /// the production path).
  final SolutionDecision? solutionDecision;

  /// The Self-Critique & Autonomous Design Review Engine's session for
  /// this creation (Vision Milestone V6) — the full review/refine/approve
  /// record. Null only for outcomes that never reach Design Review (there
  /// are none on the production path — reaching this outcome at all
  /// implies `reviewSession` exists and was approved).
  final ReviewSession? reviewSession;

  /// The Autonomous Evolution Engine's (Vision Milestone V7) roadmap for
  /// this creation — Current/Immediate/Next/Later/Future/Experimental
  /// proposals, all reviewed and ranked but never auto-executed. Null
  /// only for outcomes that never reach evolution planning (there are
  /// none on the production path — reaching this outcome at all implies
  /// `evolutionRoadmap` exists).
  final EvolutionRoadmap? evolutionRoadmap;

  /// The Requirement Graph (Vision Milestone V2's RequirementExtractor
  /// output) this creation was planned from (Implementation Milestone
  /// R5) — previously computed and immediately discarded after Feature
  /// Discovery consumed it (MIS-1 Part 2's "Engineering Memory" finding).
  /// Exposed here, additively, so a caller (the creation coordinator) can
  /// persist it as real engineering history. Null only for outcomes that
  /// never reach requirement extraction (there are none on the
  /// production path).
  final RequirementGraph? requirementGraph;

  /// The Backend Engineering Plan (Implementation Milestone R8) —
  /// deterministic Database/API/Authentication/Storage/Background-Jobs/
  /// Deployment specification derived from the same, already-computed
  /// `ArchitectureCandidate`/`SemanticApp` frontend Engineering already
  /// consumes. Null only for outcomes that never reach this point (there
  /// are none on the production path).
  final BackendEngineeringPlan? backendEngineeringPlan;

  /// The Canonical Implementation Model (Implementation Milestone R9) —
  /// real, deterministic, language-independent unification of frontend
  /// [engineeringPlan] and [backendEngineeringPlan] into one implementation-
  /// concept vocabulary reusable by every future language generator. Null
  /// only for outcomes that never reach this point (there are none on the
  /// production path).
  final CanonicalImplementationModel? canonicalImplementationModel;

  /// The Semantic Solution Architecture (Implementation Milestone R17) —
  /// real, architecture-shaped composition of [backendEngineeringPlan]
  /// and the frontend `ArchitectureCandidate` (`solutionDecision.selected
  /// .architecture`), exposed additively for the same reason
  /// [canonicalImplementationModel] is: a future generator or caller can
  /// consume it without recomputing it. Null only for outcomes that never
  /// reach this point (there are none on the production path).
  final SemanticSolutionArchitecture? solutionArchitecture;

  /// The Solution Execution Strategy (Implementation Milestone R18) —
  /// real classification of R18's 12 requested execution targets
  /// (applicable-with-generator/applicable-no-generator/not-applicable),
  /// derived from [solutionArchitecture]. Exposed additively; this
  /// milestone does NOT invoke any generator itself — a future caller
  /// uses `executionStrategy.actionableTargets` to do so. Null only for
  /// outcomes that never reach this point (there are none on the
  /// production path).
  final ExecutionStrategy? executionStrategy;

  const ExecutionPlanReady({
    required this.plan,
    required this.specification,
    this.blueprint,
    this.engineeringPlan,
    this.featurePlan,
    this.solutionDecision,
    this.reviewSession,
    this.evolutionRoadmap,
    this.requirementGraph,
    this.backendEngineeringPlan,
    this.canonicalImplementationModel,
    this.solutionArchitecture,
    this.executionStrategy,
    required super.message,
    required super.timestamp,
  });
}

/// Clarification is needed from the user.
class ClarificationRequired extends KernelOutcome {
  final ClarificationRequest request;

  const ClarificationRequired({
    required this.request,
    required super.message,
    required super.timestamp,
  });
}

/// A provider is needed but not configured.
class ProviderRequired extends KernelOutcome {
  const ProviderRequired({required super.message, required super.timestamp});
}

/// The intent cannot be fulfilled by Anything.
class UnsupportedIntent extends KernelOutcome {
  final String reason;

  const UnsupportedIntent({
    required this.reason,
    required super.message,
    required super.timestamp,
  });
}

/// Planning failed due to an error.
class PlanningFailed extends KernelOutcome {
  final String error;
  final StackTrace? stackTrace;

  const PlanningFailed({
    required this.error,
    this.stackTrace,
    required super.message,
    required super.timestamp,
  });
}

/// A clarification request to the user.
class ClarificationRequest {
  final String question;
  final String reason;
  final ClarificationResponseType expectedResponseType;
  final List<String>? choices;
  final String? affectedRequirement;

  const ClarificationRequest({
    required this.question,
    required this.reason,
    required this.expectedResponseType,
    this.choices,
    this.affectedRequirement,
  });
}

/// Expected type of response for a clarification.
enum ClarificationResponseType { text, choice, boolean, numeric }
