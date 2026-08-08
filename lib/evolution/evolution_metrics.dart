/// EvolutionMetrics — a typed summary of one EvolutionResult, mirroring
/// ReviewMetrics (V6).
library;

import 'evolution_result.dart';
import 'evolution_types.dart';

class EvolutionCategoryCount {
  final EvolutionOpportunityCategory category;
  final int count;

  const EvolutionCategoryCount({required this.category, required this.count});
}

class EvolutionMetrics {
  final int totalOpportunitiesFound;
  final int totalCandidatesEstimated;
  final int totalProposalsAccepted;
  final int totalProposalsRejected;
  final int iterationsRun;
  final List<EvolutionCategoryCount> opportunitiesByCategory;

  const EvolutionMetrics({
    required this.totalOpportunitiesFound,
    required this.totalCandidatesEstimated,
    required this.totalProposalsAccepted,
    required this.totalProposalsRejected,
    required this.iterationsRun,
    required this.opportunitiesByCategory,
  });

  factory EvolutionMetrics.from(EvolutionResult result) {
    final allOpportunities = result.cycle.iterations
        .expand((i) => i.opportunities)
        .toList();
    final allDecisions = result.cycle.iterations
        .expand((i) => i.decisions)
        .toList();
    final byCategory = <EvolutionOpportunityCategory, int>{};
    for (final o in allOpportunities) {
      byCategory[o.category] = (byCategory[o.category] ?? 0) + 1;
    }

    return EvolutionMetrics(
      totalOpportunitiesFound: allOpportunities.length,
      totalCandidatesEstimated: result.cycle.iterations
          .expand((i) => i.candidates)
          .length,
      totalProposalsAccepted: allDecisions
          .where((d) => d.kind == EvolutionDecisionKind.accepted)
          .length,
      totalProposalsRejected: allDecisions
          .where((d) => d.kind == EvolutionDecisionKind.rejected)
          .length,
      iterationsRun: result.cycle.iterations.length,
      opportunitiesByCategory: byCategory.entries
          .map((e) => EvolutionCategoryCount(category: e.key, count: e.value))
          .toList(),
    );
  }
}
