/// Canonical Implementation Planner — Implementation Milestone R9. Real,
/// deterministic derivation from the SAME already-computed
/// `EngineeringCandidate` (R3, frontend) + `BackendEngineeringPlan` (R8,
/// backend) + resolved `CapabilityRegistry` entries — zero new AI call,
/// zero new upstream dependency. Mirrors `BackendEngineeringPlanner`'s own
/// derivation-function-per-concern shape (R8).
library;

import '../application_engineering/engineering_candidate.dart';
import '../backend_engineering/api_specification.dart';
import '../backend_engineering/backend_engineering_plan.dart';
import '../backend_engineering/database_schema.dart';
import '../capabilities/registry/capability_descriptor.dart';
import '../software_cognition/software_reasoner.dart' show SoftwareRecommendation;
import 'canonical_implementation_model.dart';

class CanonicalImplementationContext {
  final EngineeringCandidate engineering;
  final BackendEngineeringPlan backend;
  final List<CapabilityDescriptor> resolvedCapabilities;

  /// Real, multi-source-corroborated Software Cognition recommendations
  /// (Implementation Milestone R14) — a caller passes ONLY recommendations
  /// it already accepted (`SoftwareRecommendation.accepted`); the planner
  /// never re-derives acceptance, it only carries evidence forward.
  /// Deliberately not yet populated by `AnythingKernel.processIntent`
  /// (see `docs/architecture/SOFTWARE_COGNITION_ENGINE.md`, "R14:
  /// Canonical Implementation Model enrichment") — the hook is real and
  /// tested end-to-end at this planner boundary.
  final List<SoftwareRecommendation> corroboratingRecommendations;

  const CanonicalImplementationContext({
    required this.engineering,
    required this.backend,
    this.resolvedCapabilities = const [],
    this.corroboratingRecommendations = const [],
  });
}

ImplementationDataType _mapColumnType(DatabaseColumnType type) => switch (type) {
  DatabaseColumnType.text => ImplementationDataType.text,
  DatabaseColumnType.integer => ImplementationDataType.integer,
  DatabaseColumnType.decimal => ImplementationDataType.decimal,
  DatabaseColumnType.boolean => ImplementationDataType.boolean,
  DatabaseColumnType.dateTime => ImplementationDataType.dateTime,
  DatabaseColumnType.reference => ImplementationDataType.reference,
};

ImplementationOperationKind _mapApiOperation(ApiOperation op) => switch (op) {
  ApiOperation.list => ImplementationOperationKind.list,
  ApiOperation.get => ImplementationOperationKind.get,
  ApiOperation.create => ImplementationOperationKind.create,
  ApiOperation.update => ImplementationOperationKind.update,
  ApiOperation.delete => ImplementationOperationKind.delete,
  ApiOperation.search => ImplementationOperationKind.search,
};

class CanonicalImplementationPlanner {
  const CanonicalImplementationPlanner();

  CanonicalImplementationModel plan(CanonicalImplementationContext context) {
    final entities = _planEntities(context);
    final repositories = _planRepositories(context);
    final controllers = _planControllers(context);
    final dtos = _planDtos(context);
    final validators = _planValidators(context);
    final services = _planServices(repositories, controllers);
    final dependencies = _planDependencies(context);

    return CanonicalImplementationModel(
      entities: entities,
      repositories: repositories,
      controllers: controllers,
      dtos: dtos,
      validators: validators,
      services: services,
      dependencies: dependencies,
      stateContainers: _planStateContainers(context),
      navigation: _planNavigation(context),
      capabilityAdapters: [
        for (final c in context.resolvedCapabilities) CapabilityAdapterSpec(capabilityId: c.id, category: c.category.name),
      ],
      authentication: AuthenticationAdapterSpec(
        requiresCredentials: context.backend.authentication.requiresCredentials,
        providerIndependent: context.backend.authentication.providerIndependent,
      ),
      storageAdapters: [
        for (final r in context.backend.storage.requirements)
          StorageAdapterSpec(entityId: r.entityId, isFileStorage: r.kind.name == 'file'),
      ],
      backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: context.backend.backgroundJobs.requiresBackgroundSync),
      corroboratedPatterns: _planCorroboratedPatterns(context),
    );
  }

  List<ImplementationEntity> _planEntities(CanonicalImplementationContext context) => [
    for (final table in context.backend.database.tables)
      ImplementationEntity(
        id: table.id,
        name: table.name,
        fields: [
          for (final col in table.columns)
            ImplementationField(id: col.id, name: col.name, type: _mapColumnType(col.type), required: col.required),
        ],
      ),
  ];

  List<ImplementationRepository> _planRepositories(CanonicalImplementationContext context) => [
    for (final table in context.backend.database.tables)
      ImplementationRepository(
        id: '${table.id}.repository',
        entityId: table.id,
        supportedOperations: context.backend.api
            .endpointsForEntity(table.id)
            .map((e) => _mapApiOperation(e.operation))
            .toSet()
            .toList(),
      ),
  ];

  List<ImplementationController> _planControllers(CanonicalImplementationContext context) {
    final byEntity = <String, List<ApiEndpoint>>{};
    for (final endpoint in context.backend.api.endpoints) {
      byEntity.putIfAbsent(endpoint.entityId, () => []).add(endpoint);
    }
    return [
      for (final entry in byEntity.entries)
        ImplementationController(
          id: '${entry.key}.controller',
          entityId: entry.key,
          operations: [
            for (final e in entry.value)
              ImplementationOperation(
                id: e.id,
                kind: _mapApiOperation(e.operation),
                requestFieldNames: e.requestFields.map((f) => f.name).toList(),
              ),
          ],
        ),
    ];
  }

  List<ImplementationDto> _planDtos(CanonicalImplementationContext context) => [
    for (final table in context.backend.database.tables)
      ImplementationDto(
        id: '${table.id}.dto',
        entityId: table.id,
        fields: [
          for (final col in table.columns)
            ImplementationField(id: col.id, name: col.name, type: _mapColumnType(col.type), required: col.required),
        ],
      ),
  ];

  List<ImplementationValidator> _planValidators(CanonicalImplementationContext context) => [
    for (final table in context.backend.database.tables)
      ImplementationValidator(
        id: '${table.id}.validator',
        entityId: table.id,
        rules: [
          for (final col in table.columns)
            ImplementationValidationRule(fieldId: col.id, required: col.required, type: _mapColumnType(col.type)),
        ],
      ),
  ];

  List<ImplementationService> _planServices(List<ImplementationRepository> repositories, List<ImplementationController> controllers) {
    final controllerByEntity = {for (final c in controllers) c.entityId: c};
    return [
      for (final repo in repositories)
        if (controllerByEntity[repo.entityId] case final controller?)
          ImplementationService(
            id: '${repo.entityId}.service',
            entityId: repo.entityId,
            repositoryId: repo.id,
            controllerId: controller.id,
          ),
    ];
  }

  List<ImplementationDependency> _planDependencies(CanonicalImplementationContext context) {
    final deps = <ImplementationDependency>[];
    for (final table in context.backend.database.tables) {
      for (final fk in table.foreignKeys) {
        deps.add(ImplementationDependency(fromId: table.id, toId: fk.referencesTableId, kind: DependencyKind.entityReference));
      }
    }
    for (final c in context.resolvedCapabilities) {
      deps.add(ImplementationDependency(fromId: 'app', toId: c.id, kind: DependencyKind.capability));
    }
    return deps;
  }

  List<StateContainerSpec> _planStateContainers(CanonicalImplementationContext context) => [
    for (final behavior in context.engineering.behaviors)
      StateContainerSpec(
        entityId: behavior.stateMachine.entityId,
        initial: behavior.stateMachine.initial,
        transitions: [
          for (final t in behavior.stateMachine.transitions)
            StateTransitionSpec(triggerId: t.eventId, from: t.from, to: t.to),
        ],
      ),
  ];

  NavigationHandlerSpec _planNavigation(CanonicalImplementationContext context) => NavigationHandlerSpec(
    routes: [
      for (final edge in context.engineering.navigation.modalEdges)
        NavigationRouteSpec(fromRouteId: edge.fromScreenId, toRouteId: edge.toScreenId, triggerId: edge.trigger, isOverlay: edge.isModal),
    ],
    deepLinkableRouteIds: context.engineering.navigation.deepLinkableScreenIds,
  );

  /// Deterministic pass-through — never re-derives acceptance, never
  /// fuzzy-matches recommendation names against this model's own
  /// entities/capabilities (Implementation Milestone R14; see the
  /// `corroboratingRecommendations` doc comment above for why).
  List<CorroboratedPattern> _planCorroboratedPatterns(CanonicalImplementationContext context) => [
    for (final r in context.corroboratingRecommendations)
      if (r.accepted)
        CorroboratedPattern(
          name: r.tracedTo.isNotEmpty ? r.tracedTo.first.sourceArtifact : r.description,
          description: r.description,
          confidenceScore: r.confidence.score,
          supportingSourceCount: r.tracedTo.length,
        ),
  ];
}
