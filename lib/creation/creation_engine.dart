/// Creation Engine — converts specifications into Experience Packages.
///
/// Takes CreationContext and produces ExperiencePackage.
/// Does NOT execute arbitrary code.
library;

import '../application_engineering/engineering_to_blueprint.dart';
import '../kernel/specification/experience_spec.dart';
import '../synthesis/app_blueprint.dart';
import 'creation_context.dart';
import 'experience_package.dart';

/// Result of creation.
sealed class CreationResult {
  final String message;
  final DateTime timestamp;

  const CreationResult({required this.message, required this.timestamp});
}

/// Creation succeeded.
class CreationReady extends CreationResult {
  final ExperiencePackage package;

  const CreationReady({
    required this.package,
    required super.message,
    required super.timestamp,
  });
}

/// Creation needs clarification.
class CreationNeedsClarification extends CreationResult {
  final String question;

  const CreationNeedsClarification({
    required this.question,
    required super.message,
    required super.timestamp,
  });
}

/// Creation needs a credential.
class CreationNeedsCredential extends CreationResult {
  final String credentialName;

  const CreationNeedsCredential({
    required this.credentialName,
    required super.message,
    required super.timestamp,
  });
}

/// Creation failed.
class CreationFailed extends CreationResult {
  final String error;

  const CreationFailed({
    required this.error,
    required super.message,
    required super.timestamp,
  });
}

/// Unsupported requirements detected.
class CreationUnsupported extends CreationResult {
  final List<String> unsupportedRequirements;

  const CreationUnsupported({
    required this.unsupportedRequirements,
    required super.message,
    required super.timestamp,
  });
}

/// The Creation Engine.
class CreationEngine {
  CreationEngine();

  /// Create an ExperiencePackage from a CreationContext.
  Future<CreationResult> create(CreationContext context) async {
    try {
      final spec = context.specification;
      final blueprint = context.blueprint;

      // Check for unsupported requirements
      final unsupported = _checkUnsupported(spec, context);
      if (unsupported.isNotEmpty) {
        return CreationUnsupported(
          unsupportedRequirements: unsupported,
          message: 'Some requirements cannot be met yet',
          timestamp: DateTime.now(),
        );
      }

      // Build interface — use blueprint when available for richer UI
      final interface = blueprint != null
          ? _buildInterfaceFromBlueprint(blueprint)
          : _buildInterface(spec);

      // Build behavior — use blueprint when available for richer behavior
      var behavior = blueprint != null
          ? _buildBehaviorFromBlueprint(blueprint)
          : _buildBehavior(spec);

      // Build state — use blueprint when available for richer state
      var state = blueprint != null
          ? _buildStateFromBlueprint(blueprint)
          : _buildState(spec);

      // Vision Milestone V3: if the Kernel produced an EngineeringPlan
      // (approved architecture-machine-checked engineering), augment the
      // behavior/state CreationEngine already built with real generic
      // status-tracking state transitions. No-op when absent — every
      // caller that predates this milestone is unaffected.
      if (blueprint != null && context.engineeringPlan != null) {
        final augmented = const EngineeringToBlueprintAugmenter().augment(
          blueprint: blueprint,
          behavior: behavior,
          state: state,
          plan: context.engineeringPlan,
        );
        behavior = augmented.behavior;
        state = augmented.state;
      }

      // Build data schema — use blueprint entities with fields
      DataSchema? data;
      if (spec.storageRequirements.requiresDatabase) {
        data = blueprint != null
            ? _buildDataSchemaFromBlueprint(blueprint)
            : _buildDataSchema(spec);
      }

      // Build services
      final services = _buildServices(spec);

      // Build network declarations
      final network = _buildNetwork(spec);

      // Build capability declarations
      final capabilities = _buildCapabilities(spec);

      // Build permission declarations
      final permissions = _buildPermissions(spec);

      // Build manifest
      final manifest = ExperienceManifest(
        experienceId: spec.id,
        name: spec.name,
        description: spec.description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        networkMode: _mapNetworkMode(spec.networkRequirements.networkNeed),
        storageMode: _mapStorageMode(spec.storageRequirements.storageType),
        requiredCapabilities: capabilities
            .where((c) => c.isRequired)
            .map((c) => c.capabilityId)
            .toList(),
        category: blueprint != null
            ? _deriveStructuralCategory(blueprint)
            : spec.category.name,
        tags: blueprint != null ? blueprint.tags : const [],
      );

      // Build provenance
      final provenance = PackageProvenance(
        resourcesConsulted:
            context.knowledgeBundle?.resources
                .map((r) => r.sourceUri)
                .toList() ??
            [],
        creationEngineVersion: '1.0.0',
        specVersion: spec.specVersion,
        planVersion: context.plan.planVersion,
      );

      // Build package
      final package = ExperiencePackage(
        manifest: manifest,
        interface: interface,
        behavior: behavior,
        state: state,
        data: data,
        services: services,
        networkDeclarations: network,
        capabilityDeclarations: capabilities,
        permissionDeclarations: permissions,
        provenance: provenance,
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime.now(),
        ),
      );

      // Compute integrity
      final integrityHash = ExperiencePackage.computeIntegrityHash(package);
      final finalPackage = ExperiencePackage(
        packageVersion: package.packageVersion,
        manifest: package.manifest,
        interface: package.interface,
        behavior: package.behavior,
        state: package.state,
        data: package.data,
        services: package.services,
        networkDeclarations: package.networkDeclarations,
        capabilityDeclarations: package.capabilityDeclarations,
        permissionDeclarations: package.permissionDeclarations,
        protection: package.protection,
        provenance: package.provenance,
        integrity: PackageIntegrity(
          contentHash: integrityHash,
          computedAt: DateTime.now(),
        ),
      );

      return CreationReady(
        package: finalPackage,
        message: 'Experience package ready',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return CreationFailed(
        error: e.toString(),
        message: 'Creation failed',
        timestamp: DateTime.now(),
      );
    }
  }

  List<String> _checkUnsupported(ExperienceSpec spec, CreationContext context) {
    final unsupported = <String>[];

    // Check backend requirements
    if (spec.backendClassification == BackendClassification.externalApi) {
      if (context.isOffline) {
        unsupported.add('External API required but device is offline');
      }
    }

    // Remote service infrastructure not yet available in Stage 6

    return unsupported;
  }

  InterfaceDefinition _buildInterface(ExperienceSpec spec) {
    final screens = <InterfaceScreen>[];

    // Build screens based on UI requirements
    for (final view in spec.uiRequirements.primaryViews) {
      screens.add(
        InterfaceScreen(
          id: view.replaceAll(' ', '_').toLowerCase(),
          title: view,
          children: _buildDefaultChildren(spec, view),
        ),
      );
    }

    // Ensure at least one screen
    if (screens.isEmpty) {
      screens.add(
        InterfaceScreen(
          id: 'main',
          title: spec.name,
          children: _buildDefaultChildren(spec, 'main'),
        ),
      );
    }

    return InterfaceDefinition(screens: screens);
  }

  List<InterfaceNode> _buildDefaultChildren(ExperienceSpec spec, String view) {
    final children = <InterfaceNode>[];

    // Add display elements
    for (final element in spec.uiRequirements.displayElements) {
      children.add(
        InterfaceNode(
          type: 'text',
          id: element.replaceAll(' ', '_').toLowerCase(),
          properties: {'content': element},
        ),
      );
    }

    // Add input elements
    for (final element in spec.uiRequirements.inputElements) {
      children.add(
        InterfaceNode(
          type: 'input',
          id: element.replaceAll(' ', '_').toLowerCase(),
          properties: {'hint': element},
        ),
      );
    }

    return children;
  }

  BehaviorGraph _buildBehavior(ExperienceSpec spec) {
    final nodes = <BehaviorNode>[];
    final edges = <BehaviorEdge>[];

    // Create nodes for each functional requirement
    for (final req in spec.functionalRequirements) {
      nodes.add(
        BehaviorNode(
          id: req.id,
          type: 'event',
          config: {'description': req.description},
        ),
      );
    }

    // Create sequential edges
    for (int i = 0; i < spec.functionalRequirements.length - 1; i++) {
      edges.add(
        BehaviorEdge(
          from: spec.functionalRequirements[i].id,
          to: spec.functionalRequirements[i + 1].id,
        ),
      );
    }

    return BehaviorGraph(nodes: nodes, edges: edges);
  }

  StateSchema _buildState(ExperienceSpec spec) {
    final variables = <StateVariable>[];

    if (spec.stateRequirements.requiresEphemeralState) {
      variables.add(
        const StateVariable(
          id: 'ui_state',
          type: 'map',
          persistence: 'session',
        ),
      );
    }

    if (spec.stateRequirements.requiresPersistentState) {
      variables.add(
        const StateVariable(
          id: 'app_state',
          type: 'map',
          persistence: 'persistent',
        ),
      );
    }

    return StateSchema(variables: variables);
  }

  DataSchema? _buildDataSchema(ExperienceSpec spec) {
    if (!spec.storageRequirements.requiresDatabase) return null;

    return const DataSchema(entities: [], schemaVersion: 1);
  }

  List<ServiceDefinition> _buildServices(ExperienceSpec spec) {
    return spec.serviceRequirements
        .map((req) => ServiceDefinition(id: req.id, type: req.type.name))
        .toList();
  }

  List<NetworkDeclaration> _buildNetwork(ExperienceSpec spec) {
    if (spec.networkRequirements.networkNeed == NetworkNeed.none) {
      return const [];
    }

    return [
      NetworkDeclaration(
        purpose: spec.networkRequirements.description ?? 'Network access',
        requiresCredential: false,
      ),
    ];
  }

  List<CapabilityDeclaration> _buildCapabilities(ExperienceSpec spec) {
    return spec.requiredCapabilities
        .map(
          (cap) => CapabilityDeclaration(
            capabilityId: cap.capabilityId,
            isRequired: cap.isRequired,
          ),
        )
        .toList();
  }

  List<PermissionDeclaration> _buildPermissions(ExperienceSpec spec) {
    return spec.permissionRequirements
        .map(
          (perm) => PermissionDeclaration(
            permission: perm.permission,
            reason: perm.reason,
          ),
        )
        .toList();
  }

  NetworkMode _mapNetworkMode(NetworkNeed need) {
    switch (need) {
      case NetworkNeed.none:
        return NetworkMode.none;
      case NetworkNeed.optional:
        return NetworkMode.optional;
      case NetworkNeed.required:
        return NetworkMode.required;
      case NetworkNeed.conditional:
        return NetworkMode.conditional;
    }
  }

  StorageMode _mapStorageMode(StorageType type) {
    switch (type) {
      case StorageType.none:
        return StorageMode.none;
      case StorageType.ephemeral:
        return StorageMode.ephemeral;
      case StorageType.localKey:
        return StorageMode.localKey;
      case StorageType.localDatabase:
        return StorageMode.localDatabase;
      case StorageType.localFile:
        return StorageMode.localKey;
    }
  }

  /// Derive structural category from blueprint archetype.
  ///
  /// Uses archetype.name directly — no domain assumptions.
  /// For multiple archetypes, uses the first archetype deterministically.
  String _deriveStructuralCategory(AppBlueprint blueprint) {
    for (final archetype in blueprint.archetypes) {
      return archetype.name;
    }
    return 'generated';
  }

  // ── Blueprint-based builders ──────────────────────────────────────────

  InterfaceDefinition _buildInterfaceFromBlueprint(AppBlueprint blueprint) {
    final screens = <InterfaceScreen>[];
    for (final view in blueprint.views) {
      final nodes = <InterfaceNode>[];
      final entity = view.sourceEntityId != null
          ? blueprint.entities
                .where((e) => e.id == view.sourceEntityId)
                .firstOrNull
          : null;

      switch (view.viewType) {
        case BlueprintViewType.list:
          nodes.add(
            InterfaceNode(
              type: 'searchField',
              id: '${view.id}_search',
              properties: {
                'hint': 'Search ${entity?.name ?? ''}...',
                'entityId': view.sourceEntityId ?? '',
              },
            ),
          );
          nodes.add(
            InterfaceNode(
              type: 'entityList',
              id: '${view.id}_list',
              properties: {
                'entityId': view.sourceEntityId ?? '',
                'titleField': _findDisplayField(entity),
                'subtitleField': _findSecondaryField(entity),
              },
            ),
          );
          if (entity != null) {
            final createAction = blueprint.actions
                .where(
                  (a) =>
                      a.actionType == BlueprintActionType.create &&
                      a.targetEntityId == entity.id,
                )
                .firstOrNull;
            if (createAction != null) {
              nodes.add(
                InterfaceNode(
                  type: 'button',
                  id: '${view.id}_add_button',
                  properties: {'label': 'Add ${entity.name}', 'primary': true},
                  actionBinding: ActionBinding(
                    actionId: createAction.id,
                    parameters: {'entityId': entity.id},
                  ),
                ),
              );
            }
          }
          break;

        case BlueprintViewType.form:
          if (entity != null) {
            final fieldDefs = <Map<String, dynamic>>[];
            for (final field in entity.fields) {
              fieldDefs.add({
                'id': field.id,
                'name': field.name,
                'type': _mapBlueprintFieldType(field.type),
                'required': field.required,
                if (field.referenceEntityId != null)
                  'referenceEntityId': field.referenceEntityId,
                if (field.allowedValues.isNotEmpty)
                  'allowedValues': field.allowedValues,
                if (field.minLength != null) 'minLength': field.minLength,
                if (field.maxLength != null) 'maxLength': field.maxLength,
                if (field.minimum != null) 'minimum': field.minimum,
                if (field.maximum != null) 'maximum': field.maximum,
                if (field.description.isNotEmpty) 'hint': field.description,
              });
            }
            nodes.add(
              InterfaceNode(
                type: 'entityForm',
                id: '${view.id}_form',
                properties: {
                  'entityId': view.sourceEntityId ?? '',
                  'mode': 'create',
                  'fields': fieldDefs,
                },
              ),
            );
            // Note: entityForm already has its own submit button
            // (Create/Save). A standalone button here would fire the raw
            // action ID and bypass the form's validation + data collection.
          }
          break;

        case BlueprintViewType.dashboard:
          if (entity != null) {
            final metrics = <Map<String, dynamic>>[];
            metrics.add({
              'label': 'Total ${entity.name}',
              'operation': 'count',
              'entityId': entity.id,
            });
            for (final field in entity.fields) {
              if (field.type == BlueprintFieldType.integer ||
                  field.type == BlueprintFieldType.decimal) {
                metrics.add({
                  'label': '${field.name} (Sum)',
                  'operation': 'sum',
                  'entityId': entity.id,
                  'fieldId': field.id,
                });
                metrics.add({
                  'label': '${field.name} (Avg)',
                  'operation': 'average',
                  'entityId': entity.id,
                  'fieldId': field.id,
                });
              }
            }
            nodes.add(
              InterfaceNode(
                type: 'dashboardMetrics',
                id: '${view.id}_dashboard',
                properties: {'title': view.name, 'metrics': metrics},
              ),
            );
            final createAction = blueprint.actions
                .where(
                  (a) =>
                      a.actionType == BlueprintActionType.create &&
                      a.targetEntityId == entity.id,
                )
                .firstOrNull;
            if (createAction != null) {
              nodes.add(
                InterfaceNode(
                  type: 'button',
                  id: '${view.id}_add_button',
                  properties: {'label': 'Add ${entity.name}', 'primary': true},
                  actionBinding: ActionBinding(
                    actionId: createAction.id,
                    parameters: {'entityId': entity.id},
                  ),
                ),
              );
            }
          }
          break;

        case BlueprintViewType.detail:
          if (entity != null) {
            nodes.add(
              InterfaceNode(
                type: 'entityDetail',
                id: '${view.id}_detail',
                properties: {
                  'entityId': view.sourceEntityId ?? '',
                  'titleField': _findDisplayField(entity),
                },
              ),
            );
            final deleteAction = blueprint.actions
                .where(
                  (a) =>
                      a.actionType == BlueprintActionType.delete &&
                      a.targetEntityId == entity.id,
                )
                .firstOrNull;
            if (deleteAction != null) {
              nodes.add(
                InterfaceNode(
                  type: 'button',
                  id: '${view.id}_delete_button',
                  properties: {'label': 'Delete', 'danger': true},
                  actionBinding: ActionBinding(
                    actionId: deleteAction.id,
                    parameters: {'entityId': entity.id},
                  ),
                ),
              );
            }
          }
          break;

        case BlueprintViewType.calendar:
        case BlueprintViewType.settings:
        case BlueprintViewType.empty:
        case BlueprintViewType.summary:
          if (entity != null) {
            for (final field in entity.fields) {
              if (field.type == BlueprintFieldType.reference &&
                  field.referenceEntityId != null) {
                nodes.add(
                  InterfaceNode(
                    type: 'referenceSelector',
                    id: '${view.id}_${field.id}_ref',
                    properties: {
                      'entityId': field.referenceEntityId,
                      'label': 'Select ${field.name}',
                    },
                  ),
                );
              } else {
                nodes.add(
                  InterfaceNode(
                    type: field.type == BlueprintFieldType.boolean
                        ? 'switch'
                        : 'input',
                    id: '${view.id}_${field.id}',
                    properties: {
                      'label': field.name,
                      'hint': 'Enter ${field.name.toLowerCase()}',
                    },
                    stateBinding: '${entity.id}_${field.id}_input',
                  ),
                );
              }
            }
          }
          break;
      }

      // Add section header for each view
      if (nodes.isNotEmpty) {
        nodes.insert(
          0,
          InterfaceNode(
            type: 'heading',
            id: '${view.id}_title',
            properties: {'content': view.name, 'level': 2},
          ),
        );
      }

      screens.add(
        InterfaceScreen(
          id: view.id,
          title: view.name,
          appBarTitle: view.name,
          children: nodes,
        ),
      );

      // For form views, also generate an edit screen so the detail view's
      // Edit button has a target to navigate to.
      if (view.viewType == BlueprintViewType.form && entity != null) {
        final editNodes = <InterfaceNode>[];
        final fieldDefs = <Map<String, dynamic>>[];
        for (final field in entity.fields) {
          fieldDefs.add({
            'id': field.id,
            'name': field.name,
            'type': _mapBlueprintFieldType(field.type),
            'required': field.required,
            if (field.referenceEntityId != null)
              'referenceEntityId': field.referenceEntityId,
            if (field.allowedValues.isNotEmpty)
              'allowedValues': field.allowedValues,
            if (field.minLength != null) 'minLength': field.minLength,
            if (field.maxLength != null) 'maxLength': field.maxLength,
            if (field.minimum != null) 'minimum': field.minimum,
            if (field.maximum != null) 'maximum': field.maximum,
            if (field.description.isNotEmpty) 'hint': field.description,
          });
        }
        editNodes.add(
          InterfaceNode(
            type: 'entityForm',
            id: '${entity.id}_edit_form',
            properties: {
              'entityId': entity.id,
              'mode': 'edit',
              'fields': fieldDefs,
            },
          ),
        );
        screens.add(
          InterfaceScreen(
            id: '${entity.id}_edit',
            title: 'Edit ${entity.name}',
            appBarTitle: 'Edit ${entity.name}',
            children: editNodes,
          ),
        );
      }
    }

    if (screens.isEmpty) {
      screens.add(
        InterfaceScreen(
          id: 'main',
          title: blueprint.name,
          appBarTitle: blueprint.name,
          children: [
            InterfaceNode(
              type: 'text',
              id: 'empty_text',
              properties: {'content': 'No views defined'},
            ),
          ],
        ),
      );
    }

    final navigation = blueprint.views.length > 1
        ? NavigationDefinition(
            type: 'bottomNavigation',
            items: blueprint.views
                .where((v) => v.viewType != BlueprintViewType.form)
                .take(5)
                .map(
                  (v) => NavigationItem(
                    label: v.name,
                    icon: _viewTypeToIcon(v.viewType),
                    screenId: v.id,
                  ),
                )
                .toList(),
          )
        : null;

    return InterfaceDefinition(screens: screens, navigation: navigation);
  }

  String _findDisplayField(BlueprintEntity? entity) {
    if (entity == null) return 'name';
    for (final field in entity.fields) {
      if (field.id == 'name' || field.id == 'title' || field.id == 'label') {
        return field.id;
      }
    }
    return entity.fields.isNotEmpty ? entity.fields.first.id : 'name';
  }

  String? _findSecondaryField(BlueprintEntity? entity) {
    if (entity == null || entity.fields.length < 2) return null;
    for (final field in entity.fields) {
      if (field.id != _findDisplayField(entity) &&
          (field.type == BlueprintFieldType.text ||
              field.type == BlueprintFieldType.reference)) {
        return field.id;
      }
    }
    return entity.fields.length > 1 ? entity.fields[1].id : null;
  }

  BehaviorGraph _buildBehaviorFromBlueprint(AppBlueprint blueprint) {
    final nodes = <BehaviorNode>[];
    final edges = <BehaviorEdge>[];

    for (final action in blueprint.actions) {
      final eventId = '${action.id}_event';
      nodes.add(
        BehaviorNode(
          id: eventId,
          type: 'event',
          config: {'eventId': action.id},
        ),
      );

      switch (action.actionType) {
        case BlueprintActionType.create:
          final mutateNodeId = '${action.id}_create_data';
          nodes.add(
            BehaviorNode(
              id: mutateNodeId,
              type: 'dataMutation',
              config: {'operation': 'create', 'entity': action.targetEntityId},
            ),
          );
          edges.add(BehaviorEdge(from: eventId, to: mutateNodeId));
          break;
        case BlueprintActionType.update:
        case BlueprintActionType.setValue:
          final mutateNodeId = '${action.id}_update_data';
          nodes.add(
            BehaviorNode(
              id: mutateNodeId,
              type: 'dataMutation',
              config: {'operation': 'update', 'entity': action.targetEntityId},
            ),
          );
          edges.add(BehaviorEdge(from: eventId, to: mutateNodeId));
          break;
        case BlueprintActionType.delete:
          final mutateNodeId = '${action.id}_delete_data';
          nodes.add(
            BehaviorNode(
              id: mutateNodeId,
              type: 'dataMutation',
              config: {'operation': 'delete', 'entity': action.targetEntityId},
            ),
          );
          edges.add(BehaviorEdge(from: eventId, to: mutateNodeId));
          break;
        case BlueprintActionType.toggle:
          final mutateNodeId = '${action.id}_toggle_data';
          nodes.add(
            BehaviorNode(
              id: mutateNodeId,
              type: 'dataMutation',
              config: {'operation': 'toggle', 'entity': action.targetEntityId},
            ),
          );
          edges.add(BehaviorEdge(from: eventId, to: mutateNodeId));
          break;
        default:
          break;
      }
    }

    // Add derived value behaviors
    for (final dv in blueprint.derivedValues) {
      final queryNodeId = 'derived_${dv.id}_query';
      final queryStateId = '${dv.id}_raw_data';
      nodes.add(
        BehaviorNode(
          id: queryNodeId,
          type: 'dataQuery',
          config: {
            'entity': dv.sourceEntityId,
            'operation': 'query',
            'resultStateId': queryStateId,
          },
        ),
      );

      final calcNodeId = 'derived_${dv.id}_calc';
      nodes.add(
        BehaviorNode(
          id: calcNodeId,
          type: 'calculation',
          config: {
            'operation': dv.operation.name,
            'sourceStateId': queryStateId,
            'fieldId': dv.fieldId ?? '',
            'targetStateId': dv.id,
          },
        ),
      );
      edges.add(BehaviorEdge(from: queryNodeId, to: calcNodeId));
    }

    return BehaviorGraph(nodes: nodes, edges: edges);
  }

  StateSchema _buildStateFromBlueprint(AppBlueprint blueprint) {
    final variables = <StateVariable>[];

    // Add global search term state variable
    variables.add(
      const StateVariable(
        id: 'searchTerm',
        type: 'string',
        defaultValue: '',
        persistence: 'session',
      ),
    );

    // Add per-field input state variables
    for (final entity in blueprint.entities) {
      for (final field in entity.fields) {
        if (field.type != BlueprintFieldType.reference &&
            field.id != '${entity.id}_id' &&
            field.id != '${entity.id}_created_at' &&
            field.id != '${entity.id}_updated_at') {
          variables.add(
            StateVariable(
              id: '${entity.id}_${field.id}_input',
              type: _mapBlueprintFieldType(field.type),
              defaultValue: field.defaultValue ?? _defaultForType(field.type),
              persistence: 'session',
            ),
          );
        }
      }
    }

    // Add derived value state variables
    for (final dv in blueprint.derivedValues) {
      variables.add(
        StateVariable(
          id: dv.id,
          type: 'string',
          defaultValue: '0',
          persistence: 'session',
        ),
      );
      variables.add(
        StateVariable(
          id: '${dv.id}_raw_data',
          type: 'list',
          defaultValue: <dynamic>[],
          persistence: 'session',
        ),
      );
    }

    // Add navigation state if multiple views
    if (blueprint.views.length > 1) {
      variables.add(
        StateVariable(
          id: 'current_screen',
          type: 'string',
          defaultValue:
              blueprint.views.where((v) => v.isDefault).firstOrNull?.id ??
              blueprint.views.first.id,
          persistence: 'session',
        ),
      );
    }

    variables.add(
      const StateVariable(
        id: 'current_record_id',
        type: 'string',
        defaultValue: '',
        persistence: 'session',
      ),
    );

    return StateSchema(variables: variables);
  }

  DataSchema _buildDataSchemaFromBlueprint(AppBlueprint blueprint) {
    final entitySchemas = blueprint.entities.map((entity) {
      return DataEntitySchema(
        id: entity.id,
        name: entity.name,
        fields: entity.fields.map((field) {
          return DataFieldSchema(
            id: field.id,
            name: field.name,
            type: _mapBlueprintFieldType(field.type),
            required: field.required,
            defaultValue: field.defaultValue,
            referenceEntityId: field.referenceEntityId,
            allowedValues: field.allowedValues,
            hint: field.description.isNotEmpty ? field.description : null,
          );
        }).toList(),
      );
    }).toList();

    return DataSchema(entities: entitySchemas, schemaVersion: 1);
  }

  String _mapBlueprintFieldType(BlueprintFieldType type) {
    switch (type) {
      case BlueprintFieldType.integer:
        return 'integer';
      case BlueprintFieldType.decimal:
        return 'decimal';
      case BlueprintFieldType.boolean:
        return 'boolean';
      case BlueprintFieldType.reference:
        return 'reference';
      case BlueprintFieldType.category:
        return 'enum';
      case BlueprintFieldType.multilineText:
        return 'multiline';
      case BlueprintFieldType.date:
        return 'date';
      case BlueprintFieldType.dateTime:
        return 'datetime';
      case BlueprintFieldType.time:
        return 'time';
      default:
        return 'string';
    }
  }

  String _defaultForType(BlueprintFieldType type) {
    switch (type) {
      case BlueprintFieldType.integer:
        return '0';
      case BlueprintFieldType.decimal:
        return '0.0';
      case BlueprintFieldType.boolean:
        return 'false';
      default:
        return '';
    }
  }

  String _viewTypeToIcon(BlueprintViewType type) {
    switch (type) {
      case BlueprintViewType.list:
        return 'list';
      case BlueprintViewType.detail:
        return 'info';
      case BlueprintViewType.form:
        return 'edit';
      case BlueprintViewType.dashboard:
        return 'dashboard';
      case BlueprintViewType.calendar:
        return 'calendar';
      case BlueprintViewType.settings:
        return 'settings';
      case BlueprintViewType.empty:
        return 'inbox';
      case BlueprintViewType.summary:
        return 'bar_chart';
    }
  }
}
