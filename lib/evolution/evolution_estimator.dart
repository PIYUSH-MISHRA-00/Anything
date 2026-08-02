/// EvolutionEstimator — Value Estimation + Risk Estimation. Turns a raw
/// [EvolutionOpportunity] into a fully-costed [EvolutionCandidate].
/// Every dimension is explained (a [Confidence] or [RiskLevel] with a
/// real rationale), never a bare number — matching SolutionScorer's (V5)
/// established "explain every score" discipline.
library;

import '../feature_discovery/feature_types.dart' show ComplexityLevel;
import '../solution_reasoning/solution_tradeoff.dart';
import '../software_architect/confidence.dart';
import 'evolution_candidate.dart';
import 'evolution_opportunity.dart';
import 'evolution_types.dart';

class EvolutionEstimator {
  const EvolutionEstimator();

  EvolutionCandidate estimate(EvolutionOpportunity opportunity) {
    final cost = _costFor(opportunity.category);
    final risk = _riskFor(opportunity.category);
    final benefit = _benefitFor(opportunity);

    return EvolutionCandidate(
      id: 'candidate:${opportunity.id}',
      opportunity: opportunity,
      cost: cost,
      risk: risk,
      benefit: benefit,
      tradeoffs: _tradeoffsFor(opportunity.category),
    );
  }

  /// Every category's cost is a structural function of what kind of
  /// change it implies (a UI/behavior addition vs. a cross-cutting
  /// architectural posture change), never an arbitrary guess.
  EvolutionCost _costFor(EvolutionOpportunityCategory category) {
    return switch (category) {
      EvolutionOpportunityCategory.missingCapability => const EvolutionCost(
        engineering: ComplexityLevel.medium,
        migration: ComplexityLevel.low,
        testing: ComplexityLevel.medium,
        documentation: ComplexityLevel.low,
      ),
      EvolutionOpportunityCategory.missingWorkflow => const EvolutionCost(
        engineering: ComplexityLevel.medium,
        testing: ComplexityLevel.medium,
      ),
      EvolutionOpportunityCategory.missingNavigation => const EvolutionCost(
        engineering: ComplexityLevel.low,
        testing: ComplexityLevel.low,
      ),
      EvolutionOpportunityCategory.missingSearch => const EvolutionCost(
        engineering: ComplexityLevel.low,
        testing: ComplexityLevel.low,
      ),
      EvolutionOpportunityCategory.missingFiltering => const EvolutionCost(
        engineering: ComplexityLevel.low,
        testing: ComplexityLevel.low,
      ),
      EvolutionOpportunityCategory.missingAccessibility => const EvolutionCost(
        engineering: ComplexityLevel.low,
        testing: ComplexityLevel.low,
        documentation: ComplexityLevel.low,
      ),
      EvolutionOpportunityCategory.missingOffline => const EvolutionCost(
        engineering: ComplexityLevel.high,
        migration: ComplexityLevel.medium,
        testing: ComplexityLevel.high,
      ),
      EvolutionOpportunityCategory.missingSynchronization => const EvolutionCost(
        engineering: ComplexityLevel.high,
        migration: ComplexityLevel.medium,
        testing: ComplexityLevel.high,
      ),
      EvolutionOpportunityCategory.missingPerformance => const EvolutionCost(
        engineering: ComplexityLevel.medium,
        testing: ComplexityLevel.medium,
      ),
      EvolutionOpportunityCategory.missingMaintainability => const EvolutionCost(
        engineering: ComplexityLevel.low,
        documentation: ComplexityLevel.medium,
      ),
    };
  }

  /// Cross-cutting posture changes (offline/sync) carry real migration and
  /// data risk; additive UI/workflow changes carry very little. Never
  /// domain-specific — the mapping is keyed on the structural category
  /// only.
  EvolutionRisk _riskFor(EvolutionOpportunityCategory category) {
    return switch (category) {
      EvolutionOpportunityCategory.missingOffline => const EvolutionRisk(
        migrationRisk: RiskLevel.medium,
        dataRisk: RiskLevel.medium,
        runtimeRisk: RiskLevel.low,
        userImpact: RiskLevel.low,
        testingCost: RiskLevel.medium,
      ),
      EvolutionOpportunityCategory.missingSynchronization => const EvolutionRisk(
        migrationRisk: RiskLevel.medium,
        dataRisk: RiskLevel.high,
        runtimeRisk: RiskLevel.medium,
        userImpact: RiskLevel.low,
        testingCost: RiskLevel.medium,
      ),
      EvolutionOpportunityCategory.missingCapability => const EvolutionRisk(
        modificationRisk: RiskLevel.low,
        securityRisk: RiskLevel.low,
        userImpact: RiskLevel.low,
      ),
      EvolutionOpportunityCategory.missingPerformance => const EvolutionRisk(
        modificationRisk: RiskLevel.low,
        performanceRisk: RiskLevel.low,
        runtimeRisk: RiskLevel.low,
      ),
      _ => const EvolutionRisk(modificationRisk: RiskLevel.low, userImpact: RiskLevel.none),
    };
  }

  /// Every benefit dimension traces to the opportunity's own confidence
  /// and category — never fabricated. Only the dimensions structurally
  /// implied by the category score above `none`; every other dimension is
  /// honestly `0.0` with a "not applicable" reason, matching SolutionScore
  /// (V5)'s honest-neutral pattern.
  EvolutionBenefit _benefitFor(EvolutionOpportunity opportunity) {
    Confidence at(double score, String reason) => Confidence(score: score, reason: reason);
    const notApplicable = 'This opportunity does not structurally affect this dimension.';

    final baseScore = opportunity.reason.confidence.score;

    return switch (opportunity.category) {
      EvolutionOpportunityCategory.missingCapability => EvolutionBenefit(
        engineeringValue: at(baseScore, 'Extends real, already-discovered capability coverage.'),
        userValue: at(baseScore, 'A capability Feature Discovery found the user objective implies.'),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(0.0, notApplicable),
        futureValue: at(baseScore, 'Keeps the design aligned with discovered future needs.'),
      ),
      EvolutionOpportunityCategory.missingWorkflow => EvolutionBenefit(
        engineeringValue: at(baseScore, 'Completes a workflow Feature Discovery already found.'),
        userValue: at(baseScore, opportunity.description),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(0.0, notApplicable),
        futureValue: at(baseScore, 'Deferred workflow becoming available later.'),
      ),
      EvolutionOpportunityCategory.missingNavigation => EvolutionBenefit(
        engineeringValue: at(0.0, notApplicable),
        userValue: at(0.8, 'A readable entity with no view is unreachable to the user today.'),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(0.0, notApplicable),
        futureValue: at(0.0, notApplicable),
      ),
      EvolutionOpportunityCategory.missingSearch || EvolutionOpportunityCategory.missingFiltering => EvolutionBenefit(
        engineeringValue: at(0.0, notApplicable),
        userValue: at(baseScore, opportunity.description),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(0.0, notApplicable),
        futureValue: at(0.0, notApplicable),
      ),
      EvolutionOpportunityCategory.missingAccessibility => EvolutionBenefit(
        engineeringValue: at(0.0, notApplicable),
        userValue: at(baseScore, 'Accessibility improvements benefit every user.'),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(baseScore, opportunity.reason.summary),
        offlineValue: at(0.0, notApplicable),
        futureValue: at(0.0, notApplicable),
      ),
      EvolutionOpportunityCategory.missingOffline => EvolutionBenefit(
        engineeringValue: at(0.0, notApplicable),
        userValue: at(baseScore, 'Full offline support benefits users with unreliable connectivity.'),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(baseScore, opportunity.reason.summary),
        futureValue: at(baseScore, 'Reduces future network-dependency risk.'),
      ),
      EvolutionOpportunityCategory.missingSynchronization => EvolutionBenefit(
        engineeringValue: at(0.0, notApplicable),
        userValue: at(baseScore, 'Synchronization keeps data current across sessions/devices.'),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(baseScore, opportunity.reason.summary),
        futureValue: at(baseScore, 'Reduces future data-staleness risk.'),
      ),
      EvolutionOpportunityCategory.missingPerformance => EvolutionBenefit(
        engineeringValue: at(0.0, notApplicable),
        userValue: at(baseScore, 'Performance improvements are directly felt by the user.'),
        maintenanceValue: at(0.0, notApplicable),
        performanceValue: at(baseScore, opportunity.reason.summary),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(0.0, notApplicable),
        futureValue: at(0.0, notApplicable),
      ),
      EvolutionOpportunityCategory.missingMaintainability => EvolutionBenefit(
        engineeringValue: at(0.0, notApplicable),
        userValue: at(0.0, notApplicable),
        maintenanceValue: at(baseScore, opportunity.reason.summary),
        performanceValue: at(0.0, notApplicable),
        securityValue: at(0.0, notApplicable),
        accessibilityValue: at(0.0, notApplicable),
        offlineValue: at(0.0, notApplicable),
        futureValue: at(baseScore, 'Lower maintenance cost compounds favorably over future milestones.'),
      ),
    };
  }

  /// Reuses [TradeoffDimension]/[SolutionTradeoff] (V5) directly — no
  /// second, competing tradeoff vocabulary.
  List<SolutionTradeoff> _tradeoffsFor(EvolutionOpportunityCategory category) {
    return switch (category) {
      EvolutionOpportunityCategory.missingOffline || EvolutionOpportunityCategory.missingSynchronization => const [
        SolutionTradeoff(
          dimension: TradeoffDimension.offline,
          direction: TradeoffDirection.advantage,
          description: 'Improves offline/synchronization posture',
          rationale: 'Directly addresses a real posture gap in the current architecture.',
        ),
        SolutionTradeoff(
          dimension: TradeoffDimension.complexity,
          direction: TradeoffDirection.disadvantage,
          description: 'Adds synchronization/conflict-handling complexity',
          rationale: 'Offline/sync changes are structurally cross-cutting, not additive.',
        ),
      ],
      EvolutionOpportunityCategory.missingAccessibility => const [
        SolutionTradeoff(
          dimension: TradeoffDimension.accessibility,
          direction: TradeoffDirection.advantage,
          description: 'Closes a real, non-critical accessibility finding',
          rationale: 'Sourced directly from a Design Review (SCARE) finding for this design.',
        ),
      ],
      EvolutionOpportunityCategory.missingPerformance => const [
        SolutionTradeoff(
          dimension: TradeoffDimension.performance,
          direction: TradeoffDirection.advantage,
          description: 'Closes a real, non-critical performance finding',
          rationale: 'Sourced directly from a Design Review (SCARE) finding for this design.',
        ),
      ],
      EvolutionOpportunityCategory.missingMaintainability => const [
        SolutionTradeoff(
          dimension: TradeoffDimension.maintainability,
          direction: TradeoffDirection.advantage,
          description: 'Closes a real, non-critical maintainability finding',
          rationale: 'Sourced directly from a Design Review (SCARE) finding for this design.',
        ),
      ],
      _ => const [
        SolutionTradeoff(
          dimension: TradeoffDimension.modificationCost,
          direction: TradeoffDirection.neutral,
          description: 'Additive UI/workflow change',
          rationale: 'Does not restructure existing entities, permissions, or navigation.',
        ),
      ],
    };
  }
}
