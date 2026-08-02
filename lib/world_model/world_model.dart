/// WorldModel — the current, complete state: the graph, the active
/// context, and its version.
library;

import 'context_analyzer.dart';
import 'world_graph.dart';
import 'world_snapshot.dart';

class WorldModel {
  final WorldGraph graph;
  final WorldContext context;
  final WorldVersion version;

  const WorldModel({required this.graph, this.context = const WorldContext(), required this.version});
}
