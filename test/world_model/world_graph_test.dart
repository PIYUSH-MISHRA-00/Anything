/// Vision V9 WMSG — WorldNode/WorldEdge/WorldGraph, GraphIndex,
/// GraphResolver.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/graph_index.dart';
import 'package:anything/world_model/graph_resolver.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  final expId = EntityIdentity.stable(WorldNodeKind.experience, 'exp-1');
  final entityId = EntityIdentity.stable(WorldNodeKind.entity, 'task');
  final graph = WorldGraph(
    nodes: [
      WorldNode(
        identity: expId,
        kind: WorldNodeKind.experience,
        label: 'My App',
      ),
      WorldNode(identity: entityId, kind: WorldNodeKind.entity, label: 'Task'),
    ],
    edges: [
      WorldEdge(
        fromId: expId,
        toId: entityId,
        kind: RelationshipKind.contains,
        evidence: const GraphEvidence(sourceGraph: 'test', sourceNodeId: 'n'),
      ),
    ],
  );

  test('WorldGraph lookups are real and typed', () {
    expect(graph.nodeById(expId)?.label, 'My App');
    expect(graph.edgesFrom(expId), hasLength(1));
    expect(graph.edgesTo(entityId), hasLength(1));
    expect(graph.nodesOfKind(WorldNodeKind.entity), hasLength(1));
  });

  test('WorldGraph.concat never deduplicates — that is GraphMerge\'s job', () {
    final doubled = graph.concat(graph);
    expect(doubled.nodes, hasLength(4));
  });

  test('GraphIndex gives O(1)-shaped lookups matching the real graph', () {
    final index = GraphIndex.build(graph);
    expect(index.nodeById(expId)?.label, 'My App');
    expect(index.outgoingFrom(expId), hasLength(1));
    expect(index.incomingTo(entityId), hasLength(1));
    expect(index.outgoingFrom(entityId), isEmpty);
  });

  test(
    'GraphResolver resolves real references and reports absence honestly',
    () {
      final resolver = GraphResolver(graph);
      expect(resolver.exists(expId), isTrue);
      expect(
        resolver.exists(
          EntityIdentity.stable(WorldNodeKind.experience, 'ghost'),
        ),
        isFalse,
      );
      expect(resolver.resolveRelationships(expId), hasLength(1));
    },
  );
}
