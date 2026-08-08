/// EvolutionPrediction — Prediction. Structural forecasts about what this
/// design is likely to need next, never domain-specific and never
/// fabricated: every forecast traces to a real, already-computed signal
/// (roadmap proposals, architecture shape, RuntimeSecurityLimits budgets,
/// FeatureComplexity), exactly like every other estimator in this engine.
library;

import '../feature_discovery/feature_types.dart' show ComplexityLevel;
import '../security/runtime_security_limits.dart';
import '../software_architect/confidence.dart';
import 'evolution_context.dart';
import 'evolution_roadmap.dart';
import 'evolution_types.dart';

class EvolutionForecast {
  final String description;
  final Confidence confidence;
  final String basis;

  const EvolutionForecast({
    required this.description,
    required this.confidence,
    required this.basis,
  });
}

class EvolutionPrediction {
  final List<EvolutionForecast> likelyModifications;
  final List<EvolutionForecast> likelyCapabilityAdditions;
  final EvolutionForecast likelyStorageEvolution;
  final EvolutionForecast likelyScalingNeeds;
  final EvolutionForecast likelyPerformanceNeeds;

  const EvolutionPrediction({
    required this.likelyModifications,
    required this.likelyCapabilityAdditions,
    required this.likelyStorageEvolution,
    required this.likelyScalingNeeds,
    required this.likelyPerformanceNeeds,
  });

  /// Derives every forecast from real, already-computed signals — never a
  /// template, never a second reasoning engine.
  factory EvolutionPrediction.derive(
    EvolutionContext context,
    EvolutionRoadmap roadmap,
  ) {
    final laterAndFuture = [
      ...roadmap.proposalsFor(EvolutionPhase.later),
      ...roadmap.proposalsFor(EvolutionPhase.future),
    ];
    final likelyModifications = laterAndFuture
        .map(
          (p) => EvolutionForecast(
            description: p.candidate.opportunity.description,
            confidence: p.candidate.opportunity.reason.confidence,
            basis: 'Roadmap phase: ${p.phase.name}',
          ),
        )
        .toList();

    final likelyCapabilityAdditions = roadmap.allProposals
        .where(
          (p) =>
              p.candidate.opportunity.category ==
              EvolutionOpportunityCategory.missingCapability,
        )
        .map(
          (p) => EvolutionForecast(
            description: p.candidate.opportunity.description,
            confidence: p.candidate.opportunity.reason.confidence,
            basis: 'FeatureGraph node deferred at discovery time',
          ),
        )
        .toList();

    final entityCount = context.architecture.entities.length;
    final relationshipCount = context.architecture.relationships.length;
    final storageEvolution = EvolutionForecast(
      description: relationshipCount > 0 || entityCount > 3
          ? 'Schema is likely to grow via additive DataMigrationPlan operations '
                '(new fields/entities/indexes) as usage grows'
          : 'Schema is small and self-contained; low likelihood of near-term migration',
      confidence: Confidence(
        score: relationshipCount > 0 || entityCount > 3 ? 0.6 : 0.3,
        reason:
            '$entityCount entities, $relationshipCount relationships in the current architecture.',
      ),
      basis: 'ArchitectureCandidate.entities/relationships',
    );

    final screenRatio =
        context.blueprint.views.length /
        RuntimeSecurityLimits.maxScreensPerPackage;
    final scalingNeeds = EvolutionForecast(
      description: screenRatio > 0.5
          ? 'Screen count is a meaningful fraction of the runtime budget; future growth may approach limits'
          : 'Screen count is well within runtime budget; no near-term scaling concern',
      confidence: Confidence(
        score: screenRatio,
        reason:
            '${context.blueprint.views.length}/${RuntimeSecurityLimits.maxScreensPerPackage} screens used.',
      ),
      basis: 'RuntimeSecurityLimits.maxScreensPerPackage',
    );

    final complexity = context.reviewContext.solution.complexity;
    final highCostDimensions =
        [complexity.runtime, complexity.memoryCost, complexity.networkCost]
            .where(
              (c) => c == ComplexityLevel.medium || c == ComplexityLevel.high,
            )
            .length;
    final performanceNeeds = EvolutionForecast(
      description: highCostDimensions > 0
          ? 'Runtime/memory/network complexity is already non-trivial; performance work is likely to matter as data grows'
          : 'Complexity is low across runtime/memory/network; performance work is unlikely to be needed soon',
      confidence: Confidence(
        score: highCostDimensions / 3.0,
        reason:
            '$highCostDimensions of 3 cost dimensions (runtime/memory/network) at medium or high.',
      ),
      basis: 'SolutionCandidate.complexity',
    );

    return EvolutionPrediction(
      likelyModifications: likelyModifications,
      likelyCapabilityAdditions: likelyCapabilityAdditions,
      likelyStorageEvolution: storageEvolution,
      likelyScalingNeeds: scalingNeeds,
      likelyPerformanceNeeds: performanceNeeds,
    );
  }
}
