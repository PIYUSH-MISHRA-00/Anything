/// Vision V9 WMSG — GraphMerge (clean dedup + real conflict detection)
/// and GraphConsistency/GraphValidation (dangling-edge detection).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/graph_consistency.dart';
import 'package:anything/world_model/graph_merge.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  EntityIdentity id(String s, {WorldNodeKind kind = WorldNodeKind.entity}) => EntityIdentity.stable(kind, s);

  group('GraphMerge', () {
    const merge = GraphMerge();

    test('the identical identity with the identical kind/label deduplicates cleanly — no conflict', () {
      final base = WorldGraph(nodes: [WorldNode(identity: id('clock', kind: WorldNodeKind.capability), kind: WorldNodeKind.capability, label: 'clock')]);
      final incoming = WorldGraph(nodes: [WorldNode(identity: id('clock', kind: WorldNodeKind.capability), kind: WorldNodeKind.capability, label: 'clock')]);

      final result = merge.merge(base, incoming);
      expect(result.isClean, isTrue);
      expect(result.graph.nodes, hasLength(1));
    });

    test('the same identity claiming a different label is a real, surfaced conflict — never silently overwritten', () {
      final base = WorldGraph(nodes: [WorldNode(identity: id('x'), kind: WorldNodeKind.entity, label: 'Original Label')]);
      final incoming = WorldGraph(nodes: [WorldNode(identity: id('x'), kind: WorldNodeKind.entity, label: 'Different Label')]);

      final result = merge.merge(base, incoming);
      expect(result.isClean, isFalse);
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.first.identity, id('x'));
      // The original is preserved, never overwritten.
      expect(result.graph.nodeById(id('x'))?.label, 'Original Label');
    });

    test('edges deduplicate by from/to/kind, never doubling a real relationship', () {
      final e = WorldEdge(fromId: id('a'), toId: id('b'), kind: RelationshipKind.dependsOn, evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'));
      final base = WorldGraph(edges: [e]);
      final incoming = WorldGraph(edges: [e]);
      final result = merge.merge(base, incoming);
      expect(result.graph.edges, hasLength(1));
    });
  });

  group('GraphConsistency', () {
    const consistency = GraphConsistency();

    test('a graph with every edge endpoint present is valid', () {
      final graph = WorldGraph(
        nodes: [WorldNode(identity: id('a'), kind: WorldNodeKind.entity, label: 'a'), WorldNode(identity: id('b'), kind: WorldNodeKind.entity, label: 'b')],
        edges: [WorldEdge(fromId: id('a'), toId: id('b'), kind: RelationshipKind.relatesTo, evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'))],
      );
      expect(consistency.validate(graph).isValid, isTrue);
    });

    test('an edge referencing a missing node is a real, reported dangling edge', () {
      final graph = WorldGraph(
        nodes: [WorldNode(identity: id('a'), kind: WorldNodeKind.entity, label: 'a')],
        edges: [WorldEdge(fromId: id('a'), toId: id('ghost'), kind: RelationshipKind.relatesTo, evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'))],
      );
      final validation = consistency.validate(graph);
      expect(validation.isValid, isFalse);
      expect(validation.danglingEdges, hasLength(1));
    });
  });
}
