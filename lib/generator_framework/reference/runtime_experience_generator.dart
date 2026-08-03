/// RuntimeExperienceGenerator — Implementation Milestone R13. The first
/// real, substantial [Generator] (R10) implementation: consumes a real
/// `CanonicalImplementationModel` (R9, via `UniversalBuildGraph.sourceModel`,
/// R11) and produces a real, valid `ExperiencePackage`
/// (`lib/creation/experience_package.dart`) — the SAME, unmodified,
/// canonical format the EXISTING `ExperienceRenderer`/`BehaviorInterpreter`/
/// `AnythingRuntime` already render and execute. Not Flutter/Dart source
/// code generation, not recompilation: this closes the Intent -> Build
/// Graph -> Generation Specification loop by emitting the one artifact
/// this codebase's own runtime already knows how to load.
///
/// Screen/behavior shape deliberately mirrors `CreationEngine`'s own
/// blueprint-driven `entityList`/`entityForm`/`entityDetail` conversion
/// (`lib/creation/creation_engine.dart`, Vision Milestone V3-era design
/// template) — the same trusted `RuntimeComponentRegistry` vocabulary, the
/// same `create_<entityId>`/`update_<entityId>`/`delete_<entityId>` event
/// naming `BehaviorInterpreter._resolveGenericEvent` already expects, the
/// same `<entityId>_list`/`_form`/`_edit`/`_detail` screen-id convention
/// `ExperienceHostScreen` already parses — never a second, parallel
/// interpretation of the package format. The real difference is the
/// SOURCE: `CanonicalImplementationModel`'s entities/controllers (language-
/// independent, R9) instead of `AppBlueprint`'s entities/views (Flutter-
/// package-specific, Vision Milestone V3).
///
/// `list`/`get`/`search` operations need no behavior node — the renderer's
/// `entityList`/`entityDetail` widgets already query `ExperienceDataRuntime`
/// live (confirmed by reading `experience_renderer.dart`); only
/// `create`/`update`/`delete` mutate data and need one, matching
/// `CreationEngine._buildBehaviorFromBlueprint`'s own scope exactly.
///
/// Honest, named limitations (Rule 5/7 — never fabricate): DTOs/Validators/
/// Services/StateContainers/NavigationHandler routes/AuthenticationAdapter/
/// StorageAdapter/BackgroundWorker have no real representation in
/// `ExperiencePackage`'s format and are reported via
/// `GenerationDiagnostic(category: skippedFeature)`, never silently
/// dropped or invented into fake package structure.
library;

import 'dart:convert';

import '../../creation/experience_package.dart';
import '../../creation/package_validator.dart';
import '../../generation_specification/generation_specification.dart';
import '../../generation_specification/path_template.dart';
import '../../implementation_model/canonical_implementation_model.dart';
import '../artifact.dart';
import '../generation_result.dart';
import '../generator.dart';

String _mapDataType(ImplementationDataType type) => switch (type) {
  ImplementationDataType.text => 'string',
  ImplementationDataType.integer => 'integer',
  ImplementationDataType.decimal => 'decimal',
  ImplementationDataType.boolean => 'boolean',
  ImplementationDataType.dateTime => 'datetime',
  ImplementationDataType.reference => 'reference',
};

class RuntimeExperienceGenerator implements Generator {
  final GenerationSpecification specification;

  const RuntimeExperienceGenerator({this.specification = defaultSpecification});

  /// The real default specification for this generator: unlike
  /// `SummaryManifestGenerator`'s per-entity `rules`, this generator emits
  /// ONE aggregate `ExperiencePackage` artifact over the whole graph — the
  /// exact case `GenerationSpecification.manifestPathTemplate`'s own doc
  /// comment describes ("not itself derived from one BuildGraphNode... a
  /// real, generator-produced aggregate over the whole graph").
  static const GenerationSpecification defaultSpecification = GenerationSpecification(
    manifestPathTemplate: PathTemplate('experience/{id}.json'),
  );

  @override
  GeneratorMetadata get metadata => const GeneratorMetadata(
    id: 'reference.runtime-experience',
    name: 'Runtime Experience Generator',
    version: GeneratorVersion(major: 1, minor: 0, patch: 0),
    capabilities: [GeneratorCapability.manifests, GeneratorCapability.configuration],
  );

  @override
  GenerationResult generate(GeneratorContext context) {
    final model = context.buildGraph.sourceModel;
    final diagnostics = <GenerationDiagnostic>[];

    if (model.entities.isEmpty) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.general,
          message: 'No entities in the supplied CanonicalImplementationModel — no Experience to generate.',
        ),
      );
      return GenerationResult(diagnostics: diagnostics);
    }

    final entitiesWithListScreen = <String>{};
    final interface = _buildInterface(model, entitiesWithListScreen, diagnostics);
    final behavior = _buildBehavior(model);
    final state = _buildState(entitiesWithListScreen.isNotEmpty, model.derivedValues);
    final data = _buildData(model);

    _reportUnrepresentedConcepts(model, diagnostics);

    final package = _assemblePackage(model, context.target, interface, behavior, state, data);

    final validation = ExperiencePackageValidator.validate(package);
    for (final error in validation.errors) {
      diagnostics.add(
        GenerationDiagnostic(
          severity: DiagnosticSeverity.error,
          category: DiagnosticCategory.general,
          message: 'Generated package failed validation: $error',
        ),
      );
    }
    for (final warning in validation.warnings) {
      diagnostics.add(
        GenerationDiagnostic(severity: DiagnosticSeverity.warning, category: DiagnosticCategory.general, message: warning),
      );
    }

    final artifact = Artifact(
      id: 'experience-package',
      path: specification.manifestPathTemplate.resolve(id: context.target.id, label: context.target.name),
      kind: ArtifactKind.manifest,
      content: jsonEncode(package.toJson()),
    );

    return GenerationResult(
      artifactGroups: [ArtifactGroup(id: 'experience', artifacts: [artifact])],
      diagnostics: diagnostics,
    );
  }

  // ── Interface ────────────────────────────────────────────────────────

  InterfaceDefinition _buildInterface(
    CanonicalImplementationModel model,
    Set<String> entitiesWithListScreen,
    List<GenerationDiagnostic> diagnostics,
  ) {
    final screens = <InterfaceScreen>[];

    for (final entity in model.entities) {
      final controller = model.controllers.where((c) => c.entityId == entity.id).firstOrNull;
      final kinds = controller?.operations.map((o) => o.kind).toSet() ?? <ImplementationOperationKind>{};

      if (kinds.isEmpty) {
        diagnostics.add(
          GenerationDiagnostic(
            severity: DiagnosticSeverity.info,
            category: DiagnosticCategory.skippedFeature,
            message: 'Entity ${entity.id} has no controller operations — no interface screens generated.',
            relatedId: entity.id,
          ),
        );
        continue;
      }

      final hasList = kinds.contains(ImplementationOperationKind.list) || kinds.contains(ImplementationOperationKind.search);
      final hasCreate = kinds.contains(ImplementationOperationKind.create);
      final hasUpdate = kinds.contains(ImplementationOperationKind.update);
      final hasDetail = kinds.contains(ImplementationOperationKind.get) || kinds.contains(ImplementationOperationKind.delete);

      if (hasList) {
        final listNodes = <InterfaceNode>[];
        if (kinds.contains(ImplementationOperationKind.search)) {
          listNodes.add(
            InterfaceNode(
              type: 'searchField',
              id: '${entity.id}_search',
              properties: {'hint': 'Search ${entity.name}...', 'entityId': entity.id},
            ),
          );
        }
        listNodes.add(
          InterfaceNode(
            type: 'entityList',
            id: '${entity.id}_list_view',
            properties: {
              'entityId': entity.id,
              'titleField': _displayField(entity),
              if (_secondaryField(entity) != null) 'subtitleField': _secondaryField(entity),
            },
          ),
        );
        if (hasCreate) {
          listNodes.add(
            InterfaceNode(
              type: 'button',
              id: '${entity.id}_add_button',
              properties: {'label': 'Add ${entity.name}', 'primary': true},
              actionBinding: ActionBinding(actionId: 'create_${entity.id}'),
            ),
          );
        }
        screens.add(InterfaceScreen(id: '${entity.id}_list', title: entity.name, appBarTitle: entity.name, children: listNodes));
        entitiesWithListScreen.add(entity.id);
      }

      if (hasCreate) {
        screens.add(
          InterfaceScreen(
            id: '${entity.id}_form',
            title: 'Add ${entity.name}',
            appBarTitle: 'Add ${entity.name}',
            children: [
              InterfaceNode(
                type: 'entityForm',
                id: '${entity.id}_form_node',
                properties: {'entityId': entity.id, 'mode': 'create', 'fields': _fieldDefs(entity)},
              ),
            ],
          ),
        );
      }

      if (hasUpdate) {
        screens.add(
          InterfaceScreen(
            id: '${entity.id}_edit',
            title: 'Edit ${entity.name}',
            appBarTitle: 'Edit ${entity.name}',
            children: [
              InterfaceNode(
                type: 'entityForm',
                id: '${entity.id}_edit_node',
                properties: {'entityId': entity.id, 'mode': 'edit', 'fields': _fieldDefs(entity)},
              ),
            ],
          ),
        );
      }

      if (hasDetail) {
        screens.add(
          InterfaceScreen(
            id: '${entity.id}_detail',
            title: entity.name,
            appBarTitle: entity.name,
            children: [
              InterfaceNode(
                type: 'entityDetail',
                id: '${entity.id}_detail_node',
                properties: {'entityId': entity.id, 'titleField': _displayField(entity)},
              ),
            ],
          ),
        );
      }
    }

    if (screens.isEmpty) {
      screens.add(
        const InterfaceScreen(
          id: 'main',
          title: 'Experience',
          children: [InterfaceNode(type: 'text', id: 'empty_text', properties: {'content': 'No entities defined'})],
        ),
      );
    }

    final navigation = entitiesWithListScreen.length > 1
        ? NavigationDefinition(
            type: 'bottomNavigation',
            items: [
              for (final entity in model.entities.where((e) => entitiesWithListScreen.contains(e.id)).take(5))
                NavigationItem(label: entity.name, icon: 'list', screenId: '${entity.id}_list'),
            ],
          )
        : null;

    return InterfaceDefinition(screens: screens, navigation: navigation);
  }

  String _displayField(ImplementationEntity entity) {
    for (final field in entity.fields) {
      if (field.id == 'name' || field.id == 'title' || field.id == 'label') return field.id;
    }
    return entity.fields.isNotEmpty ? entity.fields.first.id : 'id';
  }

  String? _secondaryField(ImplementationEntity entity) {
    final display = _displayField(entity);
    for (final field in entity.fields) {
      if (field.id != display) return field.id;
    }
    return null;
  }

  List<Map<String, dynamic>> _fieldDefs(ImplementationEntity entity) => [
    for (final field in entity.fields)
      {
        'id': field.id,
        'name': field.name,
        'type': _mapDataType(field.type),
        'required': field.required,
        // Real field metadata (Implementation Milestone R20) — only
        // included when present, mirroring CreationEngine's own
        // conditional (never a fabricated empty value).
        if (field.defaultValue != null) 'defaultValue': field.defaultValue,
        if (field.referenceEntityId != null) 'referenceEntityId': field.referenceEntityId,
        if (field.allowedValues.isNotEmpty) 'allowedValues': field.allowedValues,
        if (field.hint != null) 'hint': field.hint,
      },
  ];

  // ── Behavior ─────────────────────────────────────────────────────────

  BehaviorGraph _buildBehavior(CanonicalImplementationModel model) {
    final nodes = <BehaviorNode>[];
    final edges = <BehaviorEdge>[];

    for (final controller in model.controllers) {
      for (final op in controller.operations) {
        final String eventId;
        final String mutationOp;
        switch (op.kind) {
          case ImplementationOperationKind.create:
            eventId = 'create_${controller.entityId}';
            mutationOp = 'create';
          case ImplementationOperationKind.update:
            eventId = 'update_${controller.entityId}';
            mutationOp = 'update';
          case ImplementationOperationKind.delete:
            eventId = 'delete_${controller.entityId}';
            mutationOp = 'delete';
          case ImplementationOperationKind.list:
          case ImplementationOperationKind.get:
          case ImplementationOperationKind.search:
            // Handled by live queries inside the renderer's entityList/
            // entityDetail widgets — no behavior node needed, matching
            // CreationEngine's own blueprint-driven behavior scope.
            continue;
        }

        final eventNodeId = '${eventId}_event';
        nodes.add(BehaviorNode(id: eventNodeId, type: 'event', config: {'eventId': eventId}));
        final mutateNodeId = '${eventId}_data';
        nodes.add(
          BehaviorNode(id: mutateNodeId, type: 'dataMutation', config: {'operation': mutationOp, 'entity': controller.entityId}),
        );
        edges.add(BehaviorEdge(from: eventNodeId, to: mutateNodeId));
      }
    }

    // Derived-value behavior nodes (Implementation Milestone R20) — the
    // SAME dataQuery+calculation node pair/naming/config shape legacy's
    // `CreationEngine._buildBehaviorFromBlueprint` already emits for
    // `blueprint.derivedValues`.
    for (final dv in model.derivedValues) {
      final queryNodeId = 'derived_${dv.id}_query';
      final queryStateId = '${dv.id}_raw_data';
      nodes.add(
        BehaviorNode(id: queryNodeId, type: 'dataQuery', config: {'entity': dv.sourceEntityId, 'operation': 'query', 'resultStateId': queryStateId}),
      );

      final calcNodeId = 'derived_${dv.id}_calc';
      nodes.add(
        BehaviorNode(
          id: calcNodeId,
          type: 'calculation',
          config: {'operation': dv.operation.name, 'sourceStateId': queryStateId, 'fieldId': dv.fieldId ?? '', 'targetStateId': dv.id},
        ),
      );
      edges.add(BehaviorEdge(from: queryNodeId, to: calcNodeId));
    }

    return BehaviorGraph(nodes: nodes, edges: edges);
  }

  // ── State ────────────────────────────────────────────────────────────

  StateSchema _buildState(bool hasAnyListScreen, List<ImplementationDerivedValue> derivedValues) => StateSchema(
    variables: [
      if (hasAnyListScreen) const StateVariable(id: 'searchTerm', type: 'string', defaultValue: '', persistence: 'session'),
      // Derived-value state variables (Implementation Milestone R20) —
      // same id/type/defaultValue shape as
      // CreationEngine._buildStateFromBlueprint.
      for (final dv in derivedValues) ...[
        StateVariable(id: dv.id, type: 'string', defaultValue: '0', persistence: 'session'),
        StateVariable(id: '${dv.id}_raw_data', type: 'list', defaultValue: const <dynamic>[], persistence: 'session'),
      ],
    ],
  );

  // ── Data ─────────────────────────────────────────────────────────────

  DataSchema _buildData(CanonicalImplementationModel model) => DataSchema(
    entities: [
      for (final entity in model.entities)
        DataEntitySchema(
          id: entity.id,
          name: entity.name,
          fields: [
            for (final field in entity.fields)
              DataFieldSchema(
                id: field.id,
                name: field.name,
                type: _mapDataType(field.type),
                required: field.required,
                // Real field metadata (Implementation Milestone R20) —
                // the same properties legacy's DataFieldSchema already
                // carries (minLength/maxLength/minimum/maximum excluded:
                // legacy itself never populates them either).
                defaultValue: field.defaultValue,
                referenceEntityId: field.referenceEntityId,
                allowedValues: field.allowedValues,
                hint: field.hint,
              ),
          ],
        ),
    ],
  );

  // ── Honest diagnostics for concepts ExperiencePackage cannot represent ──

  void _reportUnrepresentedConcepts(CanonicalImplementationModel model, List<GenerationDiagnostic> diagnostics) {
    if (model.dtos.isNotEmpty || model.validators.isNotEmpty || model.services.isNotEmpty) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.skippedFeature,
          message: 'DTO/Validator/Service groupings are not represented in the generated ExperiencePackage — the runtime '
              'enforces field requiredness directly from entity/form field definitions, with no separate layer in this format.',
        ),
      );
    }
    if (model.stateContainers.isNotEmpty) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.skippedFeature,
          message: 'StateContainer transitions are not represented — ExperiencePackage.state models simple session/'
              'persistent variables, not a generic state-machine concept.',
        ),
      );
    }
    if (model.navigation.routes.isNotEmpty) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.skippedFeature,
          message: 'NavigationHandlerSpec routes are not represented — the generated NavigationDefinition is derived '
              'directly from entity list screens, not from modal/deep-link route specs.',
        ),
      );
    }
    if (model.authentication.requiresCredentials) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.skippedFeature,
          message: 'AuthenticationAdapter requirement noted but not modeled — no authentication UI concept exists in '
              'ExperiencePackage.',
        ),
      );
    }
    if (model.backgroundWorker.requiresBackgroundSync) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.skippedFeature,
          message: 'BackgroundWorker requirement noted but not modeled — no background-job concept exists in '
              'ExperiencePackage.',
        ),
      );
    }
  }

  // ── Assembly ─────────────────────────────────────────────────────────

  ExperiencePackage _assemblePackage(
    CanonicalImplementationModel model,
    GeneratorTarget target,
    InterfaceDefinition interface,
    BehaviorGraph behavior,
    StateSchema state,
    DataSchema data,
  ) {
    final manifest = ExperienceManifest(
      experienceId: target.id,
      name: target.name,
      description: 'Generated Experience for ${target.name}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      requiredCapabilities: [for (final c in model.capabilityAdapters) c.capabilityId],
      networkMode: NetworkMode.none,
      storageMode: model.entities.isNotEmpty ? StorageMode.localDatabase : StorageMode.none,
      category: 'generated',
    );

    // specVersion/planVersion have no meaningful upstream equivalent in the
    // Generator Framework pipeline (GeneratorContext carries no spec/plan
    // version of its own) — set to 1 honestly, never fabricated from
    // invented upstream data.
    final provenance = PackageProvenance(
      creationEngineVersion: 'reference.runtime-experience-1.0.0',
      specVersion: 1,
      planVersion: 1,
    );

    final draft = ExperiencePackage(
      manifest: manifest,
      interface: interface,
      behavior: behavior,
      state: state,
      data: data,
      capabilityDeclarations: [
        for (final c in model.capabilityAdapters) CapabilityDeclaration(capabilityId: c.capabilityId),
      ],
      provenance: provenance,
      integrity: PackageIntegrity(contentHash: '', computedAt: DateTime.now()),
    );

    final hash = ExperiencePackage.computeIntegrityHash(draft);
    return ExperiencePackage(
      packageVersion: draft.packageVersion,
      manifest: draft.manifest,
      interface: draft.interface,
      behavior: draft.behavior,
      state: draft.state,
      data: draft.data,
      services: draft.services,
      networkDeclarations: draft.networkDeclarations,
      capabilityDeclarations: draft.capabilityDeclarations,
      permissionDeclarations: draft.permissionDeclarations,
      protection: draft.protection,
      provenance: draft.provenance,
      integrity: PackageIntegrity(contentHash: hash, computedAt: DateTime.now()),
    );
  }
}
