/// Review Context — everything one Design Review session needs: the full,
/// already-approved output of every earlier pipeline stage (Feature
/// Discovery, Solution Reasoning, Engineering) plus the converted
/// blueprint. Design Review is the first stage to see all of these
/// together — every earlier reviewer only ever saw its own slice.
library;

import '../feature_discovery/dependency_types.dart';
import '../feature_discovery/feature_types.dart' show FeatureGraph;
import '../software_architect/architecture_candidate.dart';
import '../software_architect/requirement_graph.dart';
import '../solution_reasoning/solution_types.dart';
import '../synthesis/app_blueprint.dart';
import '../synthesis/application_reasoner.dart';
import '../application_engineering/engineering_candidate.dart';

class ReviewContext {
  final SemanticApp app;
  final RequirementGraph requirements;
  final FeatureGraph featureGraph;
  final DependencyGraph dependencyGraph;
  final SolutionCandidate solution;
  final AppBlueprint blueprint;

  const ReviewContext({
    required this.app,
    required this.requirements,
    required this.featureGraph,
    required this.dependencyGraph,
    required this.solution,
    required this.blueprint,
  });

  ArchitectureCandidate get architecture => solution.architecture;
  EngineeringCandidate get engineering =>
      solution.engineeringVariation.plan.finalCandidate;

  ReviewContext copyWith({
    AppBlueprint? blueprint,
    SolutionCandidate? solution,
  }) {
    return ReviewContext(
      app: app,
      requirements: requirements,
      featureGraph: featureGraph,
      dependencyGraph: dependencyGraph,
      solution: solution ?? this.solution,
      blueprint: blueprint ?? this.blueprint,
    );
  }
}
