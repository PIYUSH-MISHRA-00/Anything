/// Solution Scorer — computes a real, deterministic SolutionScore and a
/// complete 15-dimension SolutionTradeoff table for one SolutionCandidate.
/// Every number traces to a concrete property of the candidate (its
/// ArchitectureVariation choices, its FeatureComplexity profile, its real
/// Engineering/Architecture confidence) — nothing here is random or fixed
/// independent of the candidate.
library;

import '../feature_discovery/feature_types.dart' show ComplexityLevel;
import '../software_architect/architecture_types.dart' show OfflineCapability;
import '../software_architect/confidence.dart';
import 'solution_score.dart';
import 'solution_tradeoff.dart';
import 'solution_types.dart';
import 'solution_variation_types.dart';

class SolutionScorer {
  const SolutionScorer();

  static double _penalty(ComplexityLevel level) => switch (level) {
    ComplexityLevel.none => 0.0,
    ComplexityLevel.low => 0.05,
    ComplexityLevel.medium => 0.15,
    ComplexityLevel.high => 0.3,
  };

  static double _offlineScoreOf(OfflineCapability capability) => switch (capability) {
    OfflineCapability.fullyOffline => 1.0,
    OfflineCapability.cacheThenOnline => 0.7,
    OfflineCapability.onlineRequired => 0.3,
  };

  SolutionScore score(SolutionCandidate candidate) {
    final variation = candidate.architectureVariation;
    final complexity = candidate.complexity;
    final full = variation.capabilityRichness == CapabilityRichness.full;

    final maintainability = (1.0 - _penalty(complexity.maintenanceCost)).clamp(0.0, 1.0);
    final runtime = (1.0 - _penalty(complexity.runtime)).clamp(0.0, 1.0);
    final performance = (1.0 - _penalty(complexity.runtime) - _penalty(complexity.networkCost) / 2).clamp(0.0, 1.0);
    final offline = _offlineScoreOf(variation.offlineStrategy);
    final security = candidate.architecture.security.decision.confidence.score;
    final userExperience = full ? 0.85 : 0.65;
    const accessibility = 0.6; // invariant — Material defaults apply equally, matches V3's AccessibilityEngineering finding
    final futureEvolution = full ? 0.8 : 0.6;
    final engineering = candidate.engineeringVariation.plan.finalCandidate.overallConfidence.score;
    final architecture = candidate.architecture.overallConfidence.score;

    final dimensions = [
      engineering,
      architecture,
      maintainability,
      runtime,
      performance,
      security,
      offline,
      userExperience,
      accessibility,
      futureEvolution,
    ];
    final overall = dimensions.reduce((a, b) => a + b) / dimensions.length;

    Confidence of(double value, String reason) => Confidence(score: value, reason: reason);

    return SolutionScore(
      overall: of(overall, 'Equal-weighted mean of engineering/architecture/maintainability/runtime/'
          'performance/security/offline/userExperience/accessibility/futureEvolution.'),
      engineering: of(engineering, "This candidate's own Application Engineering Engine confidence."),
      architecture: of(architecture, "This candidate's own Architecture confidence."),
      maintainability: of(
        maintainability,
        'Derived from maintenance-cost complexity (${complexity.maintenanceCost.name}).',
      ),
      runtime: of(runtime, 'Derived from runtime complexity (${complexity.runtime.name}).'),
      performance: of(
        performance,
        'Derived from runtime (${complexity.runtime.name}) and network (${complexity.networkCost.name}) complexity.',
      ),
      security: of(security, "This candidate's SecurityDecision confidence (V2 SecurityPlanner)."),
      offline: of(offline, 'Offline strategy: ${variation.offlineStrategy.name}.'),
      userExperience: of(
        userExperience,
        full
            ? 'Full capability richness — search/filter/sort available on list views.'
            : 'Minimal capability richness — search/filter/sort deliberately omitted.',
      ),
      accessibility: of(accessibility, 'Inherited from Flutter Material defaults — invariant across candidates.'),
      futureEvolution: of(
        futureEvolution,
        full
            ? 'Full richness already covers more of the surface future growth would need.'
            : 'Minimal richness would need retrofitting (search/filter/sort) as the app grows.',
      ),
    );
  }

  List<SolutionTradeoff> tradeoffs(SolutionCandidate candidate) {
    final variation = candidate.architectureVariation;
    final full = variation.capabilityRichness == CapabilityRichness.full;
    final hierarchical = variation.navigationTopology == NavigationTopology.hierarchical;
    final offlineFirst = variation.offlineStrategy == OfflineCapability.fullyOffline;

    SolutionTradeoff t(TradeoffDimension d, TradeoffDirection dir, String desc, String why) =>
        SolutionTradeoff(dimension: d, direction: dir, description: desc, rationale: why);

    return [
      t(
        TradeoffDimension.complexity,
        full ? TradeoffDirection.disadvantage : TradeoffDirection.advantage,
        full ? 'Search/filter/sort add UI and state surface' : 'Fewer moving parts to build and reason about',
        'CapabilityRichness.${variation.capabilityRichness.name} was chosen for this candidate.',
      ),
      t(
        TradeoffDimension.maintainability,
        full ? TradeoffDirection.disadvantage : TradeoffDirection.advantage,
        full ? 'More UI paths to keep working across changes' : 'Fewer paths to keep working across changes',
        'Mirrors the complexity tradeoff above.',
      ),
      t(
        TradeoffDimension.battery,
        offlineFirst ? TradeoffDirection.advantage : TradeoffDirection.neutral,
        offlineFirst
            ? 'No network activity implied by this posture'
            : 'Network-capable posture; no background sync exists today so battery impact is currently neutral',
        'Offline strategy: ${variation.offlineStrategy.name} (architecture-only — no server exists either way, see V3).',
      ),
      t(
        TradeoffDimension.performance,
        full ? TradeoffDirection.disadvantage : TradeoffDirection.advantage,
        full
            ? 'Client-side filter/sort work scales with list size (no virtualization yet, per V3 finding)'
            : 'No client-side filter/sort overhead',
        'CapabilityRichness.${variation.capabilityRichness.name}.',
      ),
      t(
        TradeoffDimension.memory,
        full ? TradeoffDirection.disadvantage : TradeoffDirection.advantage,
        full ? 'Search/filter state held in memory' : 'No additional in-memory state for search/filter',
        'CapabilityRichness.${variation.capabilityRichness.name}.',
      ),
      const SolutionTradeoff(
        dimension: TradeoffDimension.storage,
        direction: TradeoffDirection.neutral,
        description: 'Same generic SQLite storage regardless of choice',
        rationale: 'StorageVariation is single-valued today — one real storage backend (ExperienceDatabase).',
      ),
      t(
        TradeoffDimension.network,
        offlineFirst ? TradeoffDirection.advantage : TradeoffDirection.disadvantage,
        offlineFirst ? 'Minimal network dependency' : 'Assumes network is used for a declared purpose',
        'Offline strategy: ${variation.offlineStrategy.name}.',
      ),
      t(
        TradeoffDimension.offline,
        offlineFirst ? TradeoffDirection.advantage : TradeoffDirection.disadvantage,
        offlineFirst ? 'Strongest offline guarantee' : 'Depends on cached data freshness when offline',
        'Offline strategy: ${variation.offlineStrategy.name}.',
      ),
      t(
        TradeoffDimension.modificationCost,
        full ? TradeoffDirection.disadvantage : TradeoffDirection.advantage,
        full ? 'More surface to touch when modifying later' : 'Less surface to touch when modifying later',
        'CapabilityRichness.${variation.capabilityRichness.name}.',
      ),
      t(
        TradeoffDimension.testingCost,
        full ? TradeoffDirection.disadvantage : TradeoffDirection.advantage,
        full ? 'More UI paths to test (search/filter/sort)' : 'Fewer UI paths to test',
        'CapabilityRichness.${variation.capabilityRichness.name}.',
      ),
      t(
        TradeoffDimension.security,
        offlineFirst ? TradeoffDirection.advantage : TradeoffDirection.neutral,
        offlineFirst ? 'Less data leaves the device' : 'Same M2-audited network hardening applies either way',
        'Offline strategy: ${variation.offlineStrategy.name}.',
      ),
      t(
        TradeoffDimension.privacy,
        offlineFirst ? TradeoffDirection.advantage : TradeoffDirection.neutral,
        offlineFirst ? 'Data stays local by design' : 'No additional data leaves the device beyond declared network use',
        'Offline strategy: ${variation.offlineStrategy.name}.',
      ),
      t(
        TradeoffDimension.scalability,
        hierarchical ? TradeoffDirection.advantage : TradeoffDirection.disadvantage,
        hierarchical
            ? 'Scales to many entities without cluttering one hub screen'
            : 'A flat hub gets crowded as more entities are added',
        'NavigationTopology.${variation.navigationTopology.name}.',
      ),
      const SolutionTradeoff(
        dimension: TradeoffDimension.accessibility,
        direction: TradeoffDirection.neutral,
        description: 'Same Flutter Material defaults regardless of choice',
        rationale: 'Accessibility posture is invariant across candidates (see V3 AccessibilityEngineering finding).',
      ),
      t(
        TradeoffDimension.futureEvolution,
        hierarchical ? TradeoffDirection.advantage : TradeoffDirection.disadvantage,
        hierarchical
            ? 'Easier to add more entities without redesigning navigation'
            : 'Adding more entities later would crowd the flat hub, likely forcing a redesign',
        'NavigationTopology.${variation.navigationTopology.name}.',
      ),
    ];
  }
}
