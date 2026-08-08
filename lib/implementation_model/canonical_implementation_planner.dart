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
import '../software_cognition/software_reasoner.dart'
    show SoftwareRecommendation;
import '../synthesis/app_blueprint.dart'
    show DerivedOperation, BlueprintViewType;
import '../synthesis/application_reasoner.dart'
    show SemanticEntity, SemanticDerivedValue, SemanticView;
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

  /// Real, already-reasoned per-entity field metadata (Implementation
  /// Milestone R20) — `SemanticApp.entities`, the SAME single reasoning
  /// call's own output legacy's `CreationEngine` pipeline already reads
  /// (via `SynthesisPlanner.convertToBlueprint`) to populate
  /// `DataFieldSchema.defaultValue`/`referenceEntityId`/`allowedValues`/
  /// `hint`. Optional/additive: when omitted, `ImplementationField`'s new
  /// properties simply stay null/empty, matching pre-R20 behavior
  /// byte-for-byte. Deliberately NOT threaded through `FieldDecision`/
  /// `DatabaseColumn` (the intermediate architecture/backend stages) —
  /// this planner already receives `SemanticApp` transitively via the
  /// Kernel, so matching by (entityId, fieldId) directly here is the
  /// smaller, lower-blast-radius fix; `ArchitectureCandidate`/
  /// `BackendEngineeringPlan` and their many other consumers are
  /// unaffected.
  final List<SemanticEntity> semanticEntities;

  /// Real derived-value definitions (Implementation Milestone R20) — the
  /// SAME `SemanticApp.derivedValues` legacy's `CreationEngine` already
  /// turns into `dataQuery`+`calculation` behavior nodes. Optional/
  /// additive.
  final List<SemanticDerivedValue> derivedValues;

  /// Real, already-reasoned non-CRUD experience views (Implementation
  /// Milestone R21) — `SemanticApp.views`, the SAME single reasoning
  /// call's output legacy's `CreationEngine` already reads to build
  /// dashboard/calendar/settings/summary/empty screens. Optional/
  /// additive: when omitted, `CanonicalImplementationModel.views` stays
  /// empty, matching pre-R21 behavior byte-for-byte.
  final List<SemanticView> semanticViews;

  const CanonicalImplementationContext({
    required this.engineering,
    required this.backend,
    this.resolvedCapabilities = const [],
    this.corroboratingRecommendations = const [],
    this.semanticEntities = const [],
    this.derivedValues = const [],
    this.semanticViews = const [],
  });
}

/// `null` for `list`/`detail`/`form` — those screens are already produced
/// from `ImplementationEntity`/`ImplementationOperationKind`; mapping them
/// again here would duplicate, not enrich (Implementation Milestone R21).
ImplementationViewKind? _mapViewKind(BlueprintViewType type) => switch (type) {
  BlueprintViewType.dashboard => ImplementationViewKind.dashboard,
  BlueprintViewType.calendar => ImplementationViewKind.calendar,
  BlueprintViewType.settings => ImplementationViewKind.settings,
  BlueprintViewType.empty => ImplementationViewKind.empty,
  BlueprintViewType.summary => ImplementationViewKind.summary,
  BlueprintViewType.list ||
  BlueprintViewType.detail ||
  BlueprintViewType.form => null,
};

ImplementationDerivedOperation _mapDerivedOperation(DerivedOperation op) =>
    switch (op) {
      DerivedOperation.count => ImplementationDerivedOperation.count,
      DerivedOperation.sum => ImplementationDerivedOperation.sum,
      DerivedOperation.average => ImplementationDerivedOperation.average,
      DerivedOperation.minimum => ImplementationDerivedOperation.minimum,
      DerivedOperation.maximum => ImplementationDerivedOperation.maximum,
      DerivedOperation.consecutiveDateCount =>
        ImplementationDerivedOperation.consecutiveDateCount,
      DerivedOperation.percentage => ImplementationDerivedOperation.percentage,
      DerivedOperation.daysRemaining =>
        ImplementationDerivedOperation.daysRemaining,
      DerivedOperation.difference => ImplementationDerivedOperation.difference,
    };

ImplementationDataType _mapColumnType(DatabaseColumnType type) =>
    switch (type) {
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
        for (final c in context.resolvedCapabilities)
          CapabilityAdapterSpec(capabilityId: c.id, category: c.category.name),
      ],
      authentication: AuthenticationAdapterSpec(
        requiresCredentials: context.backend.authentication.requiresCredentials,
        providerIndependent: context.backend.authentication.providerIndependent,
      ),
      storageAdapters: [
        for (final r in context.backend.storage.requirements)
          StorageAdapterSpec(
            entityId: r.entityId,
            isFileStorage: r.kind.name == 'file',
          ),
      ],
      backgroundWorker: BackgroundWorkerSpec(
        requiresBackgroundSync:
            context.backend.backgroundJobs.requiresBackgroundSync,
      ),
      corroboratedPatterns: _planCorroboratedPatterns(context),
      derivedValues: _planDerivedValues(context),
      views: _planViews(context),
    );
  }

  /// Deterministic pass-through — never invents Layout Intent/
  /// Presentation Semantics/Grouping metadata beyond what `SemanticView`
  /// already names (Implementation Milestone R21).
  List<ImplementationView> _planViews(CanonicalImplementationContext context) =>
      [
        for (final v in context.semanticViews)
          if (_mapViewKind(v.viewType) case final kind?)
            ImplementationView(
              id: v.id,
              name: v.name,
              kind: kind,
              sourceEntityId: v.sourceEntityId,
            ),
      ];

  List<ImplementationEntity> _planEntities(
    CanonicalImplementationContext context,
  ) {
    final semanticFieldsByEntity = {
      for (final e in context.semanticEntities)
        e.id: {for (final f in e.fields) f.id: f},
    };
    // Real, existing entity ids only (Implementation Milestone R20) — a
    // `SemanticField.referenceEntityId` naming an entity that was never
    // declared (or was pruned before architecture planning finished) must
    // NOT be carried through: legacy's `ArchitectureToBlueprintConverter
    // ._droppedReferenceFields` already drops exactly these, confirmed by
    // a real test finding (a field referencing an undeclared entity had
    // `referenceEntityId: null` on the legacy side but leaked through
    // un-checked on a first version of this enrichment).
    final realEntityIds = context.backend.database.tables
        .map((t) => t.id)
        .toSet();
    return [
      for (final table in context.backend.database.tables)
        ImplementationEntity(
          id: table.id,
          name: table.name,
          fields: [
            for (final col in table.columns)
              () {
                // DatabaseColumn.id is '${table.id}.${fieldId}' (see
                // BackendEngineeringPlanner._planDatabase) — recover the
                // plain fieldId to match against SemanticField.id.
                final prefix = '${table.id}.';
                final fieldId = col.id.startsWith(prefix)
                    ? col.id.substring(prefix.length)
                    : col.id;
                final semanticField =
                    semanticFieldsByEntity[table.id]?[fieldId];
                final referenceEntityId = semanticField?.referenceEntityId;
                return ImplementationField(
                  id: col.id,
                  name: col.name,
                  type: _mapColumnType(col.type),
                  required: col.required,
                  defaultValue: semanticField?.defaultValue,
                  referenceEntityId:
                      (referenceEntityId != null &&
                          realEntityIds.contains(referenceEntityId))
                      ? referenceEntityId
                      : null,
                  allowedValues: semanticField?.allowedValues ?? const [],
                  hint: (semanticField?.description.isNotEmpty ?? false)
                      ? semanticField!.description
                      : null,
                );
              }(),
          ],
        ),
    ];
  }

  /// Deterministic pass-through — never invents calculation semantics
  /// beyond what `SemanticDerivedValue` already names.
  List<ImplementationDerivedValue> _planDerivedValues(
    CanonicalImplementationContext context,
  ) => [
    for (final dv in context.derivedValues)
      ImplementationDerivedValue(
        id: dv.id,
        name: dv.name,
        sourceEntityId: dv.sourceEntityId,
        operation: _mapDerivedOperation(dv.operation),
        fieldId: dv.fieldId,
        description: dv.description,
      ),
  ];

  List<ImplementationRepository> _planRepositories(
    CanonicalImplementationContext context,
  ) => [
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

  List<ImplementationController> _planControllers(
    CanonicalImplementationContext context,
  ) {
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
            ImplementationField(
              id: col.id,
              name: col.name,
              type: _mapColumnType(col.type),
              required: col.required,
            ),
        ],
      ),
  ];

  List<ImplementationValidator> _planValidators(
    CanonicalImplementationContext context,
  ) => [
    for (final table in context.backend.database.tables)
      ImplementationValidator(
        id: '${table.id}.validator',
        entityId: table.id,
        rules: [
          for (final col in table.columns)
            ImplementationValidationRule(
              fieldId: col.id,
              required: col.required,
              type: _mapColumnType(col.type),
            ),
        ],
      ),
  ];

  List<ImplementationService> _planServices(
    List<ImplementationRepository> repositories,
    List<ImplementationController> controllers,
  ) {
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

  List<ImplementationDependency> _planDependencies(
    CanonicalImplementationContext context,
  ) {
    final deps = <ImplementationDependency>[];
    for (final table in context.backend.database.tables) {
      for (final fk in table.foreignKeys) {
        deps.add(
          ImplementationDependency(
            fromId: table.id,
            toId: fk.referencesTableId,
            kind: DependencyKind.entityReference,
          ),
        );
      }
    }
    for (final c in context.resolvedCapabilities) {
      deps.add(
        ImplementationDependency(
          fromId: 'app',
          toId: c.id,
          kind: DependencyKind.capability,
        ),
      );
    }
    return deps;
  }

  List<StateContainerSpec> _planStateContainers(
    CanonicalImplementationContext context,
  ) => [
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

  NavigationHandlerSpec _planNavigation(
    CanonicalImplementationContext context,
  ) => NavigationHandlerSpec(
    routes: [
      for (final edge in context.engineering.navigation.modalEdges)
        NavigationRouteSpec(
          fromRouteId: edge.fromScreenId,
          toRouteId: edge.toScreenId,
          triggerId: edge.trigger,
          isOverlay: edge.isModal,
        ),
    ],
    deepLinkableRouteIds: context.engineering.navigation.deepLinkableScreenIds,
  );

  /// Deterministic pass-through — never re-derives acceptance, never
  /// fuzzy-matches recommendation names against this model's own
  /// entities/capabilities (Implementation Milestone R14; see the
  /// `corroboratingRecommendations` doc comment above for why).
  List<CorroboratedPattern> _planCorroboratedPatterns(
    CanonicalImplementationContext context,
  ) => [
    for (final r in context.corroboratingRecommendations)
      if (r.accepted)
        CorroboratedPattern(
          name: r.tracedTo.isNotEmpty
              ? r.tracedTo.first.sourceArtifact
              : r.description,
          description: r.description,
          confidenceScore: r.confidence.score,
          supportingSourceCount: r.tracedTo.length,
        ),
  ];
}
