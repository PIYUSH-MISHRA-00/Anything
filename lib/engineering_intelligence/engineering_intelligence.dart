/// Engineering Intelligence — Implementation Specification IS-R24. A real
/// FACADE over the engineering-level graphs this codebase already
/// produces, never a new parallel model (mirrors Vision Milestone V7's own
/// established precedent: "EngineeringMemory is a facade over
/// ReviewMemory/EvolutionMemory, not a third store").
///
/// REALITY (see `docs/architecture/ENGINEERING_INTELLIGENCE.md` for the
/// full audit): of R24's 14 requested graph types, 11 already exist under
/// real names, all reachable from the two fields below:
///
///  - Requirement Graph        -> [requirementGraph] (V2, `RequirementGraph`)
///  - Architecture Graph       -> [architectureCandidate] + [backendEngineeringPlan]
///  - Workflow Graph           -> `ArchitectureCandidate.interactions` (no
///                                distinct signal exists beyond this —
///                                honestly not a separate type, see below)
///  - Navigation Graph         -> `ArchitectureCandidate.navigation`
///                                (`NavigationGraph`, already real)
///  - Capability Graph         -> `ArchitectureCandidate.capabilities`
///  - Relationship Graph       -> `ArchitectureCandidate.relationships`
///  - Dependency Graph         -> `UniversalBuildGraph` (R11, compiler-side)
///  - Permission Graph         -> `ArchitectureCandidate.permissions`
///  - Storage Graph            -> `BackendEngineeringPlan.database`
///  - Backend Graph            -> [backendEngineeringPlan] as a whole
///  - Frontend Graph           -> [architectureCandidate] as a whole
///  - Offline Strategy         -> `ArchitectureCandidate.offline`
///  - Synchronization Strategy -> `ArchitectureCandidate.synchronization`
///  - Deployment Intent        -> `BackendEngineeringPlan.deployment`
///
/// Genuinely composed further by `SemanticSolutionArchitecture` (R17),
/// which already unifies [architectureCandidate] + [backendEngineeringPlan]
/// into one architecture-shaped view and honestly names 8 further gaps
/// (Realtime/Messaging/Notifications/Observability/Monitoring/
/// Configuration/Policies/Scaling — see
/// `SolutionArchitecturePlanner.standingGaps`) — this facade does not
/// re-litigate that audit, it points at it.
///
/// "Workflow Graph" is deliberately NOT modeled as a distinct type: every
/// real signal for it (`ArchitectureCandidate.interactions`, the
/// compiler-side `BehaviorGraph`, R20's derived-value behavior chains)
/// already exists under an established name; inventing a fifteenth
/// wrapper type around the same data would duplicate, not close a gap.
library;

import '../backend_engineering/backend_engineering_plan.dart';
import '../software_architect/architecture_candidate.dart';
import '../software_architect/requirement_graph.dart';

/// Real references to already-real engineering artifacts for one
/// creation/modification request — never a copy, never a new graph
/// representation. [backendEngineeringPlan] is nullable: a fully-offline,
/// no-backend request legitimately has none (matches
/// `AnythingKernel`'s own `backendEngineeringPlan` optionality).
class EngineeringIntelligence {
  final RequirementGraph requirementGraph;
  final ArchitectureCandidate architectureCandidate;
  final BackendEngineeringPlan? backendEngineeringPlan;

  const EngineeringIntelligence({required this.requirementGraph, required this.architectureCandidate, this.backendEngineeringPlan});
}
