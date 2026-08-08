/// GraphSearch — runs a typed GraphQuery against a real WorldGraph via
/// GraphTraversal and returns typed WorldNode results. The engine behind
/// SemanticQueryEngine; never a keyword index over content.
library;

import 'graph_query.dart';
import 'graph_traversal.dart';
import 'world_graph.dart';
import 'world_node.dart';

class GraphSearch {
  final GraphTraversal _traversal;

  const GraphSearch({GraphTraversal traversal = const GraphTraversal()})
    : _traversal = traversal;

  List<WorldNode> run(WorldGraph graph, GraphQuery query) {
    final steps = switch (query.direction) {
      GraphQueryDirection.forward => _traversal.forward(
        graph,
        query.startId,
        maxDepth: query.maxDepth,
        relationKinds: query.relationKinds,
      ),
      GraphQueryDirection.reverse => _traversal.reverse(
        graph,
        query.startId,
        maxDepth: query.maxDepth,
        relationKinds: query.relationKinds,
      ),
      GraphQueryDirection.both => [
        ..._traversal.forward(
          graph,
          query.startId,
          maxDepth: query.maxDepth,
          relationKinds: query.relationKinds,
        ),
        ..._traversal.reverse(
          graph,
          query.startId,
          maxDepth: query.maxDepth,
          relationKinds: query.relationKinds,
        ),
      ],
    };

    return steps
        .map((s) => graph.nodeById(s.nodeId))
        .whereType<WorldNode>()
        .toList();
  }
}
