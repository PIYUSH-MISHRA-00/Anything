/// Generic Package Builder — converts AppBlueprint into ExperiencePackage.
///
/// This is the core synthesis engine that translates semantic blueprint
/// structures into the trusted declarative ExperiencePackage format.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../creation/experience_package.dart';
import 'app_blueprint.dart';

/// Builds an ExperiencePackage from an AppBlueprint.
class GenericPackageBuilder {
  /// Build an ExperiencePackage from a validated AppBlueprint.
  static ExperiencePackage build(AppBlueprint blueprint) {
    final interface = _buildInterface(blueprint);
    final behavior = _buildBehavior(blueprint);
    final state = _buildState(blueprint);
    final data = _buildData(blueprint);
    final manifest = _buildManifest(blueprint);
    final provenance = _buildProvenance(blueprint);
    final integrity = _computeIntegrity(manifest, interface, behavior, state);

    return ExperiencePackage(
      packageVersion: experiencePackageVersion,
      manifest: manifest,
      interface: interface,
      behavior: behavior,
      state: state,
      data: data,
      services: const [],
      protection: const ProtectionMetadata(),
      provenance: provenance,
      integrity: integrity,
    );
  }

  static InterfaceDefinition _buildInterface(AppBlueprint blueprint) {
    final screens = <InterfaceScreen>[];
    for (final view in blueprint.views) {
      screens.add(_buildScreen(view, blueprint));
    }

    final navigation = blueprint.views.length > 1
        ? NavigationDefinition(
            type: 'bottomNavigation',
            items: blueprint.views
                .where(
                  (v) => v.isDefault || v.viewType != BlueprintViewType.form,
                )
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

  static InterfaceScreen _buildScreen(
    BlueprintView view,
    AppBlueprint blueprint,
  ) {
    final nodes = <InterfaceNode>[];

    switch (view.viewType) {
      case BlueprintViewType.list:
        nodes.addAll(_buildListNodes(view, blueprint));
        break;
      case BlueprintViewType.form:
        nodes.addAll(_buildFormNodes(view, blueprint));
        break;
      case BlueprintViewType.dashboard:
        nodes.addAll(_buildDashboardNodes(view, blueprint));
        break;
      default:
        nodes.addAll(_buildListNodes(view, blueprint));
    }

    return InterfaceScreen(
      id: view.id,
      title: view.name,
      appBarTitle: view.name,
      children: nodes,
    );
  }

  static List<InterfaceNode> _buildListNodes(
    BlueprintView view,
    AppBlueprint blueprint,
  ) {
    final nodes = <InterfaceNode>[];
    final entity = blueprint.entities
        .where((e) => e.id == view.sourceEntityId)
        .firstOrNull;

    if (entity == null) return nodes;

    nodes.add(
      InterfaceNode(
        type: 'text',
        id: '${view.id}_title',
        properties: {'text': view.purpose, 'style': 'headlineSmall'},
      ),
    );

    nodes.add(
      InterfaceNode(
        type: 'column',
        id: '${view.id}_list',
        properties: {'crossAxisAlignment': 'stretch'},
        stateBinding: '${entity.id}_list_data',
        children: [],
      ),
    );

    if (view.primaryActionId != null) {
      nodes.add(
        InterfaceNode(
          type: 'button',
          id: '${view.id}_add_button',
          properties: {'text': 'Add ${entity.name}', 'icon': 'add'},
          actionBinding: ActionBinding(
            actionId: view.primaryActionId!,
            parameters: {'entityId': entity.id},
          ),
        ),
      );
    }

    return nodes;
  }

  static List<InterfaceNode> _buildFormNodes(
    BlueprintView view,
    AppBlueprint blueprint,
  ) {
    final nodes = <InterfaceNode>[];
    final entity = blueprint.entities
        .where((e) => e.id == view.entityId)
        .firstOrNull;

    if (entity == null) return nodes;

    nodes.add(
      InterfaceNode(
        type: 'text',
        id: '${view.id}_title',
        properties: {'text': view.name, 'style': 'headlineSmall'},
      ),
    );

    for (final field in entity.fields) {
      if (field.id == '${entity.id}_id' ||
          field.id == '${entity.id}_created_at' ||
          field.id == '${entity.id}_updated_at') {
        continue;
      }

      nodes.add(_buildFormField(field, entity.id));
    }

    nodes.add(
      InterfaceNode(
        type: 'button',
        id: '${view.id}_save_button',
        properties: {'text': 'Save', 'icon': 'check'},
        actionBinding: ActionBinding(
          actionId: 'save_${entity.id}',
          parameters: {'entityId': entity.id},
        ),
      ),
    );

    return nodes;
  }

  static InterfaceNode _buildFormField(BlueprintField field, String entityId) {
    final stateId = '${entityId}_${field.id}_input';

    switch (field.type) {
      case BlueprintFieldType.multilineText:
        return InterfaceNode(
          type: 'input',
          id: 'field_${field.id}',
          properties: {
            'label': field.name,
            'hint': 'Enter ${field.name.toLowerCase()}',
            'maxLines': 5,
          },
          stateBinding: stateId,
        );

      case BlueprintFieldType.integer:
        return InterfaceNode(
          type: 'input',
          id: 'field_${field.id}',
          properties: {
            'label': field.name,
            'hint': 'Enter ${field.name.toLowerCase()}',
            'keyboardType': 'number',
          },
          stateBinding: stateId,
        );

      case BlueprintFieldType.decimal:
        return InterfaceNode(
          type: 'input',
          id: 'field_${field.id}',
          properties: {
            'label': field.name,
            'hint': 'Enter ${field.name.toLowerCase()}',
            'keyboardType': 'decimal',
          },
          stateBinding: stateId,
        );

      case BlueprintFieldType.boolean:
        return InterfaceNode(
          type: 'switch',
          id: 'field_${field.id}',
          properties: {'label': field.name},
          stateBinding: stateId,
        );

      case BlueprintFieldType.category:
        return InterfaceNode(
          type: 'input',
          id: 'field_${field.id}',
          properties: {
            'label': field.name,
            'hint': 'Select ${field.name.toLowerCase()}',
            'allowedValues': field.allowedValues,
          },
          stateBinding: stateId,
        );

      case BlueprintFieldType.date:
        return InterfaceNode(
          type: 'input',
          id: 'field_${field.id}',
          properties: {'label': field.name, 'inputType': 'date'},
          stateBinding: stateId,
        );

      default:
        return InterfaceNode(
          type: 'input',
          id: 'field_${field.id}',
          properties: {
            'label': field.name,
            'hint': 'Enter ${field.name.toLowerCase()}',
          },
          stateBinding: stateId,
        );
    }
  }

  static List<InterfaceNode> _buildDashboardNodes(
    BlueprintView view,
    AppBlueprint blueprint,
  ) {
    final nodes = <InterfaceNode>[];

    nodes.add(
      InterfaceNode(
        type: 'text',
        id: '${view.id}_title',
        properties: {'text': view.name, 'style': 'headlineSmall'},
      ),
    );

    for (final section in view.sections) {
      if (section.sectionType == BlueprintSectionType.summary) {
        nodes.add(
          InterfaceNode(
            type: 'card',
            id: '${view.id}_summary_${section.id}',
            properties: {'title': section.purpose},
            stateBinding: '${section.sourceEntityId}_summary',
          ),
        );
      } else if (section.sectionType == BlueprintSectionType.list) {
        nodes.add(
          InterfaceNode(
            type: 'column',
            id: '${view.id}_list_${section.id}',
            properties: {'crossAxisAlignment': 'stretch'},
            stateBinding: '${section.sourceEntityId}_list_data',
            children: [],
          ),
        );
      }
    }

    if (view.primaryActionId != null) {
      final targetAction = blueprint.actions
          .where((a) => a.id == view.primaryActionId)
          .firstOrNull;
      if (targetAction != null) {
        nodes.add(
          InterfaceNode(
            type: 'button',
            id: '${view.id}_add_button',
            properties: {'text': 'Add', 'icon': 'add'},
            actionBinding: ActionBinding(
              actionId: view.primaryActionId!,
              parameters: {'entityId': targetAction.targetEntityId},
            ),
          ),
        );
      }
    }

    return nodes;
  }

  static BehaviorGraph _buildBehavior(AppBlueprint blueprint) {
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
          _addCreateBehavior(nodes, edges, action, blueprint, eventId);
          break;
        case BlueprintActionType.update:
        case BlueprintActionType.setValue:
          _addUpdateBehavior(nodes, edges, action, blueprint, eventId);
          break;
        case BlueprintActionType.delete:
          _addDeleteBehavior(nodes, edges, action, blueprint, eventId);
          break;
        case BlueprintActionType.toggle:
          _addToggleBehavior(nodes, edges, action, blueprint, eventId);
          break;
        default:
          break;
      }
    }

    for (final dv in blueprint.derivedValues) {
      _addDerivedValueBehavior(nodes, edges, dv, blueprint);
    }

    return BehaviorGraph(nodes: nodes, edges: edges);
  }

  static void _addCreateBehavior(
    List<BehaviorNode> nodes,
    List<BehaviorEdge> edges,
    BlueprintAction action,
    AppBlueprint blueprint,
    String eventId,
  ) {
    final entity = blueprint.entities
        .where((e) => e.id == action.targetEntityId)
        .firstOrNull;
    if (entity == null) return;

    final formView = blueprint.views
        .where(
          (v) =>
              v.viewType == BlueprintViewType.form && v.entityId == entity.id,
        )
        .firstOrNull;
    if (formView != null) {
      final navNodeId = '${action.id}_navigate_form';
      nodes.add(
        BehaviorNode(
          id: navNodeId,
          type: 'navigation',
          config: {'action': 'navigateTo', 'target': formView.id},
        ),
      );
      edges.add(BehaviorEdge(from: eventId, to: navNodeId));
    }
  }

  static void _addUpdateBehavior(
    List<BehaviorNode> nodes,
    List<BehaviorEdge> edges,
    BlueprintAction action,
    AppBlueprint blueprint,
    String eventId,
  ) {
    final entity = blueprint.entities
        .where((e) => e.id == action.targetEntityId)
        .firstOrNull;
    if (entity == null) return;

    final mutateNodeId = '${action.id}_update_data';
    nodes.add(
      BehaviorNode(
        id: mutateNodeId,
        type: 'dataMutation',
        config: {'operation': 'update', 'entity': entity.id},
      ),
    );
    edges.add(BehaviorEdge(from: eventId, to: mutateNodeId));
  }

  static void _addDeleteBehavior(
    List<BehaviorNode> nodes,
    List<BehaviorEdge> edges,
    BlueprintAction action,
    AppBlueprint blueprint,
    String eventId,
  ) {
    final entity = blueprint.entities
        .where((e) => e.id == action.targetEntityId)
        .firstOrNull;
    if (entity == null) return;

    final mutateNodeId = '${action.id}_delete_data';
    nodes.add(
      BehaviorNode(
        id: mutateNodeId,
        type: 'dataMutation',
        config: {'operation': 'delete', 'entity': entity.id},
      ),
    );
    edges.add(BehaviorEdge(from: eventId, to: mutateNodeId));
  }

  static void _addToggleBehavior(
    List<BehaviorNode> nodes,
    List<BehaviorEdge> edges,
    BlueprintAction action,
    AppBlueprint blueprint,
    String eventId,
  ) {
    final entity = blueprint.entities
        .where((e) => e.id == action.targetEntityId)
        .firstOrNull;
    if (entity == null) return;

    final toggleNodeId = '${action.id}_toggle_data';
    nodes.add(
      BehaviorNode(
        id: toggleNodeId,
        type: 'dataMutation',
        config: {'operation': 'toggle', 'entity': entity.id},
      ),
    );
    edges.add(BehaviorEdge(from: eventId, to: toggleNodeId));
  }

  static void _addDerivedValueBehavior(
    List<BehaviorNode> nodes,
    List<BehaviorEdge> edges,
    BlueprintDerivedValue dv,
    AppBlueprint blueprint,
  ) {
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

  static StateSchema _buildState(AppBlueprint blueprint) {
    final variables = <StateVariable>[];

    for (final entity in blueprint.entities) {
      for (final field in entity.fields) {
        if (field.type != BlueprintFieldType.reference &&
            field.id != '${entity.id}_id' &&
            field.id != '${entity.id}_created_at' &&
            field.id != '${entity.id}_updated_at') {
          variables.add(
            StateVariable(
              id: '${entity.id}_${field.id}_input',
              type: _mapFieldTypeToStateType(field.type),
              defaultValue: field.defaultValue ?? _defaultForType(field.type),
              persistence: 'session',
            ),
          );
        }
      }
    }

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
      StateVariable(
        id: 'current_record_id',
        type: 'string',
        defaultValue: '',
        persistence: 'session',
      ),
    );

    return StateSchema(variables: variables);
  }

  static String _mapFieldTypeToStateType(BlueprintFieldType type) {
    switch (type) {
      case BlueprintFieldType.integer:
        return 'integer';
      case BlueprintFieldType.decimal:
        return 'decimal';
      case BlueprintFieldType.boolean:
        return 'boolean';
      default:
        return 'string';
    }
  }

  static String _defaultForType(BlueprintFieldType type) {
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

  static DataSchema? _buildData(AppBlueprint blueprint) {
    if (blueprint.entities.isEmpty) return null;

    final entitySchemas = blueprint.entities.map((entity) {
      return DataEntitySchema(
        id: entity.id,
        name: entity.name,
        fields: entity.fields.map((field) {
          return DataFieldSchema(
            id: field.id,
            name: field.name,
            type: _mapBlueprintFieldTypeToDataFieldType(field.type),
            required: field.required,
            defaultValue: field.defaultValue,
          );
        }).toList(),
      );
    }).toList();

    return DataSchema(entities: entitySchemas, schemaVersion: 1);
  }

  static String _mapBlueprintFieldTypeToDataFieldType(BlueprintFieldType type) {
    switch (type) {
      case BlueprintFieldType.integer:
        return 'integer';
      case BlueprintFieldType.decimal:
        return 'decimal';
      case BlueprintFieldType.boolean:
        return 'boolean';
      default:
        return 'string';
    }
  }

  static ExperienceManifest _buildManifest(AppBlueprint blueprint) {
    return ExperienceManifest(
      experienceId: blueprint.id,
      name: blueprint.name,
      version: '1.0.0',
      description: blueprint.description,
      networkMode: blueprint.networkConfig != null
          ? NetworkMode.required
          : NetworkMode.none,
      storageMode: blueprint.entities.isNotEmpty
          ? StorageMode.localDatabase
          : StorageMode.ephemeral,
      category: _deriveCategory(blueprint),
      tags: blueprint.tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static String _deriveCategory(AppBlueprint blueprint) {
    // Structural categories derived from archetypes — no domain assumptions.
    // Each archetype maps to its structural category name.
    for (final archetype in blueprint.archetypes) {
      return archetype.name;
    }
    return 'generated';
  }

  static PackageProvenance _buildProvenance(AppBlueprint blueprint) {
    return PackageProvenance(
      resourcesConsulted: ['synthesis_engine'],
      packagesSelected: blueprint.archetypes.map((a) => a.name).toList(),
      creationEngineVersion: '10.0.0',
      specVersion: 1,
      planVersion: 1,
    );
  }

  static PackageIntegrity _computeIntegrity(
    ExperienceManifest manifest,
    InterfaceDefinition interface,
    BehaviorGraph behavior,
    StateSchema state,
  ) {
    final content = jsonEncode({
      'manifest': manifest.toJson(),
      'interface': interface.toJson(),
      'behavior': behavior.toJson(),
      'state': state.toJson(),
    });
    final hash = sha256.convert(utf8.encode(content)).toString();
    return PackageIntegrity(contentHash: hash, computedAt: DateTime.now());
  }

  static String _viewTypeToIcon(BlueprintViewType type) {
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
