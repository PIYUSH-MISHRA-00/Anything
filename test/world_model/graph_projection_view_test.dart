/// Vision V9 WMSG — GraphProjection, GraphView (centered-on, bounded),
/// SemanticGraph.projectFrom (a real projection of WorldGraph, never a
/// second graph implementation).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/graph_projection.dart';
import 'package:anything/world_model/graph_view.dart';
import 'package:anything/world_model/semantic_graph.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  EntityIdentity id(String s, WorldNodeKind kind) =>
      EntityIdentity.stable(kind, s);

  final graph = WorldGraph(
    nodes: [
      WorldNode(
        identity: id('exp', WorldNodeKind.experience),
        kind: WorldNodeKind.experience,
        label: 'App',
      ),
      WorldNode(
        identity: id('task', WorldNodeKind.entity),
        kind: WorldNodeKind.entity,
        label: 'Task',
      ),
      WorldNode(
        identity: id('r1', WorldNodeKind.review),
        kind: WorldNodeKind.review,
        label: 'Finding',
      ),
    ],
    edges: [
      WorldEdge(
        fromId: id('exp', WorldNodeKind.experience),
        toId: id('task', WorldNodeKind.entity),
        kind: RelationshipKind.contains,
        evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'),
      ),
      WorldEdge(
        fromId: id('r1', WorldNodeKind.review),
        toId: id('task', WorldNodeKind.entity),
        kind: RelationshipKind.relatesTo,
        evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'),
      ),
    ],
  );

  test(
    'GraphProjection filters by node kind and only keeps edges within the projected set',
    () {
      const projection = GraphProjection();
      final projected = projection.project(
        graph,
        nodeKinds: {WorldNodeKind.experience, WorldNodeKind.entity},
      );
      expect(
        projected.nodes.map((n) => n.kind),
        everyElement(isIn({WorldNodeKind.experience, WorldNodeKind.entity})),
      );
      // The review->task edge is dropped since 'review' isn't in the projection.
      expect(projected.edges, hasLength(1));
    },
  );

  test(
    'GraphView.centeredOn returns a real, bounded subgraph reachable from the focus',
    () {
      final view = GraphView.centeredOn(
        graph,
        id('task', WorldNodeKind.entity),
        maxDepth: 1,
      );
      expect(
        view.nodes.map((n) => n.id),
        containsAll([
          id('exp', WorldNodeKind.experience).value,
          id('r1', WorldNodeKind.review).value,
        ]),
      );
    },
  );

  test(
    'SemanticGraph.projectFrom keeps only semantic-relevant kinds — review nodes are excluded',
    () {
      final semantic = SemanticGraph.projectFrom(graph);
      expect(
        semantic.nodes.any((n) => n.kind == WorldNodeKind.review),
        isFalse,
      );
      expect(
        semantic.nodes.any((n) => n.kind == WorldNodeKind.experience),
        isTrue,
      );
    },
  );
}
