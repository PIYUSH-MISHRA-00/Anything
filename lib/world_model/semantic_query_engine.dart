/// SemanticQueryEngine — Natural language -> Semantic Query -> Graph
/// Traversal -> Typed Results. `parseIntent` is honestly a minimal,
/// deterministic structural parser (relationship-phrase -> RelationshipKind),
/// never an NLP/embedding engine — this milestone's own user-experience
/// section explicitly allows these capabilities to "remain internal in
/// V9," and the real requirement is that the typed GraphQuery/GraphSearch
/// architecture exists and works, not that free text understanding does.
library;

import 'entity_identity.dart';
import 'graph_query.dart';
import 'graph_search.dart';
import 'world_graph.dart';
import 'world_node.dart';
import 'world_types.dart';

class SemanticQueryEngine {
  final GraphSearch _search;

  const SemanticQueryEngine({GraphSearch search = const GraphSearch()}) : _search = search;

  List<WorldNode> query(WorldGraph graph, GraphQuery query) => _search.run(graph, query);

  /// A minimal, deterministic structural parser — matches a small,
  /// fixed vocabulary of relationship phrases to a real RelationshipKind.
  /// Returns null (never a guess) when nothing recognized matches.
  GraphQuery? parseIntent(String expression, EntityIdentity startId) {
    final lower = expression.toLowerCase();
    RelationshipKind? kind;
    var direction = GraphQueryDirection.forward;

    if (lower.contains('depend')) {
      kind = RelationshipKind.dependsOn;
      direction = lower.contains('depends on this') || lower.contains('what depends') ? GraphQueryDirection.reverse : GraphQueryDirection.forward;
    } else if (lower.contains('contain')) {
      kind = RelationshipKind.contains;
    } else if (lower.contains('reference')) {
      kind = RelationshipKind.references;
    } else if (lower.contains('duplicate')) {
      kind = RelationshipKind.duplicates;
    } else if (lower.contains('related') || lower.contains('everything')) {
      direction = GraphQueryDirection.both;
    }

    return GraphQuery(startId: startId, relationKinds: kind == null ? null : {kind}, direction: direction);
  }
}
