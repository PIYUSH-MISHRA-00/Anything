/// Vision V9 WMSG — GraphTraversal (bounded, cycle-safe), GraphQuery/
/// GraphSearch, SemanticQueryEngine's structural parser.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/graph_query.dart';
import 'package:anything/world_model/graph_search.dart';
import 'package:anything/world_model/graph_traversal.dart';
import 'package:anything/world_model/semantic_query_engine.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  EntityIdentity id(String s) => EntityIdentity.stable(WorldNodeKind.entity, s);

  WorldEdge edge(String from, String to, RelationshipKind kind) => WorldEdge(
    fromId: id(from),
    toId: id(to),
    kind: kind,
    evidence: const GraphEvidence(sourceGraph: 'test', sourceNodeId: 'n'),
  );

  final chain = WorldGraph(
    nodes: ['a', 'b', 'c', 'd'].map((s) => WorldNode(identity: id(s), kind: WorldNodeKind.entity, label: s)).toList(),
    edges: [edge('a', 'b', RelationshipKind.dependsOn), edge('b', 'c', RelationshipKind.dependsOn), edge('c', 'd', RelationshipKind.dependsOn)],
  );

  final cyclic = WorldGraph(
    nodes: ['x', 'y'].map((s) => WorldNode(identity: id(s), kind: WorldNodeKind.entity, label: s)).toList(),
    edges: [edge('x', 'y', RelationshipKind.relatesTo), edge('y', 'x', RelationshipKind.relatesTo)],
  );

  group('GraphTraversal', () {
    const traversal = GraphTraversal();

    test('forward traversal follows outgoing edges up to maxDepth, never beyond', () {
      final steps = traversal.forward(chain, id('a'), maxDepth: 2);
      expect(steps.map((s) => s.nodeId), containsAll([id('b'), id('c')]));
      expect(steps.any((s) => s.nodeId == id('d')), isFalse); // depth 3, beyond the bound
    });

    test('reverse traversal follows incoming edges', () {
      final steps = traversal.reverse(chain, id('d'), maxDepth: 5);
      expect(steps.map((s) => s.nodeId), containsAll([id('c'), id('b'), id('a')]));
    });

    test('a cyclic graph never causes an infinite loop — terminates deterministically', () {
      final steps = traversal.forward(cyclic, id('x'), maxDepth: 10);
      // Only 'y' is ever reachable and visited once, despite the cycle.
      expect(steps, hasLength(1));
      expect(steps.first.nodeId, id('y'));
    });

    test('relationKinds filters the traversal to only the requested edge kinds', () {
      final mixed = WorldGraph(
        nodes: ['p', 'q', 'r'].map((s) => WorldNode(identity: id(s), kind: WorldNodeKind.entity, label: s)).toList(),
        edges: [edge('p', 'q', RelationshipKind.dependsOn), edge('p', 'r', RelationshipKind.duplicates)],
      );
      final onlyDepends = traversal.forward(mixed, id('p'), relationKinds: {RelationshipKind.dependsOn});
      expect(onlyDepends.map((s) => s.nodeId), [id('q')]);
    });
  });

  group('GraphSearch + GraphQuery', () {
    const search = GraphSearch();

    test('runs a typed query and returns typed WorldNode results', () {
      final results = search.run(chain, GraphQuery(startId: id('a'), maxDepth: 5));
      expect(results.map((n) => n.label), containsAll(['b', 'c', 'd']));
    });
  });

  group('SemanticQueryEngine', () {
    const engine = SemanticQueryEngine();

    test('parseIntent maps a real relationship phrase to a typed RelationshipKind', () {
      final query = engine.parseIntent('what does this depend on', id('a'));
      expect(query, isNotNull);
      expect(query!.relationKinds, {RelationshipKind.dependsOn});
    });

    test('an unrecognized expression still returns a query, never a crash, with no relation filter', () {
      final query = engine.parseIntent('completely unrelated gibberish', id('a'));
      expect(query, isNotNull);
      expect(query!.relationKinds, isNull);
    });

    test('end to end: query(graph, parseIntent(...)) returns real results', () {
      final query = engine.parseIntent('show everything related', id('a'))!;
      final results = engine.query(chain, query);
      expect(results, isNotEmpty);
    });
  });
}
