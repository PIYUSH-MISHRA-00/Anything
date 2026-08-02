/// Engineering Context — everything one EngineeringPlanner run needs:
/// the approved architecture and the original semantic app (for the
/// field/derived-value detail ArchitectureCandidate summarizes but
/// doesn't repeat in full).
library;

import '../software_architect/architecture_candidate.dart';
import '../synthesis/application_reasoner.dart';

class EngineeringContext {
  final ArchitectureCandidate architecture;
  final SemanticApp app;

  const EngineeringContext({required this.architecture, required this.app});
}
