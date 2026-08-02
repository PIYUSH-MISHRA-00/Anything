/// Feature Discovery Engine — the entry point of Vision Milestone V4.
///
/// Given a FeatureDiscoveryContext (SemanticApp + RequirementGraph +
/// optional KnowledgeGraph), discovers FeatureCandidates structurally:
/// nothing here inspects an entity/field/view/capability *name* — only its
/// shape (field count, reference presence, view type, capability id,
/// non-functional category). A "Telescope Observation Log" and an "LMS"
/// with identically-shaped entities/views/capabilities produce identically
/// *typed* feature candidates.
///
/// Runs BEFORE Architecture in the Kernel pipeline (per the pipeline
/// diagram: RequirementGraph -> KnowledgeGraph -> Feature Discovery ->
/// Review -> Refinement -> Architecture), so it deliberately does not take
/// an ArchitectureCandidate — that would create a circular dependency.
library;

import '../synthesis/app_blueprint.dart' show BlueprintViewType;
import '../software_architect/requirement_graph.dart';
import 'feature_classifier.dart';
import 'feature_complexity_analyzer.dart';
import 'feature_confidence_analyzer.dart';
import 'feature_discovery_context.dart';
import 'feature_priority_analyzer.dart';
import 'feature_types.dart';

class FeatureDiscoveryEngine {
  const FeatureDiscoveryEngine();

  /// Capability ids known (today, in this codebase's fixed, cross-app
  /// infrastructure vocabulary — not a domain word) to require a platform
  /// permission grant. Mirrors the same honesty-first static-table pattern
  /// V2's PermissionPlanner already uses.
  static const Set<String> permissionRequiringCapabilities = {
    'camera',
    'microphone',
    'location',
    'bluetooth',
    'sensors',
    'notifications',
  };

  /// Capability ids that would resolve credentials, if one existed. No
  /// capability implemented in this codebase does today (confirmed in
  /// docs/security/TRUST_BOUNDARIES.md: CredentialVault is unused) — this
  /// set exists purely so the Credential Storage -> Kaalka -> Permission
  /// Strategy dependency chain is real, tested code with a documented,
  /// currently-dormant trigger, never a fabricated always-on feature.
  static const Set<String> credentialRequiringCapabilities = {'oauth', 'accounts'};

  List<FeatureCandidate> discover(FeatureDiscoveryContext context) {
    final app = context.app;
    final requirements = context.requirements;
    final candidates = <FeatureCandidate>[];

    for (final entity in app.entities) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:data:${entity.id}',
          name: 'Data management — ${entity.name}',
          category: FeatureCategory.data,
          sourceNodeIds: ['entity:${entity.id}'],
          rationale:
              'Entity "${entity.name}" is a first-class data model with '
              '${entity.fields.length} field(s).',
        ),
      );
      candidates.add(
        FeatureCandidate(
          id: 'feature:persistence:${entity.id}',
          name: 'Persistence — ${entity.name}',
          category: FeatureCategory.persistence,
          sourceNodeIds: ['storage:${entity.id}'],
          rationale:
              'Every entity requires durable local storage — the '
              'requirement graph always records a storage node per entity.',
        ),
      );

      for (final field in entity.fields) {
        if (field.referenceEntityId != null) {
          candidates.add(
            FeatureCandidate(
              id: 'feature:relational:${entity.id}.${field.id}',
              name: 'Relational navigation — ${entity.name}.${field.name}',
              category: FeatureCategory.relational,
              sourceNodeIds: ['relationship:${entity.id}.${field.id}'],
              rationale:
                  '"${field.name}" references another entity — the app '
                  'needs cross-entity lookup/navigation.',
            ),
          );
        }
      }
    }

    for (final view in app.views) {
      if (view.viewType == BlueprintViewType.list) {
        candidates.add(
          FeatureCandidate(
            id: 'feature:search:${view.id}',
            name: 'Search — ${view.name}',
            category: FeatureCategory.search,
            sourceNodeIds: ['view:${view.id}'],
            rationale:
                '"${view.name}" is a list view over potentially many '
                'records — search is expected once the list grows.',
          ),
        );
        candidates.add(
          FeatureCandidate(
            id: 'feature:index:${view.id}',
            name: 'Index support — ${view.name}',
            category: FeatureCategory.indexing,
            sourceNodeIds: ['view:${view.id}'],
            rationale:
                'The search feature above needs an efficient lookup path '
                '— indexing is its structural prerequisite.',
          ),
        );
      }
    }

    for (final capNode in requirements.nodesOfType(RequirementNodeType.capability)) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:capability:${capNode.label}',
          name: 'Capability — ${capNode.label}',
          category: FeatureCategory.capability,
          sourceNodeIds: [capNode.id],
          rationale: capNode.source == RequirementSource.explicit
              ? 'Explicitly required by the intent.'
              : 'Inferred from a declared network/service need.',
        ),
      );
    }

    if (app.views.isNotEmpty) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:navigation',
          name: 'Navigation',
          category: FeatureCategory.navigation,
          sourceNodeIds: requirements.nodesOfType(RequirementNodeType.navigation).map((n) => n.id).toList(),
          rationale: '${app.views.length} view(s) require navigation between them.',
        ),
      );
    }

    final constraintNodes = requirements.nodesOfType(RequirementNodeType.constraint);
    if (constraintNodes.isNotEmpty) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:validation',
          name: 'Validation',
          category: FeatureCategory.validation,
          sourceNodeIds: constraintNodes.map((n) => n.id).toList(),
          rationale: '${constraintNodes.length} explicit field constraint(s) require enforcement.',
        ),
      );
    }

    final stateNodes = requirements.nodesOfType(RequirementNodeType.state);
    if (stateNodes.isNotEmpty) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:state',
          name: 'State management',
          category: FeatureCategory.state,
          sourceNodeIds: stateNodes.map((n) => n.id).toList(),
          rationale: '${stateNodes.length} entity list(s) require reactive state.',
        ),
      );
    }

    for (final dv in app.derivedValues) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:reporting:${dv.id}',
          name: 'Reporting — ${dv.name}',
          category: FeatureCategory.reporting,
          sourceNodeIds: ['entity:${dv.sourceEntityId}'],
          rationale: '"${dv.name}" is a computed aggregate — a reporting/dashboard feature.',
        ),
      );
    }

    final offlineReq = requirements.nonFunctional
        .where((r) => r.category == NonFunctionalCategory.offline)
        .firstOrNull;
    candidates.add(
      FeatureCandidate(
        id: 'feature:offline',
        name: 'Offline strategy',
        category: FeatureCategory.offline,
        rationale: offlineReq?.description ?? 'Every application needs an explicit offline posture.',
      ),
    );

    candidates.add(
      const FeatureCandidate(
        id: 'feature:security:protection',
        name: 'Data protection',
        category: FeatureCategory.security,
        rationale: 'Kaalka-based time-protection is available for any generated Experience, opt-in.',
      ),
    );

    final capabilityCandidates = candidates.where((c) => c.category == FeatureCategory.capability).toList();
    final permissionTriggers = capabilityCandidates
        .where((c) => permissionRequiringCapabilities.contains(_capabilityIdOf(c)))
        .toList();
    if (permissionTriggers.isNotEmpty) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:permission:strategy',
          name: 'Permission strategy',
          category: FeatureCategory.permission,
          sourceNodeIds: permissionTriggers.map((c) => c.id).toList(),
          rationale: '${permissionTriggers.length} required capability(ies) need a declared platform permission strategy.',
        ),
      );
    }

    final credentialTriggers = capabilityCandidates
        .where((c) => credentialRequiringCapabilities.contains(_capabilityIdOf(c)))
        .toList();
    if (credentialTriggers.isNotEmpty) {
      candidates.add(
        FeatureCandidate(
          id: 'feature:security:credential_storage',
          name: 'Credential storage',
          category: FeatureCategory.security,
          sourceNodeIds: credentialTriggers.map((c) => c.id).toList(),
          rationale: '${credentialTriggers.length} required capability(ies) resolve credentials — needs vault-backed storage.',
        ),
      );
    }

    return candidates;
  }

  /// Full orchestration: discover -> classify (de-dupe) -> link (feature-
  /// to-feature edges) -> priority + complexity per feature -> confidence.
  /// Mirrors ArchitecturePlanner.plan()/EngineeringPlanner.plan()'s shape.
  FeatureGraph plan(FeatureDiscoveryContext context) {
    final raw = discover(context);
    final candidates = const FeatureClassifier().classify(raw);
    final edges = _buildEdges(candidates, context);

    const priorityAnalyzer = FeaturePriorityAnalyzer();
    const complexityAnalyzer = FeatureComplexityAnalyzer();

    final nodes = candidates.map((candidate) {
      final result = priorityAnalyzer.analyze(candidate, requirements: context.requirements);
      final complexity = complexityAnalyzer.analyze(candidate);
      final dependents = edges.where((e) => e.fromFeatureId == candidate.id).map((e) => e.toFeatureId).toList();

      return FeatureNode(
        candidate: candidate,
        priority: result.priority,
        complexity: complexity,
        decision: result.decision,
        explanation: FeatureExplanation(
          featureId: candidate.id,
          whyDiscovered: candidate.rationale,
          whyRequired: result.priority == FeaturePriority.mandatory
              ? 'Priority: mandatory — ${result.decision.rationale}'
              : null,
          whyOptional: result.priority == FeaturePriority.optional
              ? 'Priority: optional — ${result.decision.rationale}'
              : null,
          whyDependent: dependents.isNotEmpty ? 'Depends on: ${dependents.join(', ')}' : null,
        ),
      );
    }).toList();

    const confidenceAnalyzer = FeatureConfidenceAnalyzer();
    // Implementation Milestone R3: real, structural, bounded enrichment —
    // never a fabricated boost — see feature_confidence_analyzer.dart.
    final overallConfidence = confidenceAnalyzer.analyze(
      nodes.map((n) => n.decision).toList(),
      knowledge: context.knowledge,
      priorCapabilityIds: context.priorCapabilityIds,
    );

    return FeatureGraph(nodes: nodes, edges: edges, overallConfidence: overallConfidence);
  }

  /// Feature-to-feature edges: Search -> requires -> Index -> requires ->
  /// Persistence; Capability -> dependsOn -> Permission Strategy /
  /// Credential Storage; Credential Storage -> requires -> Data Protection
  /// (Kaalka) + Permission Strategy; Relational/Reporting -> dependsOn ->
  /// the owning entity's Persistence; Offline -> dependsOn -> every
  /// Persistence feature.
  List<FeatureEdge> _buildEdges(List<FeatureCandidate> candidates, FeatureDiscoveryContext context) {
    final byId = {for (final c in candidates) c.id: c};
    final edges = <FeatureEdge>[];

    for (final view in context.app.views) {
      if (view.viewType != BlueprintViewType.list) continue;
      final searchId = 'feature:search:${view.id}';
      final indexId = 'feature:index:${view.id}';
      if (!byId.containsKey(searchId) || !byId.containsKey(indexId)) continue;
      edges.add(FeatureEdge(fromFeatureId: searchId, toFeatureId: indexId, kind: FeatureRelationKind.requires));

      final entityId = view.sourceEntityId;
      final persistenceId = 'feature:persistence:$entityId';
      if (entityId != null && byId.containsKey(persistenceId)) {
        edges.add(FeatureEdge(fromFeatureId: indexId, toFeatureId: persistenceId, kind: FeatureRelationKind.requires));
      }
    }

    for (final entity in context.app.entities) {
      for (final field in entity.fields) {
        if (field.referenceEntityId == null) continue;
        final relationalId = 'feature:relational:${entity.id}.${field.id}';
        final persistenceId = 'feature:persistence:${entity.id}';
        if (byId.containsKey(relationalId) && byId.containsKey(persistenceId)) {
          edges.add(
            FeatureEdge(fromFeatureId: relationalId, toFeatureId: persistenceId, kind: FeatureRelationKind.dependsOn),
          );
        }
      }
    }

    for (final dv in context.app.derivedValues) {
      final reportingId = 'feature:reporting:${dv.id}';
      final persistenceId = 'feature:persistence:${dv.sourceEntityId}';
      if (byId.containsKey(reportingId) && byId.containsKey(persistenceId)) {
        edges.add(
          FeatureEdge(fromFeatureId: reportingId, toFeatureId: persistenceId, kind: FeatureRelationKind.dependsOn),
        );
      }
    }

    if (byId.containsKey('feature:offline')) {
      for (final c in candidates.where((c) => c.category == FeatureCategory.persistence)) {
        edges.add(FeatureEdge(fromFeatureId: 'feature:offline', toFeatureId: c.id, kind: FeatureRelationKind.dependsOn));
      }
    }

    if (byId.containsKey('feature:permission:strategy')) {
      for (final capFeatureId in byId['feature:permission:strategy']!.sourceNodeIds) {
        if (byId.containsKey(capFeatureId)) {
          edges.add(
            FeatureEdge(
              fromFeatureId: capFeatureId,
              toFeatureId: 'feature:permission:strategy',
              kind: FeatureRelationKind.dependsOn,
            ),
          );
        }
      }
    }

    if (byId.containsKey('feature:security:credential_storage')) {
      final credentialId = 'feature:security:credential_storage';
      for (final capFeatureId in byId[credentialId]!.sourceNodeIds) {
        if (byId.containsKey(capFeatureId)) {
          edges.add(
            FeatureEdge(fromFeatureId: capFeatureId, toFeatureId: credentialId, kind: FeatureRelationKind.dependsOn),
          );
        }
      }
      if (byId.containsKey('feature:security:protection')) {
        edges.add(
          FeatureEdge(
            fromFeatureId: credentialId,
            toFeatureId: 'feature:security:protection',
            kind: FeatureRelationKind.requires,
          ),
        );
      }
      if (byId.containsKey('feature:permission:strategy')) {
        edges.add(
          FeatureEdge(
            fromFeatureId: credentialId,
            toFeatureId: 'feature:permission:strategy',
            kind: FeatureRelationKind.requires,
          ),
        );
      }
    }

    return edges;
  }

  String _capabilityIdOf(FeatureCandidate c) => c.id.replaceFirst('feature:capability:', '');
}
