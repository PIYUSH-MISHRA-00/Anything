/// EvolutionPolicy — the thresholds EvolutionPlanner uses to place a
/// reviewed proposal on the roadmap. EvolutionStrategy selects which
/// preset policy applies; never a magic number scattered through planning
/// logic.
library;

import '../software_architect/confidence.dart' show RiskLevel;

/// How aggressively EvolutionPlanner promotes proposals toward "immediate"
/// phases. Conservative apps (higher risk aversion) push more proposals
/// toward "later"/"future"; aggressive apps promote more toward
/// "immediate"/"next". Never auto-execution — strategy only affects
/// roadmap placement, never approval-for-execution.
enum EvolutionStrategy { conservative, balanced, aggressive }

class EvolutionPolicy {
  /// The highest [RiskLevel] a proposal may carry and still be eligible
  /// for the "immediate" phase.
  final RiskLevel maxRiskForImmediate;

  /// The highest [RiskLevel] a proposal may carry and still be eligible
  /// for the "next" phase.
  final RiskLevel maxRiskForNext;

  /// The minimum [EvolutionBenefit.overall] score (0.0-1.0) required for a
  /// proposal to be placed anywhere but "experimental".
  final double minBenefitForRoadmap;

  const EvolutionPolicy({
    this.maxRiskForImmediate = RiskLevel.low,
    this.maxRiskForNext = RiskLevel.medium,
    this.minBenefitForRoadmap = 0.3,
  });

  factory EvolutionPolicy.forStrategy(EvolutionStrategy strategy) => switch (strategy) {
    EvolutionStrategy.conservative => const EvolutionPolicy(
      maxRiskForImmediate: RiskLevel.none,
      maxRiskForNext: RiskLevel.low,
      minBenefitForRoadmap: 0.4,
    ),
    EvolutionStrategy.balanced => const EvolutionPolicy(),
    EvolutionStrategy.aggressive => const EvolutionPolicy(
      maxRiskForImmediate: RiskLevel.medium,
      maxRiskForNext: RiskLevel.high,
      minBenefitForRoadmap: 0.2,
    ),
  };
}
