/// Solution Exploration Context — everything one SolutionExplorer run
/// needs beyond the approved, self-critiqued baseline ArchitectureCandidate
/// (which SolutionExplorer computes itself, reusing the certified
/// ArchitecturePlanner/RefinementPlanner unchanged).
library;

import '../feature_discovery/dependency_types.dart';
import '../feature_discovery/feature_types.dart' show FeatureGraph;
import '../synthesis/application_reasoner.dart';

class SolutionExplorationContext {
  final SemanticApp app;
  final FeatureGraph featureGraph;
  final DependencyGraph dependencyGraph;

  const SolutionExplorationContext({
    required this.app,
    required this.featureGraph,
    required this.dependencyGraph,
  });
}
