/// EvolutionPlanner — turns reviewed, accepted candidates into an ordered
/// [EvolutionRoadmap]. Ranking mirrors the exact algorithm shape already
/// established by SolutionComparison/SolutionSelector (V5): sort by
/// benefit, break ties by risk then cost — SolutionComparison/
/// SolutionSelector themselves are generically bound to `SolutionCandidate`
/// and cannot be reused as library calls for a different candidate type,
/// so the same reasoning approach is mirrored here rather than
/// reimplemented from scratch or forced through an unrelated type.
library;

import 'evolution_budget.dart';
import 'evolution_candidate.dart';
import 'evolution_context.dart';
import 'evolution_policy.dart';
import 'evolution_roadmap.dart';
import 'evolution_types.dart';

class EvolutionPlanner {
  const EvolutionPlanner();

  EvolutionRoadmap plan({
    required String fingerprint,
    required List<EvolutionProposal> reviewedProposals,
    required EvolutionContext context,
    EvolutionBudget budget = const EvolutionBudget(),
  }) {
    final policy = EvolutionPolicy.forStrategy(context.strategy);
    final ranked = [...reviewedProposals]
      ..sort((a, b) => _compare(a.candidate, b.candidate));
    final capped = ranked.take(budget.maxProposalsOnRoadmap).toList();

    final placed = capped.map((p) => _placeInPhase(p, policy)).toList();

    final milestones = EvolutionPhase.values
        .map(
          (phase) => EvolutionMilestone(
            phase: phase,
            proposals: placed.where((p) => p.phase == phase).toList(),
          ),
        )
        .toList();

    return EvolutionRoadmap(
      fingerprint: fingerprint,
      milestones: milestones,
      generatedAt: DateTime.now(),
    );
  }

  EvolutionProposal _placeInPhase(
    EvolutionProposal proposal,
    EvolutionPolicy policy,
  ) {
    final risk = proposal.candidate.risk.highest;
    final benefit = proposal.candidate.benefit.overall;

    final phase = benefit < policy.minBenefitForRoadmap
        ? (benefit > 0 ? EvolutionPhase.future : EvolutionPhase.experimental)
        : risk.index <= policy.maxRiskForImmediate.index
        ? EvolutionPhase.immediate
        : risk.index <= policy.maxRiskForNext.index
        ? EvolutionPhase.next
        : EvolutionPhase.later;

    return EvolutionProposal(
      candidate: proposal.candidate,
      phase: phase,
      reviewDecision: proposal.reviewDecision,
    );
  }

  int _compare(EvolutionCandidate a, EvolutionCandidate b) {
    var cmp = b.benefit.overall.compareTo(a.benefit.overall);
    if (cmp != 0) return cmp;

    cmp = a.risk.highest.index.compareTo(b.risk.highest.index);
    if (cmp != 0) return cmp;

    return a.cost.engineering.index.compareTo(b.cost.engineering.index);
  }
}
