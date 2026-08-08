/// WorldContext — the current focus of reasoning (e.g. "Project Alpha"
/// or an active Experience). ContextAnalyzer resolves it into a real,
/// bounded GraphView — the substrate for "show everything related to X."
library;

import 'entity_identity.dart';
import 'graph_view.dart';
import 'world_graph.dart';

class WorldContext {
  final EntityIdentity? focusIdentity;
  final String? activeExperienceId;

  const WorldContext({this.focusIdentity, this.activeExperienceId});
}

class ContextAnalyzer {
  const ContextAnalyzer();

  GraphView? relevantView(
    WorldGraph graph,
    WorldContext context, {
    int maxDepth = 3,
  }) {
    final focus = context.focusIdentity;
    if (focus == null) return null;
    return GraphView.centeredOn(graph, focus, maxDepth: maxDepth);
  }
}
