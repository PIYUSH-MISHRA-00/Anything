/// Vision V4 FDI — DependencyResolvers + DependencyGraphBuilder: expanding
/// FeatureCandidates into concrete capability/permission/storage/
/// navigation primitives.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/dependency_types.dart';
import 'package:anything/feature_discovery/feature_types.dart';

const _persistence = FeatureCandidate(
  id: 'feature:persistence:inspection',
  name: 'Persistence — Inspection',
  category: FeatureCategory.persistence,
  rationale: 'r',
);
const _search = FeatureCandidate(
  id: 'feature:search:list',
  name: 'Search',
  category: FeatureCategory.search,
  rationale: 'r',
);
const _relational = FeatureCandidate(
  id: 'feature:relational:a.b',
  name: 'Relational',
  category: FeatureCategory.relational,
  rationale: 'r',
);
const _offline = FeatureCandidate(
  id: 'feature:offline',
  name: 'Offline',
  category: FeatureCategory.offline,
  rationale: 'r',
);
const _permissionStrategy = FeatureCandidate(
  id: 'feature:permission:strategy',
  name: 'Permission strategy',
  category: FeatureCategory.permission,
  sourceNodeIds: ['feature:capability:camera'],
  rationale: 'r',
);
const _credentialStorage = FeatureCandidate(
  id: 'feature:security:credential_storage',
  name: 'Credential storage',
  category: FeatureCategory.security,
  sourceNodeIds: ['feature:capability:oauth'],
  rationale: 'r',
);

void main() {
  group('StorageDependencyResolver', () {
    const resolver = StorageDependencyResolver();

    test(
      'every persistence feature depends on the real SQLite storage primitive',
      () {
        final deps = resolver.resolve(
          candidate: _persistence,
          allCandidates: [_persistence],
        );
        expect(deps, hasLength(1));
        expect(deps.single.dependsOnKind, DependencyNodeKind.storage);
        expect(deps.single.dependsOnId, 'storage:sqlite');
      },
    );

    test('ignores non-persistence candidates', () {
      expect(
        resolver.resolve(candidate: _search, allCandidates: [_search]),
        isEmpty,
      );
    });
  });

  group('NavigationDependencyResolver', () {
    const resolver = NavigationDependencyResolver();

    test(
      'search and relational features depend on the app navigation graph',
      () {
        expect(
          resolver.resolve(candidate: _search, allCandidates: [_search]),
          hasLength(1),
        );
        expect(
          resolver.resolve(
            candidate: _relational,
            allCandidates: [_relational],
          ),
          hasLength(1),
        );
      },
    );

    test('ignores unrelated categories', () {
      expect(
        resolver.resolve(
          candidate: _persistence,
          allCandidates: [_persistence],
        ),
        isEmpty,
      );
    });
  });

  group('OfflineDependencyResolver', () {
    const resolver = OfflineDependencyResolver();

    test(
      'offline strategy depends on storage only when persistence exists',
      () {
        final withPersistence = resolver.resolve(
          candidate: _offline,
          allCandidates: [_offline, _persistence],
        );
        expect(withPersistence, hasLength(1));

        final withoutPersistence = resolver.resolve(
          candidate: _offline,
          allCandidates: [_offline],
        );
        expect(withoutPersistence, isEmpty);
      },
    );
  });

  group('PermissionDependencyResolver', () {
    const resolver = PermissionDependencyResolver();

    test(
      'expands the aggregate permission-strategy feature into per-capability primitives',
      () {
        final deps = resolver.resolve(
          candidate: _permissionStrategy,
          allCandidates: [_permissionStrategy],
        );
        expect(deps, hasLength(1));
        expect(deps.single.dependsOnKind, DependencyNodeKind.permission);
        expect(deps.single.dependsOnId, 'permission:camera');
      },
    );
  });

  group('CapabilityDependencyResolver', () {
    const resolver = CapabilityDependencyResolver();

    test('links credential storage back to the triggering capability', () {
      final deps = resolver.resolve(
        candidate: _credentialStorage,
        allCandidates: [_credentialStorage],
      );
      expect(deps, hasLength(1));
      expect(deps.single.dependsOnKind, DependencyNodeKind.capability);
      expect(deps.single.dependsOnId, 'capability:oauth');
    });

    test('ignores features other than credential storage', () {
      expect(
        resolver.resolve(
          candidate: _persistence,
          allCandidates: [_persistence],
        ),
        isEmpty,
      );
    });
  });

  group('DependencyGraphBuilder', () {
    test(
      'assembles one node per feature plus one per unique concrete primitive',
      () {
        const builder = DependencyGraphBuilder();
        final graph = builder.build([_persistence, _search, _offline]);

        expect(graph.nodeById('feature:persistence:inspection'), isNotNull);
        expect(graph.nodeById('storage:sqlite'), isNotNull);
        expect(graph.nodeById('navigation:global'), isNotNull);

        // storage:sqlite is depended on by both persistence and offline —
        // exactly one node, not duplicated.
        final storageNodes = graph.nodes.where((n) => n.id == 'storage:sqlite');
        expect(storageNodes, hasLength(1));
      },
    );

    test('every resolved dependency becomes a real typed edge', () {
      const builder = DependencyGraphBuilder();
      final graph = builder.build([_persistence]);
      final edge = graph.edgesFrom('feature:persistence:inspection').single;
      expect(edge.toId, 'storage:sqlite');
      expect(edge.relation, FeatureRelationKind.requires);
    });
  });
}
