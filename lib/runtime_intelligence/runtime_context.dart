/// RuntimeContext — bundles everything RecommendationEngine/
/// PredictionEngine need about the current runtime intelligence state:
/// the active session, the aggregated workspace, and the real UsageGraph
/// built from ObservationMemory. Mirrors EvolutionContext (V7)'s role as
/// a read-only context bundle passed into engines.
library;

import 'session_context.dart';
import 'usage_graph.dart';
import 'workspace_context.dart';

class RuntimeContext {
  final SessionContext session;
  final WorkspaceContext workspace;
  final UsageGraph usageGraph;

  const RuntimeContext({required this.session, required this.workspace, required this.usageGraph});
}
