/// Modification Engine — applies typed modifications to existing Experiences.
library;

import 'package:uuid/uuid.dart';

import '../../creation/experience_package.dart';
import 'experience_modification_spec.dart';

/// Result of modification.
sealed class ModificationResult {
  final String message;
  const ModificationResult({required this.message});
}

class ModificationReady extends ModificationResult {
  final ExperiencePackage updatedPackage;
  const ModificationReady({
    required this.updatedPackage,
    required super.message,
  });
}

class ModificationFailed extends ModificationResult {
  final String error;
  const ModificationFailed({required this.error, required super.message});
}

class ModificationUnsupported extends ModificationResult {
  final String reason;
  const ModificationUnsupported({required this.reason, required super.message});
}

/// Applies typed modifications to existing Experiences.
class ModificationEngine {
  /// Modify an existing package according to a spec.
  Future<ModificationResult> modify(
    ExperiencePackage existingPackage,
    ExperienceModificationSpec spec,
  ) async {
    try {
      final updatedManifest = ExperienceManifest(
        experienceId: existingPackage.manifest.experienceId,
        name: spec.params['name'] as String? ?? existingPackage.manifest.name,
        description:
            spec.params['description'] as String? ??
            existingPackage.manifest.description,
        version: _bumpVersion(existingPackage.manifest.version),
        createdAt: existingPackage.manifest.createdAt,
        updatedAt: DateTime.now(),
        networkMode: existingPackage.manifest.networkMode,
        storageMode: existingPackage.manifest.storageMode,
        requiredCapabilities: [
          ...existingPackage.manifest.requiredCapabilities,
          ...spec.requiredCapabilities,
        ],
      );

      final updatedInterface = _applyInterfaceOps(
        existingPackage.interface,
        spec.operations,
      );
      final updatedBehavior = _applyBehaviorOps(
        existingPackage.behavior,
        spec.operations,
      );
      final updatedState = _applyStateOps(
        existingPackage.state,
        spec.operations,
      );
      final updatedData = _applyDataOps(existingPackage.data, spec.operations);

      final updatedPackage = ExperiencePackage(
        manifest: updatedManifest,
        interface: updatedInterface,
        behavior: updatedBehavior,
        state: updatedState,
        data: updatedData,
        services: existingPackage.services,
        networkDeclarations: existingPackage.networkDeclarations,
        capabilityDeclarations: [
          ...existingPackage.capabilityDeclarations,
          ...spec.requiredCapabilities.map(
            (c) => CapabilityDeclaration(capabilityId: c),
          ),
        ],
        permissionDeclarations: [
          ...existingPackage.permissionDeclarations,
          ...spec.requiredPermissions.map(
            (p) => PermissionDeclaration(
              permission: p,
              reason: 'Required by modification',
            ),
          ),
        ],
        provenance: PackageProvenance(
          resourcesConsulted: existingPackage.provenance.resourcesConsulted,
          creationEngineVersion: '1.0.0',
          specVersion: existingPackage.provenance.specVersion,
          planVersion: existingPackage.provenance.planVersion,
        ),
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime.now(),
        ),
      );

      final hash = ExperiencePackage.computeIntegrityHash(updatedPackage);
      final finalPackage = ExperiencePackage(
        packageVersion: updatedPackage.packageVersion,
        manifest: updatedPackage.manifest,
        interface: updatedPackage.interface,
        behavior: updatedPackage.behavior,
        state: updatedPackage.state,
        data: updatedPackage.data,
        services: updatedPackage.services,
        networkDeclarations: updatedPackage.networkDeclarations,
        capabilityDeclarations: updatedPackage.capabilityDeclarations,
        permissionDeclarations: updatedPackage.permissionDeclarations,
        provenance: updatedPackage.provenance,
        integrity: PackageIntegrity(
          contentHash: hash,
          computedAt: DateTime.now(),
        ),
      );

      return ModificationReady(
        updatedPackage: finalPackage,
        message: 'Modification applied',
      );
    } catch (e) {
      return ModificationFailed(
        error: e.toString(),
        message: 'Modification failed',
      );
    }
  }

  String _bumpVersion(String version) {
    final parts = version.split('.');
    if (parts.length < 3) return '$version.1';
    final patch = int.tryParse(parts[2]) ?? 0;
    return '${parts[0]}.${parts[1]}.${patch + 1}';
  }

  InterfaceDefinition _applyInterfaceOps(
    InterfaceDefinition existing,
    List<ModificationOperation> ops,
  ) {
    var screens = List<InterfaceScreen>.from(existing.screens);

    for (final op in ops) {
      switch (op.type) {
        case ModificationType.addUiNode:
          screens = _addNodeToScreens(screens, op.params);
          break;
        case ModificationType.modifyUiNode:
          screens = _modifyNodeInScreens(screens, op.params);
          break;
        case ModificationType.removeUiNode:
          screens = _removeNodeFromScreens(screens, op.params);
          break;
        default:
          break;
      }
    }

    return InterfaceDefinition(
      screens: screens,
      navigation: existing.navigation,
    );
  }

  List<InterfaceScreen> _addNodeToScreens(
    List<InterfaceScreen> screens,
    Map<String, dynamic> params,
  ) {
    final screenId =
        params['screenId'] as String? ??
        (screens.isNotEmpty ? screens.first.id : 'main');
    final nodeType = params['nodeType'] as String? ?? 'button';
    final label = params['label'] as String? ?? 'New';
    final actionId = params['actionId'] as String?;
    final stateBinding = params['stateBinding'] as String?;

    final newNode = InterfaceNode(
      type: nodeType,
      id: 'node-${const Uuid().v4().substring(0, 8)}',
      properties: {'label': label},
      actionBinding: actionId != null
          ? ActionBinding(actionId: actionId)
          : null,
      stateBinding: stateBinding,
    );

    return screens.map((screen) {
      if (screen.id == screenId) {
        return InterfaceScreen(
          id: screen.id,
          title: screen.title,
          appBarTitle: screen.appBarTitle,
          children: [...screen.children, newNode],
        );
      }
      return screen;
    }).toList();
  }

  List<InterfaceScreen> _modifyNodeInScreens(
    List<InterfaceScreen> screens,
    Map<String, dynamic> params,
  ) {
    final nodeId = params['nodeId'] as String?;
    final properties = params['properties'] as Map<String, dynamic>?;
    if (nodeId == null || properties == null) return screens;

    return screens.map((screen) {
      return InterfaceScreen(
        id: screen.id,
        title: screen.title,
        appBarTitle: screen.appBarTitle,
        children: screen.children.map((node) {
          if (node.id == nodeId) {
            return InterfaceNode(
              type: node.type,
              id: node.id,
              properties: {...node.properties, ...properties},
              children: node.children,
              stateBinding: node.stateBinding,
              actionBinding: node.actionBinding,
            );
          }
          return node;
        }).toList(),
      );
    }).toList();
  }

  List<InterfaceScreen> _removeNodeFromScreens(
    List<InterfaceScreen> screens,
    Map<String, dynamic> params,
  ) {
    final nodeId = params['nodeId'] as String?;
    if (nodeId == null) return screens;

    return screens.map((screen) {
      return InterfaceScreen(
        id: screen.id,
        title: screen.title,
        appBarTitle: screen.appBarTitle,
        children: screen.children.where((node) => node.id != nodeId).toList(),
      );
    }).toList();
  }

  BehaviorGraph _applyBehaviorOps(
    BehaviorGraph existing,
    List<ModificationOperation> ops,
  ) {
    var nodes = List<BehaviorNode>.from(existing.nodes);
    var edges = List<BehaviorEdge>.from(existing.edges);

    for (final op in ops) {
      switch (op.type) {
        case ModificationType.addBehavior:
          nodes = _addBehaviorNode(nodes, op.params);
          break;
        case ModificationType.modifyBehavior:
          nodes = _modifyBehaviorNode(nodes, op.params);
          break;
        case ModificationType.removeBehavior:
          nodes = _removeBehaviorNode(nodes, op.params);
          break;
        default:
          break;
      }
    }

    return BehaviorGraph(nodes: nodes, edges: edges);
  }

  List<BehaviorNode> _addBehaviorNode(
    List<BehaviorNode> nodes,
    Map<String, dynamic> params,
  ) {
    final nodeType = params['nodeType'] as String? ?? 'event';
    final config = Map<String, dynamic>.from(params['config'] as Map? ?? {});

    return [
      ...nodes,
      BehaviorNode(
        id: 'node-${const Uuid().v4().substring(0, 8)}',
        type: nodeType,
        config: config,
      ),
    ];
  }

  List<BehaviorNode> _modifyBehaviorNode(
    List<BehaviorNode> nodes,
    Map<String, dynamic> params,
  ) {
    final nodeId = params['nodeId'] as String?;
    final config = params['config'] as Map<String, dynamic>?;
    if (nodeId == null || config == null) return nodes;

    return nodes.map((node) {
      if (node.id == nodeId) {
        return BehaviorNode(
          id: node.id,
          type: node.type,
          config: {...node.config, ...config},
        );
      }
      return node;
    }).toList();
  }

  List<BehaviorNode> _removeBehaviorNode(
    List<BehaviorNode> nodes,
    Map<String, dynamic> params,
  ) {
    final nodeId = params['nodeId'] as String?;
    if (nodeId == null) return nodes;
    return nodes.where((node) => node.id != nodeId).toList();
  }

  StateSchema _applyStateOps(
    StateSchema existing,
    List<ModificationOperation> ops,
  ) {
    var variables = List<StateVariable>.from(existing.variables);

    for (final op in ops) {
      if (op.type == ModificationType.addState) {
        final id = op.params['id'] as String?;
        final type = op.params['type'] as String? ?? 'string';
        final defaultValue = op.params['defaultValue'];
        if (id != null) {
          variables.add(
            StateVariable(id: id, type: type, defaultValue: defaultValue),
          );
        }
      }
    }

    return StateSchema(variables: variables);
  }

  DataSchema? _applyDataOps(
    DataSchema? existing,
    List<ModificationOperation> ops,
  ) {
    if (existing == null) return null;
    var entities = List<DataEntitySchema>.from(existing.entities);

    for (final op in ops) {
      if (op.type == ModificationType.addEntity) {
        final name = op.params['name'] as String?;
        final fields =
            (op.params['fields'] as List?)
                ?.map(
                  (f) => DataFieldSchema(
                    id: f['id'] as String? ?? 'field_${f['name']}',
                    name: f['name'] as String,
                    type: f['type'] as String? ?? 'string',
                    required: f['required'] as bool? ?? false,
                  ),
                )
                .toList() ??
            [];
        if (name != null) {
          entities.add(
            DataEntitySchema(
              id: 'entity_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              fields: fields,
            ),
          );
        }
      }
    }

    return DataSchema(
      entities: entities,
      schemaVersion: existing.schemaVersion + 1,
    );
  }
}
