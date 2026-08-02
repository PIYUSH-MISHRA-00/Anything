/// EvolutionContext — everything EvolutionEngine needs to observe a
/// design and plan its roadmap, all of it already computed by earlier
/// Kernel stages. Never re-derives Requirements/Features/Architecture/
/// Engineering/Review itself — it only reads them.
library;

import '../design_review/review_context.dart';
import '../design_review/review_history.dart' show ReviewSession;
import '../feature_discovery/feature_types.dart' show FeatureGraph;
import '../software_architect/architecture_candidate.dart';
import '../software_architect/requirement_graph.dart';
import '../synthesis/app_blueprint.dart';
import 'evolution_policy.dart';

class EvolutionContext {
  final ReviewContext reviewContext;

  /// The real, already-approved Design Review session for this design —
  /// its non-critical findings are the primary structural source for
  /// accessibility/performance/offline/maintainability opportunities
  /// (see EvolutionObserver). Reused directly, never re-derived.
  final ReviewSession reviewSession;

  final EvolutionStrategy strategy;

  const EvolutionContext({
    required this.reviewContext,
    required this.reviewSession,
    this.strategy = EvolutionStrategy.balanced,
  });

  RequirementGraph get requirements => reviewContext.requirements;
  FeatureGraph get featureGraph => reviewContext.featureGraph;
  ArchitectureCandidate get architecture => reviewContext.architecture;
  AppBlueprint get blueprint => reviewContext.blueprint;
}
