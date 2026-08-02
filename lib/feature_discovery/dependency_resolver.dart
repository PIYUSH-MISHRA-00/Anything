/// Dependency Resolvers — expand a FeatureCandidate into the concrete
/// capability/permission/storage/navigation primitives it bottoms out in.
/// Five resolvers, one per concern, sharing one typed interface; assembled
/// into a single DependencyGraph by DependencyGraphBuilder.
library;

import 'dependency_types.dart';
import 'feature_types.dart';

abstract class DependencyResolver {
  const DependencyResolver();

  List<FeatureDependency> resolve({
    required FeatureCandidate candidate,
    required List<FeatureCandidate> allCandidates,
  });
}

/// Every persistence feature bottoms out in the real, single generic
/// SQLite table ExperienceDatabase uses — no other storage kind exists on
/// the live path today.
class StorageDependencyResolver extends DependencyResolver {
  const StorageDependencyResolver();

  @override
  List<FeatureDependency> resolve({
    required FeatureCandidate candidate,
    required List<FeatureCandidate> allCandidates,
  }) {
    if (candidate.category != FeatureCategory.persistence) return const [];
    return [
      FeatureDependency(
        featureId: candidate.id,
        dependsOnKind: DependencyNodeKind.storage,
        dependsOnId: 'storage:sqlite',
        dependsOnLabel: 'SQLite generic storage',
        rationale:
            'ExperienceDatabase persists every entity as a JSON blob row '
            'in one generic SQLite table.',
      ),
    ];
  }
}

/// Links the (currently dormant — see credentialRequiringCapabilities in
/// FeatureDiscoveryEngine) Credential Storage feature back to the concrete
/// capability primitive(s) that triggered it.
class CapabilityDependencyResolver extends DependencyResolver {
  const CapabilityDependencyResolver();

  @override
  List<FeatureDependency> resolve({
    required FeatureCandidate candidate,
    required List<FeatureCandidate> allCandidates,
  }) {
    if (candidate.id != 'feature:security:credential_storage') return const [];
    return candidate.sourceNodeIds.map((capFeatureId) {
      final capId = capFeatureId.replaceFirst('feature:capability:', '');
      return FeatureDependency(
        featureId: candidate.id,
        dependsOnKind: DependencyNodeKind.capability,
        dependsOnId: 'capability:$capId',
        dependsOnLabel: capId,
        rationale: 'Credential storage is required because capability "$capId" resolves credentials.',
      );
    }).toList();
  }
}

/// Expands the aggregate Permission Strategy feature into one concrete
/// per-capability permission primitive.
class PermissionDependencyResolver extends DependencyResolver {
  const PermissionDependencyResolver();

  @override
  List<FeatureDependency> resolve({
    required FeatureCandidate candidate,
    required List<FeatureCandidate> allCandidates,
  }) {
    if (candidate.id != 'feature:permission:strategy') return const [];
    return candidate.sourceNodeIds.map((capFeatureId) {
      final capId = capFeatureId.replaceFirst('feature:capability:', '');
      return FeatureDependency(
        featureId: candidate.id,
        dependsOnKind: DependencyNodeKind.permission,
        dependsOnId: 'permission:$capId',
        dependsOnLabel: '$capId permission',
        rationale: 'Capability "$capId" requires a declared platform permission.',
      );
    }).toList();
  }
}

/// Search and relational-navigation features both need somewhere to
/// navigate to (a detail/target screen) — the real ExperienceRouter graph.
class NavigationDependencyResolver extends DependencyResolver {
  const NavigationDependencyResolver();

  @override
  List<FeatureDependency> resolve({
    required FeatureCandidate candidate,
    required List<FeatureCandidate> allCandidates,
  }) {
    if (candidate.category != FeatureCategory.search && candidate.category != FeatureCategory.relational) {
      return const [];
    }
    return [
      FeatureDependency(
        featureId: candidate.id,
        dependsOnKind: DependencyNodeKind.navigation,
        dependsOnId: 'navigation:global',
        dependsOnLabel: 'App navigation graph',
        rationale: 'Search/relational results need to navigate to a detail or target screen.',
      ),
    ];
  }
}

/// The offline strategy feature depends on local persistence remaining
/// available without network — one dependency per app, not per entity.
class OfflineDependencyResolver extends DependencyResolver {
  const OfflineDependencyResolver();

  @override
  List<FeatureDependency> resolve({
    required FeatureCandidate candidate,
    required List<FeatureCandidate> allCandidates,
  }) {
    if (candidate.category != FeatureCategory.offline) return const [];
    final hasPersistence = allCandidates.any((c) => c.category == FeatureCategory.persistence);
    if (!hasPersistence) return const [];
    return [
      FeatureDependency(
        featureId: candidate.id,
        dependsOnKind: DependencyNodeKind.storage,
        dependsOnId: 'storage:sqlite',
        dependsOnLabel: 'SQLite generic storage',
        rationale: 'Offline behavior depends on local persistence remaining available without network.',
      ),
    ];
  }
}

/// Runs every resolver over every candidate and assembles one typed
/// DependencyGraph — a DependencyNode per feature plus one per unique
/// concrete primitive it resolves to, and a DependencyEdge per resolved
/// FeatureDependency.
class DependencyGraphBuilder {
  final List<DependencyResolver> resolvers;

  const DependencyGraphBuilder({
    this.resolvers = const [
      StorageDependencyResolver(),
      CapabilityDependencyResolver(),
      PermissionDependencyResolver(),
      NavigationDependencyResolver(),
      OfflineDependencyResolver(),
    ],
  });

  DependencyGraph build(List<FeatureCandidate> candidates) {
    final nodes = <DependencyNode>[
      for (final c in candidates) DependencyNode(id: c.id, kind: DependencyNodeKind.feature, label: c.name),
    ];
    final nodeIds = nodes.map((n) => n.id).toSet();
    final edges = <DependencyEdge>[];

    for (final candidate in candidates) {
      for (final resolver in resolvers) {
        final dependencies = resolver.resolve(candidate: candidate, allCandidates: candidates);
        for (final dep in dependencies) {
          if (nodeIds.add(dep.dependsOnId)) {
            nodes.add(DependencyNode(id: dep.dependsOnId, kind: dep.dependsOnKind, label: dep.dependsOnLabel));
          }
          edges.add(DependencyEdge(fromId: dep.featureId, toId: dep.dependsOnId, relation: dep.relation));
        }
      }
    }

    return DependencyGraph(nodes: nodes, edges: edges);
  }
}
