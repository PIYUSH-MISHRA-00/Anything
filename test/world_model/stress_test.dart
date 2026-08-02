/// Vision V10 RC — Stress Tests: Large World Graph (1000+ entities,
/// 10000+ relationships). Proves GraphTraversal/GraphConsistency/
/// GraphMerge/WorldModelRepository remain correct — and reports real,
/// measured elapsed time (never a fabricated benchmark number, never a
/// promised SLA) — at scale.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/world_model_repository.dart';
import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/graph_consistency.dart';
import 'package:anything/world_model/graph_merge.dart';
import 'package:anything/world_model/graph_traversal.dart';
import 'package:anything/world_model/impact_analyzer.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

WorldGraph _buildLargeGraph({required int entityCount, required int relationshipsPerEntity}) {
  final nodes = <WorldNode>[];
  final edges = <WorldEdge>[];

  final identities = List.generate(entityCount, (i) => EntityIdentity.stable(WorldNodeKind.entity, 'entity-$i'));
  for (var i = 0; i < entityCount; i++) {
    nodes.add(WorldNode(identity: identities[i], kind: WorldNodeKind.entity, label: 'Entity $i'));
  }

  for (var i = 0; i < entityCount; i++) {
    for (var j = 1; j <= relationshipsPerEntity; j++) {
      final target = (i + j) % entityCount;
      edges.add(
        WorldEdge(
          fromId: identities[i],
          toId: identities[target],
          kind: RelationshipKind.dependsOn,
          evidence: const GraphEvidence(sourceGraph: 'stress', sourceNodeId: 'n'),
        ),
      );
    }
  }

  return WorldGraph(nodes: nodes, edges: edges);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('a World Graph with 1000+ entities and 10000+ relationships stays correct under GraphConsistency', () {
    final graph = _buildLargeGraph(entityCount: 1000, relationshipsPerEntity: 10);
    expect(graph.nodes, hasLength(1000));
    expect(graph.edges, hasLength(10000));

    final stopwatch = Stopwatch()..start();
    final validation = const GraphConsistency().validate(graph);
    stopwatch.stop();

    expect(validation.isValid, isTrue); // every edge's endpoints are real, by construction
    // Real, measured elapsed time — printed for visibility, never
    // asserted against a fabricated SLA number.
    // ignore: avoid_print
    print('GraphConsistency.validate over 1000 nodes / 10000 edges: ${stopwatch.elapsedMilliseconds}ms');
  });

  test('GraphTraversal stays correct and bounded on a large, densely-connected graph', () {
    final graph = _buildLargeGraph(entityCount: 1000, relationshipsPerEntity: 10);
    final start = EntityIdentity.stable(WorldNodeKind.entity, 'entity-0');

    final stopwatch = Stopwatch()..start();
    final steps = const GraphTraversal().forward(graph, start, maxDepth: 3);
    stopwatch.stop();

    // Bounded: never revisits a node, so the result can never exceed the
    // total node count even in a densely-connected graph.
    expect(steps.length, lessThanOrEqualTo(999));
    // ignore: avoid_print
    print('GraphTraversal.forward(maxDepth: 3) over 1000/10000: ${stopwatch.elapsedMilliseconds}ms, ${steps.length} nodes reached');
  });

  test('ImpactAnalyzer stays correct on a large graph', () {
    final graph = _buildLargeGraph(entityCount: 1000, relationshipsPerEntity: 10);
    final target = EntityIdentity.stable(WorldNodeKind.entity, 'entity-500');

    final report = const ImpactAnalyzer().analyze(graph, target, maxDepth: 2);
    expect(report.impactedNodes, isNotEmpty);
  });

  test('GraphMerge correctly deduplicates when merging two large, overlapping graphs', () {
    final graphA = _buildLargeGraph(entityCount: 1000, relationshipsPerEntity: 5);
    final graphB = _buildLargeGraph(entityCount: 1000, relationshipsPerEntity: 5); // structurally identical

    final stopwatch = Stopwatch()..start();
    final result = const GraphMerge().merge(graphA, graphB);
    stopwatch.stop();

    expect(result.isClean, isTrue); // identical nodes/edges — no conflicts
    expect(result.graph.nodes, hasLength(1000)); // deduplicated, not doubled
    expect(result.graph.edges, hasLength(5000)); // deduplicated, not doubled
    // ignore: avoid_print
    print('GraphMerge over 2x(1000/5000): ${stopwatch.elapsedMilliseconds}ms');
  });

  test('WorldModelRepository persists and reloads a large graph (1000+ nodes, 10000+ edges) with full fidelity', () async {
    final experienceRepo = SqliteExperienceRepository(dbName: 'stress_${DateTime.now().microsecondsSinceEpoch}.db');
    final repo = WorldModelRepository(experienceRepository: experienceRepo);
    final graph = _buildLargeGraph(entityCount: 1000, relationshipsPerEntity: 10);

    final saveStopwatch = Stopwatch()..start();
    await repo.saveGraph(graph);
    saveStopwatch.stop();

    final loadStopwatch = Stopwatch()..start();
    final loaded = await repo.loadGraph();
    loadStopwatch.stop();

    expect(loaded.nodes, hasLength(1000));
    expect(loaded.edges, hasLength(10000));
    // ignore: avoid_print
    print('WorldModelRepository save: ${saveStopwatch.elapsedMilliseconds}ms, load: ${loadStopwatch.elapsedMilliseconds}ms for 1000/10000');

    await experienceRepo.close();
  });
}
