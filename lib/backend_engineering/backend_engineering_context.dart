/// Backend Engineering Context — mirrors `EngineeringContext`'s exact
/// shape (Vision Milestone V3): the approved architecture plus the
/// original semantic app, the same two already-computed, already-real
/// inputs frontend Engineering consumes. No new upstream dependency.
library;

import '../software_architect/architecture_candidate.dart';
import '../synthesis/application_reasoner.dart';

class BackendEngineeringContext {
  final ArchitectureCandidate architecture;
  final SemanticApp app;

  const BackendEngineeringContext({required this.architecture, required this.app});
}
