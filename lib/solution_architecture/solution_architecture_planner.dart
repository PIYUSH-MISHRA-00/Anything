/// SolutionArchitecturePlanner — Implementation Milestone R17. Real,
/// deterministic derivation from the SAME already-computed
/// `ArchitectureCandidate` (Vision Milestone V2/V5, frontend) +
/// `BackendEngineeringPlan` (Implementation Milestone R8, backend) —
/// zero new AI call, zero new upstream dependency. Mirrors
/// `BackendEngineeringPlanner`/`CanonicalImplementationPlanner`'s own
/// derivation-function-per-concern shape.
library;

import '../backend_engineering/backend_engineering_plan.dart';
import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_types.dart' show SyncStrategy;
import 'solution_architecture.dart';

class SolutionArchitecturePlanner {
  const SolutionArchitecturePlanner();

  /// The 8 R17 concepts with zero real signal anywhere in
  /// `ArchitectureCandidate`/`BackendEngineeringPlan` today — a static,
  /// honest fact about this codebase's current engineering models, not a
  /// per-request computation (see `solution_architecture.dart`'s top-level
  /// doc comment for why each one is genuinely absent).
  static const List<UnmodeledConcept> standingGaps = [
    UnmodeledConcept(
      name: 'realtime',
      reason: 'No websocket/push/live-channel concept exists anywhere in ArchitectureCandidate or BackendEngineeringPlan to derive from.',
    ),
    UnmodeledConcept(name: 'messaging', reason: 'No message-queue/pub-sub concept exists anywhere upstream.'),
    UnmodeledConcept(
      name: 'notifications',
      reason: 'CapabilityCategory has no notification category; NotificationCapability is a runtime capability, not an architecture-level decision.',
    ),
    UnmodeledConcept(name: 'observability', reason: 'No tracing/telemetry concept exists anywhere upstream.'),
    UnmodeledConcept(name: 'monitoring', reason: 'No health-check/alerting concept exists anywhere upstream.'),
    UnmodeledConcept(
      name: 'configuration',
      reason: 'No environment/config-variable concept exists anywhere upstream (SecretReference names secrets only, never config).',
    ),
    UnmodeledConcept(
      name: 'policies',
      reason: 'PermissionDecision models capability access control; no distinct business/data policy concept exists upstream.',
    ),
    UnmodeledConcept(name: 'scaling', reason: 'No load/instance/throughput concept exists anywhere upstream.'),
  ];

  SemanticSolutionArchitecture plan(ArchitectureCandidate frontend, BackendEngineeringPlan backend) {
    return SemanticSolutionArchitecture(
      frontend: frontend,
      backend: backend,
      components: _planComponents(frontend, backend),
      caching: _planCaching(backend),
      unmodeledConcepts: standingGaps,
    );
  }

  List<SolutionComponent> _planComponents(ArchitectureCandidate frontend, BackendEngineeringPlan backend) => [
    for (final entity in frontend.entities)
      SolutionComponent(
        id: entity.entityId,
        name: entity.name,
        responsibility: 'Owns and manages ${entity.name} records and behavior.',
        hasBackendPresence: backend.api.endpointsForEntity(entity.entityId).isNotEmpty,
        storageKind: entity.storage.name,
        dependsOnComponentIds: [
          for (final fk in (backend.database.tableById(entity.entityId)?.foreignKeys ?? const [])) fk.referencesTableId,
        ],
        contractIds: backend.api.endpointsForEntity(entity.entityId).map((e) => e.id).toList(),
      ),
  ];

  CachingModel _planCaching(BackendEngineeringPlan backend) => CachingModel(
    employsCaching: backend.backgroundJobs.sourceStrategy == SyncStrategy.cacheFirst,
    sourceStrategy: backend.backgroundJobs.sourceStrategy,
  );
}
