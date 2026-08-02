/// EvolutionBudget — bounds how many observe/estimate/review passes one
/// EvolutionCycle may run, mirroring ReviewBudget (V6) and
/// FeatureRefinement/EngineeringRefinement/SolutionRefinement's proven,
/// terminating-by-construction budget pattern.
library;

class EvolutionBudget {
  final int maxIterations;
  final int maxOpportunitiesPerIteration;
  final int maxProposalsOnRoadmap;

  const EvolutionBudget({
    this.maxIterations = 3,
    this.maxOpportunitiesPerIteration = 100,
    this.maxProposalsOnRoadmap = 50,
  });
}
