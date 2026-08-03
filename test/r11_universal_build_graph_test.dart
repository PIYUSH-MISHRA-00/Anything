/// Implementation Milestone R11 — Universal Build Graph. Proves the real,
/// deterministic derivation of a build-scoped dependency graph from
/// `CanonicalImplementationModel` (R9), real cycle detection, real
/// topological build ordering, and that the Generator Framework (R10)
/// genuinely now consumes `UniversalBuildGraph` instead of
/// `CanonicalImplementationModel` directly (see the updated
/// `test/r10_generator_framework_test.dart`, whose full regression this
/// milestone also depends on).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/build_graph/build_graph.dart';
import 'package:anything/build_graph/build_graph_analysis.dart';
import 'package:anything/build_graph/universal_build_graph.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';

CanonicalImplementationModel _twoEntityModel() {
  return const CanonicalImplementationModel(
    entities: [
      ImplementationEntity(id: 'task', name: 'Task', fields: [ImplementationField(id: 'task.title', name: 'title', type: ImplementationDataType.text, required: true)]),
      ImplementationEntity(id: 'tag', name: 'Tag', fields: [ImplementationField(id: 'tag.label', name: 'label', type: ImplementationDataType.text, required: true)]),
    ],
    repositories: [ImplementationRepository(id: 'task.repository', entityId: 'task', supportedOperations: [ImplementationOperationKind.list, ImplementationOperationKind.create])],
    controllers: [ImplementationController(id: 'task.controller', entityId: 'task')],
    dependencies: [ImplementationDependency(fromId: 'task', toId: 'tag', kind: DependencyKind.entityReference)],
    capabilityAdapters: [CapabilityAdapterSpec(capabilityId: 'storage', category: 'storage')],
    authentication: AuthenticationAdapterSpec(requiresCredentials: false),
    backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
  );
}

void main() {
  group('BuildGraphBuilder (R11)', () {
    test('every entity/repository/controller/capability becomes a real node', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());

      expect(graph.nodes.map((n) => n.id), containsAll(['task', 'tag', 'task.repository', 'task.controller', 'storage']));
      expect(graph.nodes.firstWhere((n) => n.id == 'task').kind, BuildNodeKind.entity);
      expect(graph.nodes.firstWhere((n) => n.id == 'task.repository').kind, BuildNodeKind.repository);
      expect(graph.nodes.firstWhere((n) => n.id == 'storage').kind, BuildNodeKind.capability);
    });

    test('real dependency, repository->entity, and controller->entity edges are all present', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());

      expect(graph.edges, contains(const BuildGraphEdge(fromId: 'task', toId: 'tag', kind: BuildRelationshipKind.dependsOn)));
      expect(graph.edges, contains(const BuildGraphEdge(fromId: 'task.repository', toId: 'task', kind: BuildRelationshipKind.dependsOn)));
      expect(graph.edges, contains(const BuildGraphEdge(fromId: 'task.controller', toId: 'task', kind: BuildRelationshipKind.dependsOn)));
    });

    test('an edge referencing a non-existent node is never emitted — never a dangling edge', () {
      final model = CanonicalImplementationModel(
        entities: const [ImplementationEntity(id: 'a', name: 'A')],
        dependencies: const [ImplementationDependency(fromId: 'app', toId: 'ai', kind: DependencyKind.capability)],
        authentication: const AuthenticationAdapterSpec(requiresCredentials: false),
        backgroundWorker: const BackgroundWorkerSpec(requiresBackgroundSync: false),
      );
      final graph = const BuildGraphBuilder().build(model);

      expect(graph.edges, isEmpty, reason: 'neither app nor ai is a real node in this model, so the dependency must not become a dangling edge');
    });

    test('sourceModel retains the exact original CanonicalImplementationModel', () {
      final model = _twoEntityModel();
      final graph = const BuildGraphBuilder().build(model);
      expect(graph.sourceModel, same(model));
    });

    test('determinism: building the same model twice produces structurally identical graphs', () {
      final model = _twoEntityModel();
      final g1 = const BuildGraphBuilder().build(model);
      final g2 = const BuildGraphBuilder().build(model);

      expect(g1.nodes.map((n) => n.id).toList(), g2.nodes.map((n) => n.id).toList());
      expect(g1.edges.length, g2.edges.length);
    });
  });

  group('BuildGraphCycleDetector (R11)', () {
    test('an acyclic graph is correctly reported as having no cycle', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());
      final result = const BuildGraphCycleDetector().detect(graph);
      expect(result.hasCycle, isFalse);
    });

    test('a real, artificially-constructed cyclic dependency is correctly caught', () {
      const graph = UniversalBuildGraph(
        nodes: [
          BuildGraphNode(id: 'x', kind: BuildNodeKind.entity, label: 'X'),
          BuildGraphNode(id: 'y', kind: BuildNodeKind.entity, label: 'Y'),
          BuildGraphNode(id: 'z', kind: BuildNodeKind.entity, label: 'Z'),
        ],
        edges: [
          BuildGraphEdge(fromId: 'x', toId: 'y', kind: BuildRelationshipKind.dependsOn),
          BuildGraphEdge(fromId: 'y', toId: 'z', kind: BuildRelationshipKind.dependsOn),
          BuildGraphEdge(fromId: 'z', toId: 'x', kind: BuildRelationshipKind.dependsOn),
        ],
        sourceModel: CanonicalImplementationModel(authentication: AuthenticationAdapterSpec(requiresCredentials: false), backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false)),
      );

      final result = const BuildGraphCycleDetector().detect(graph);
      expect(result.hasCycle, isTrue);
      expect(result.cycleNodeIds, containsAll(['x', 'y', 'z']));
    });

    test('two nodes sharing a common dependency (a diamond, not a cycle) is correctly NOT flagged', () {
      const graph = UniversalBuildGraph(
        nodes: [
          BuildGraphNode(id: 'a', kind: BuildNodeKind.entity, label: 'A'),
          BuildGraphNode(id: 'b', kind: BuildNodeKind.entity, label: 'B'),
          BuildGraphNode(id: 'c', kind: BuildNodeKind.entity, label: 'C'),
        ],
        edges: [
          BuildGraphEdge(fromId: 'a', toId: 'c', kind: BuildRelationshipKind.dependsOn),
          BuildGraphEdge(fromId: 'b', toId: 'c', kind: BuildRelationshipKind.dependsOn),
        ],
        sourceModel: CanonicalImplementationModel(authentication: AuthenticationAdapterSpec(requiresCredentials: false), backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false)),
      );

      expect(const BuildGraphCycleDetector().detect(graph).hasCycle, isFalse);
    });
  });

  group('BuildGraphOrderer (R11)', () {
    test('a real dependency chain produces a correct, complete topological order — dependencies before dependents', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());
      final result = const BuildGraphOrderer().order(graph);

      expect(result.isComplete, isTrue);
      expect(result.orderedNodeIds.indexOf('task'), lessThan(result.orderedNodeIds.indexOf('task.repository')));
      expect(result.orderedNodeIds.indexOf('task'), lessThan(result.orderedNodeIds.indexOf('task.controller')));
      expect(result.orderedNodeIds.indexOf('tag'), lessThan(result.orderedNodeIds.indexOf('task')));
    });

    test('a cyclic graph honestly reports an incomplete order — never a fabricated one', () {
      const graph = UniversalBuildGraph(
        nodes: [BuildGraphNode(id: 'x', kind: BuildNodeKind.entity, label: 'X'), BuildGraphNode(id: 'y', kind: BuildNodeKind.entity, label: 'Y')],
        edges: [BuildGraphEdge(fromId: 'x', toId: 'y', kind: BuildRelationshipKind.dependsOn), BuildGraphEdge(fromId: 'y', toId: 'x', kind: BuildRelationshipKind.dependsOn)],
        sourceModel: CanonicalImplementationModel(authentication: AuthenticationAdapterSpec(requiresCredentials: false), backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false)),
      );

      final result = const BuildGraphOrderer().order(graph);
      expect(result.isComplete, isFalse);
      expect(result.orderedNodeIds.length, lessThan(2));
    });

    test('determinism: ordering the same graph twice produces the exact same order', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());
      final o1 = const BuildGraphOrderer().order(graph).orderedNodeIds;
      final o2 = const BuildGraphOrderer().order(graph).orderedNodeIds;
      expect(o1, o2);
    });
  });

  group('Performance (R11)', () {
    test('building and ordering a large (200-entity) chain stays correct and reports real elapsed time', () {
      final entities = List.generate(200, (i) => ImplementationEntity(id: 'e$i', name: 'Entity$i'));
      final deps = List.generate(199, (i) => ImplementationDependency(fromId: 'e${i + 1}', toId: 'e$i', kind: DependencyKind.entityReference));
      final model = CanonicalImplementationModel(
        entities: entities,
        dependencies: deps,
        authentication: const AuthenticationAdapterSpec(requiresCredentials: false),
        backgroundWorker: const BackgroundWorkerSpec(requiresBackgroundSync: false),
      );

      final stopwatch = Stopwatch()..start();
      final graph = const BuildGraphBuilder().build(model);
      final cycleResult = const BuildGraphCycleDetector().detect(graph);
      final orderResult = const BuildGraphOrderer().order(graph);
      stopwatch.stop();

      expect(graph.nodes, hasLength(200));
      expect(cycleResult.hasCycle, isFalse);
      expect(orderResult.isComplete, isTrue);
      expect(orderResult.orderedNodeIds.first, 'e0');
      // ignore: avoid_print
      print('BuildGraph build+cycle-detect+order over 200 entities/199 deps: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
