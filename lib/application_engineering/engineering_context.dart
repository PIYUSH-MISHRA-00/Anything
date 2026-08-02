/// Engineering Context — everything one EngineeringPlanner run needs:
/// the approved architecture and the original semantic app (for the
/// field/derived-value detail ArchitectureCandidate summarizes but
/// doesn't repeat in full).
library;

import '../feature_discovery/feature_types.dart';
import '../software_architect/architecture_candidate.dart';
import '../synthesis/application_reasoner.dart';

class EngineeringContext {
  final ArchitectureCandidate architecture;
  final SemanticApp app;

  /// The Feature Discovery Engine's approved FeatureGraph (Vision
  /// Milestone V4), if the Kernel produced one. Optional for backward
  /// compatibility with pre-V4 test fixtures; the Kernel unconditionally
  /// supplies a real, approved FeatureGraph in production — there is no
  /// live path where Engineering runs without one.
  final FeatureGraph? featureGraph;

  const EngineeringContext({required this.architecture, required this.app, this.featureGraph});
}
