/// Vision V9 WMSG — WorldPlanner (review-before-commit gate: clean merge
/// + consistent graph, or nothing is applied) and WorldModelEngine
/// (versioning, deterministic apply, rejected updates leave state
/// unchanged).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/graph_update.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_history.dart';
import 'package:anything/world_model/world_memory.dart';
import 'package:anything/world_model/world_model_engine.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_planner.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  EntityIdentity id(String s, WorldNodeKind kind) => EntityIdentity.stable(kind, s);

  group('WorldPlanner', () {
    const planner = WorldPlanner();

    test('a clean, consistent update is approved', () {
      const base = WorldGraph();
      final update = GraphUpdate(
        addedNodes: [
          WorldNode(identity: id('a', WorldNodeKind.entity), kind: WorldNodeKind.entity, label: 'a'),
          WorldNode(identity: id('b', WorldNodeKind.entity), kind: WorldNodeKind.entity, label: 'b'),
        ],
        addedEdges: [
          WorldEdge(
            fromId: id('a', WorldNodeKind.entity),
            toId: id('b', WorldNodeKind.entity),
            kind: RelationshipKind.relatesTo,
            evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'),
          ),
        ],
      );
      final result = planner.plan(base, update);
      expect(result.approved, isTrue);
    });

    test('an update whose edge dangles (targets a node not included) is honestly rejected', () {
      const base = WorldGraph();
      final update = GraphUpdate(
        addedNodes: [WorldNode(identity: id('a', WorldNodeKind.entity), kind: WorldNodeKind.entity, label: 'a')],
        addedEdges: [
          WorldEdge(
            fromId: id('a', WorldNodeKind.entity),
            toId: id('ghost', WorldNodeKind.entity),
            kind: RelationshipKind.relatesTo,
            evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'),
          ),
        ],
      );
      final result = planner.plan(base, update);
      expect(result.approved, isFalse);
      expect(result.validation.danglingEdges, isNotEmpty);
    });
  });

  group('WorldModelEngine', () {
    const engine = WorldModelEngine();

    test('a real, approved update advances the version and is recorded in history/memory', () {
      final model = engine.empty();
      final update = GraphUpdate(addedNodes: [WorldNode(identity: id('a', WorldNodeKind.entity), kind: WorldNodeKind.entity, label: 'a')]);
      final history = WorldHistory();
      final memory = WorldMemory();

      final updated = engine.apply(model, update, history: history, memory: memory);
      expect(updated.version.number, model.version.number + 1);
      expect(history.snapshotCount, 1);
      expect(memory.recall(updated.version.number)?.nodeCount, 1);
    });

    test('a rejected update leaves the model completely unchanged — never partially applied', () {
      final model = engine.empty();
      final badUpdate = GraphUpdate(
        addedEdges: [
          WorldEdge(
            fromId: id('a', WorldNodeKind.entity),
            toId: id('b', WorldNodeKind.entity),
            kind: RelationshipKind.relatesTo,
            evidence: const GraphEvidence(sourceGraph: 'g', sourceNodeId: 'n'),
          ),
        ],
      );
      final updated = engine.apply(model, badUpdate);
      expect(updated.version.number, model.version.number);
      expect(updated.graph.nodes, isEmpty);
      expect(updated.graph.edges, isEmpty);
    });
  });
}
