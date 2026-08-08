/// Serialization for `SemanticSolutionArchitecture` (Implementation
/// Milestone R17) — reuses `ArchitectureCandidate`/`BackendEngineeringPlan`'s
/// ALREADY-REAL `.toJson()`/`.fromJson()` (Vision Milestone V2,
/// Implementation Milestone R8) for the two composed fields, never a
/// second, independent serialization of their data.
library;

import '../backend_engineering/backend_engineering_serialization.dart';
import '../software_architect/architecture_candidate_serialization.dart';
import '../software_architect/architecture_types.dart' show SyncStrategy;
import 'solution_architecture.dart';

extension SolutionComponentJson on SolutionComponent {
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'responsibility': responsibility,
    'hasBackendPresence': hasBackendPresence,
    'storageKind': storageKind,
    'dependsOnComponentIds': dependsOnComponentIds,
    'contractIds': contractIds,
  };
}

SolutionComponent solutionComponentFromJson(Map<String, dynamic> json) =>
    SolutionComponent(
      id: json['id'] as String,
      name: json['name'] as String,
      responsibility: json['responsibility'] as String,
      hasBackendPresence: json['hasBackendPresence'] as bool,
      storageKind: json['storageKind'] as String,
      dependsOnComponentIds: (json['dependsOnComponentIds'] as List)
          .cast<String>(),
      contractIds: (json['contractIds'] as List).cast<String>(),
    );

extension SemanticSolutionArchitectureJson on SemanticSolutionArchitecture {
  Map<String, dynamic> toJson() => {
    'frontend': frontend.toJson(),
    'backend': backend.toJson(),
    'components': components.map((c) => c.toJson()).toList(),
    'caching': {
      'employsCaching': caching.employsCaching,
      'sourceStrategy': caching.sourceStrategy.name,
    },
    'unmodeledConcepts': unmodeledConcepts
        .map((u) => {'name': u.name, 'reason': u.reason})
        .toList(),
  };
}

SemanticSolutionArchitecture semanticSolutionArchitectureFromJson(
  Map<String, dynamic> json,
) {
  final cachingJson = json['caching'] as Map<String, dynamic>;
  return SemanticSolutionArchitecture(
    frontend: ArchitectureCandidateJson.fromJson(
      json['frontend'] as Map<String, dynamic>,
    ),
    backend: backendEngineeringPlanFromJson(
      json['backend'] as Map<String, dynamic>,
    ),
    components: (json['components'] as List)
        .map((c) => solutionComponentFromJson(c as Map<String, dynamic>))
        .toList(),
    caching: CachingModel(
      employsCaching: cachingJson['employsCaching'] as bool,
      sourceStrategy: SyncStrategy.values.byName(
        cachingJson['sourceStrategy'] as String,
      ),
    ),
    unmodeledConcepts: (json['unmodeledConcepts'] as List)
        .map(
          (u) => UnmodeledConcept(
            name: (u as Map<String, dynamic>)['name'] as String,
            reason: u['reason'] as String,
          ),
        )
        .toList(),
  );
}
