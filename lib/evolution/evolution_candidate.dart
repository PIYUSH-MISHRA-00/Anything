/// An EvolutionCandidate is one [EvolutionOpportunity] plus its estimated
/// cost/risk/benefit — not yet reviewed or placed on the roadmap. Once
/// [EvolutionReviewer] and the ranking pass accept it, it becomes an
/// [EvolutionProposal]: reviewed, ranked, and phase-assigned, ready to be
/// shown on the roadmap or (only on explicit request) compiled for
/// execution.
library;

import '../software_architect/confidence.dart' show RiskLevel;
import '../solution_reasoning/solution_tradeoff.dart' show SolutionTradeoff;
import 'evolution_opportunity.dart';
import 'evolution_types.dart';

class EvolutionCandidate {
  final String id;
  final EvolutionOpportunity opportunity;
  final EvolutionCost cost;
  final EvolutionRisk risk;
  final EvolutionBenefit benefit;

  /// Reuses Solution Reasoning's (V5) typed Tradeoff Engine vocabulary
  /// directly — never a second, competing tradeoff representation.
  final List<SolutionTradeoff> tradeoffs;

  const EvolutionCandidate({
    required this.id,
    required this.opportunity,
    required this.cost,
    required this.risk,
    required this.benefit,
    this.tradeoffs = const [],
  });

  /// Raw urgency, independent of roadmap phase: high benefit at low risk
  /// is critical/high; high benefit at high risk or low benefit at any
  /// risk trails off toward speculative. Never a bare number — always
  /// derived from the same typed benefit/risk this candidate already
  /// carries.
  EvolutionPriority get priority {
    if (benefit.overall >= 0.7 && risk.highest.index <= RiskLevel.low.index) {
      return EvolutionPriority.critical;
    }
    if (benefit.overall >= 0.5 &&
        risk.highest.index <= RiskLevel.medium.index) {
      return EvolutionPriority.high;
    }
    if (benefit.overall >= 0.3) return EvolutionPriority.medium;
    if (benefit.overall > 0) return EvolutionPriority.low;
    return EvolutionPriority.speculative;
  }
}

/// A candidate that survived Design Review and ranking — real enough to
/// place on the roadmap. Never auto-executed: [approvedForExecution] only
/// ever becomes true in response to an explicit, separate request (see
/// EvolutionExecutor), never inside roadmap planning itself.
class EvolutionProposal {
  final EvolutionCandidate candidate;
  final EvolutionPhase phase;
  final EvolutionDecision reviewDecision;
  final bool approvedForExecution;

  const EvolutionProposal({
    required this.candidate,
    required this.phase,
    required this.reviewDecision,
    this.approvedForExecution = false,
  });

  String get id => candidate.id;
}
