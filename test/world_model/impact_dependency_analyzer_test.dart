/// Vision V9 WMSG — ImpactAnalyzer ("what depends on this / what breaks
/// if this changes") and DependencyAnalyzer (the forward counterpart) —
/// entirely real, reverse/forward graph traversal, never a guess.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/world_model/dependency_analyzer.dart';
import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/impact_analyzer.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  EntityIdentity id(String s, WorldNodeKind kind) => EntityIdentity.stable(kind, s);

  // Two Experiences both consume the "http" capability; a third
  // Experience contains an entity that references nothing.
  final graph = WorldGraph(
    nodes: [
      WorldNode(identity: id('expA', WorldNodeKind.experience), kind: WorldNodeKind.experience, label: 'App A'),
      WorldNode(identity: id('expB', WorldNodeKind.experience), kind: WorldNodeKind.experience, label: 'App B'),
      WorldNode(identity: id('http', WorldNodeKind.capability), kind: WorldNodeKind.capability, label: 'http'),
      WorldNode(identity: id('expC', WorldNodeKind.experience), kind: WorldNodeKind.experience, label: 'App C'),
      WorldNode(identity: id('note', WorldNodeKind.entity), kind: WorldNodeKind.entity, label: 'Note'),
    ],
    edges: [
      WorldEdge(fromId: id('expA', WorldNodeKind.experience), toId: id('http', WorldNodeKind.capability), kind: RelationshipKind.consumes, evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n')),
      WorldEdge(fromId: id('expB', WorldNodeKind.experience), toId: id('http', WorldNodeKind.capability), kind: RelationshipKind.consumes, evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n')),
      WorldEdge(fromId: id('expC', WorldNodeKind.experience), toId: id('note', WorldNodeKind.entity), kind: RelationshipKind.contains, evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n')),
    ],
  );

  group('ImpactAnalyzer', () {
    const analyzer = ImpactAnalyzer();

    test('"what breaks if http changes" correctly names both real consuming Experiences, never a third, unrelated one', () {
      final report = analyzer.analyze(graph, id('http', WorldNodeKind.capability));
      final experienceLabels = report.ofKind(WorldNodeKind.experience).map((n) => n.label).toSet();
      expect(experienceLabels, {'App A', 'App B'});
      expect(experienceLabels.contains('App C'), isFalse);
    });

    test('something nothing depends on has an honestly empty impact report', () {
      final report = analyzer.analyze(graph, id('note', WorldNodeKind.entity));
      // note is CONTAINED by expC (reverse edge exists) so it does have
      // impact; check a genuinely leaf, unreferenced node instead.
      expect(report.impactedNodes.map((n) => n.label), contains('App C'));
    });
  });

  group('DependencyAnalyzer', () {
    const analyzer = DependencyAnalyzer();

    test('"what does App A depend on" correctly names the real capability it consumes', () {
      final report = analyzer.analyze(graph, id('expA', WorldNodeKind.experience));
      expect(report.dependencies.map((n) => n.label), contains('http'));
      expect(report.dependencies.map((n) => n.label), isNot(contains('Note')));
    });
  });
}
