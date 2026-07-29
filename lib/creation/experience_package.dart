/// Experience Package — the canonical format for generated applications.
///
/// Versioned, portable, machine-validatable representation of a
/// complete Experience inside Anything.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

const int experiencePackageVersion = 1;

/// A complete generated Experience package.
class ExperiencePackage {
  final int packageVersion;
  final ExperienceManifest manifest;
  final InterfaceDefinition interface;
  final BehaviorGraph behavior;
  final StateSchema state;
  final DataSchema? data;
  final List<ServiceDefinition> services;
  final List<NetworkDeclaration> networkDeclarations;
  final List<CapabilityDeclaration> capabilityDeclarations;
  final List<PermissionDeclaration> permissionDeclarations;
  final ProtectionMetadata? protection;
  final PackageProvenance provenance;
  final PackageIntegrity integrity;

  const ExperiencePackage({
    this.packageVersion = experiencePackageVersion,
    required this.manifest,
    required this.interface,
    required this.behavior,
    required this.state,
    this.data,
    this.services = const [],
    this.networkDeclarations = const [],
    this.capabilityDeclarations = const [],
    this.permissionDeclarations = const [],
    this.protection,
    required this.provenance,
    required this.integrity,
  });

  /// Compute integrity hash from package content.
  static String computeIntegrityHash(ExperiencePackage package) {
    final content = jsonEncode({
      'manifest': package.manifest.toJson(),
      'interface': package.interface.toJson(),
      'behavior': package.behavior.toJson(),
      'state': package.state.toJson(),
    });
    return sha256.convert(utf8.encode(content)).toString();
  }

  Map<String, dynamic> toJson() => {
    'packageVersion': packageVersion,
    'manifest': manifest.toJson(),
    'interface': interface.toJson(),
    'behavior': behavior.toJson(),
    'state': state.toJson(),
    'data': data?.toJson(),
    'services': services.map((s) => s.toJson()).toList(),
    'networkDeclarations': networkDeclarations.map((n) => n.toJson()).toList(),
    'capabilityDeclarations': capabilityDeclarations
        .map((c) => c.toJson())
        .toList(),
    'permissionDeclarations': permissionDeclarations
        .map((p) => p.toJson())
        .toList(),
    'protection': protection?.toJson(),
    'provenance': provenance.toJson(),
    'integrity': integrity.toJson(),
  };

  factory ExperiencePackage.fromJson(Map<String, dynamic> json) {
    return ExperiencePackage(
      packageVersion: json['packageVersion'] as int? ?? 1,
      manifest: ExperienceManifest.fromJson(
        json['manifest'] as Map<String, dynamic>,
      ),
      interface: InterfaceDefinition.fromJson(
        json['interface'] as Map<String, dynamic>,
      ),
      behavior: BehaviorGraph.fromJson(
        json['behavior'] as Map<String, dynamic>,
      ),
      state: StateSchema.fromJson(json['state'] as Map<String, dynamic>),
      data: json['data'] != null
          ? DataSchema.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      services:
          (json['services'] as List?)
              ?.map(
                (s) => ServiceDefinition.fromJson(s as Map<String, dynamic>),
              )
              .toList() ??
          [],
      networkDeclarations:
          (json['networkDeclarations'] as List?)
              ?.map(
                (n) => NetworkDeclaration.fromJson(n as Map<String, dynamic>),
              )
              .toList() ??
          [],
      capabilityDeclarations:
          (json['capabilityDeclarations'] as List?)
              ?.map(
                (c) =>
                    CapabilityDeclaration.fromJson(c as Map<String, dynamic>),
              )
              .toList() ??
          [],
      permissionDeclarations:
          (json['permissionDeclarations'] as List?)
              ?.map(
                (p) =>
                    PermissionDeclaration.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          [],
      protection: json['protection'] != null
          ? ProtectionMetadata.fromJson(
              json['protection'] as Map<String, dynamic>,
            )
          : null,
      provenance: PackageProvenance.fromJson(
        json['provenance'] as Map<String, dynamic>,
      ),
      integrity: PackageIntegrity.fromJson(
        json['integrity'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Package manifest.
class ExperienceManifest {
  final String experienceId;
  final String name;
  final String description;
  final String version;
  final String? minimumRuntimeVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String entryPoint;
  final List<String> requiredCapabilities;
  final List<String> optionalCapabilities;
  final NetworkMode networkMode;
  final StorageMode storageMode;
  final String category;
  final List<String> tags;

  const ExperienceManifest({
    required this.experienceId,
    required this.name,
    required this.description,
    this.version = '1.0.0',
    this.minimumRuntimeVersion,
    required this.createdAt,
    required this.updatedAt,
    this.entryPoint = 'main',
    this.requiredCapabilities = const [],
    this.optionalCapabilities = const [],
    this.networkMode = NetworkMode.none,
    this.storageMode = StorageMode.none,
    this.category = 'utility',
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'experienceId': experienceId,
    'name': name,
    'description': description,
    'version': version,
    'minimumRuntimeVersion': minimumRuntimeVersion,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'entryPoint': entryPoint,
    'requiredCapabilities': requiredCapabilities,
    'optionalCapabilities': optionalCapabilities,
    'networkMode': networkMode.name,
    'storageMode': storageMode.name,
    'category': category,
    'tags': tags,
  };

  factory ExperienceManifest.fromJson(Map<String, dynamic> json) {
    return ExperienceManifest(
      experienceId: json['experienceId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String? ?? '1.0.0',
      minimumRuntimeVersion: json['minimumRuntimeVersion'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      entryPoint: json['entryPoint'] as String? ?? 'main',
      requiredCapabilities: List<String>.from(
        json['requiredCapabilities'] ?? [],
      ),
      optionalCapabilities: List<String>.from(
        json['optionalCapabilities'] ?? [],
      ),
      networkMode: NetworkMode.values.firstWhere(
        (m) => m.name == json['networkMode'],
        orElse: () => NetworkMode.none,
      ),
      storageMode: StorageMode.values.firstWhere(
        (m) => m.name == json['storageMode'],
        orElse: () => StorageMode.none,
      ),
      category: json['category'] as String? ?? 'utility',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    );
  }
}

enum NetworkMode { none, optional, required, conditional }

enum StorageMode { none, ephemeral, localKey, localDatabase }

/// Declarative interface definition.
class InterfaceDefinition {
  final List<InterfaceScreen> screens;
  final NavigationDefinition? navigation;

  const InterfaceDefinition({this.screens = const [], this.navigation});

  Map<String, dynamic> toJson() => {
    'screens': screens.map((s) => s.toJson()).toList(),
    'navigation': navigation?.toJson(),
  };

  factory InterfaceDefinition.fromJson(Map<String, dynamic> json) {
    return InterfaceDefinition(
      screens:
          (json['screens'] as List?)
              ?.map((s) => InterfaceScreen.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      navigation: json['navigation'] != null
          ? NavigationDefinition.fromJson(
              json['navigation'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// A screen in the interface.
class InterfaceScreen {
  final String id;
  final String title;
  final List<InterfaceNode> children;
  final String? appBarTitle;

  const InterfaceScreen({
    required this.id,
    required this.title,
    this.children = const [],
    this.appBarTitle,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'children': children.map((c) => c.toJson()).toList(),
    'appBarTitle': appBarTitle,
  };

  factory InterfaceScreen.fromJson(Map<String, dynamic> json) {
    return InterfaceScreen(
      id: json['id'] as String,
      title: json['title'] as String,
      children:
          (json['children'] as List?)
              ?.map((c) => InterfaceNode.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      appBarTitle: json['appBarTitle'] as String?,
    );
  }
}

/// A node in the interface tree.
class InterfaceNode {
  final String type;
  final String id;
  final Map<String, dynamic> properties;
  final List<InterfaceNode> children;
  final String? stateBinding;
  final ActionBinding? actionBinding;

  const InterfaceNode({
    required this.type,
    required this.id,
    this.properties = const {},
    this.children = const [],
    this.stateBinding,
    this.actionBinding,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'properties': properties,
    'children': children.map((c) => c.toJson()).toList(),
    'stateBinding': stateBinding,
    'actionBinding': actionBinding?.toJson(),
  };

  factory InterfaceNode.fromJson(Map<String, dynamic> json) {
    return InterfaceNode(
      type: json['type'] as String,
      id: json['id'] as String,
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      children:
          (json['children'] as List?)
              ?.map((c) => InterfaceNode.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      stateBinding: json['stateBinding'] as String?,
      actionBinding: json['actionBinding'] != null
          ? ActionBinding.fromJson(
              json['actionBinding'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Action binding for a node.
class ActionBinding {
  final String actionId;
  final Map<String, dynamic> parameters;

  const ActionBinding({required this.actionId, this.parameters = const {}});

  Map<String, dynamic> toJson() => {
    'actionId': actionId,
    'parameters': parameters,
  };

  factory ActionBinding.fromJson(Map<String, dynamic> json) {
    return ActionBinding(
      actionId: json['actionId'] as String,
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
    );
  }
}

/// Navigation definition.
class NavigationDefinition {
  final String type;
  final List<NavigationItem> items;

  const NavigationDefinition({required this.type, this.items = const []});

  Map<String, dynamic> toJson() => {
    'type': type,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory NavigationDefinition.fromJson(Map<String, dynamic> json) {
    return NavigationDefinition(
      type: json['type'] as String,
      items:
          (json['items'] as List?)
              ?.map((i) => NavigationItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class NavigationItem {
  final String label;
  final String icon;
  final String screenId;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.screenId,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'icon': icon,
    'screenId': screenId,
  };

  factory NavigationItem.fromJson(Map<String, dynamic> json) {
    return NavigationItem(
      label: json['label'] as String,
      icon: json['icon'] as String,
      screenId: json['screenId'] as String,
    );
  }
}

/// Behavior graph — declarative application logic.
class BehaviorGraph {
  final List<BehaviorNode> nodes;
  final List<BehaviorEdge> edges;

  const BehaviorGraph({this.nodes = const [], this.edges = const []});

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
  };

  factory BehaviorGraph.fromJson(Map<String, dynamic> json) {
    return BehaviorGraph(
      nodes:
          (json['nodes'] as List?)
              ?.map((n) => BehaviorNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      edges:
          (json['edges'] as List?)
              ?.map((e) => BehaviorEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BehaviorNode {
  final String id;
  final String type;
  final Map<String, dynamic> config;

  const BehaviorNode({
    required this.id,
    required this.type,
    this.config = const {},
  });

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'config': config};

  factory BehaviorNode.fromJson(Map<String, dynamic> json) {
    return BehaviorNode(
      id: json['id'] as String,
      type: json['type'] as String,
      config: Map<String, dynamic>.from(json['config'] ?? {}),
    );
  }
}

class BehaviorEdge {
  final String from;
  final String to;
  final String? condition;

  const BehaviorEdge({required this.from, required this.to, this.condition});

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'condition': condition,
  };

  factory BehaviorEdge.fromJson(Map<String, dynamic> json) {
    return BehaviorEdge(
      from: json['from'] as String,
      to: json['to'] as String,
      condition: json['condition'] as String?,
    );
  }
}

/// State schema.
class StateSchema {
  final List<StateVariable> variables;

  const StateSchema({this.variables = const []});

  Map<String, dynamic> toJson() => {
    'variables': variables.map((v) => v.toJson()).toList(),
  };

  factory StateSchema.fromJson(Map<String, dynamic> json) {
    return StateSchema(
      variables:
          (json['variables'] as List?)
              ?.map((v) => StateVariable.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class StateVariable {
  final String id;
  final String type;
  final dynamic defaultValue;
  final String persistence;

  const StateVariable({
    required this.id,
    required this.type,
    this.defaultValue,
    this.persistence = 'session',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'defaultValue': defaultValue,
    'persistence': persistence,
  };

  factory StateVariable.fromJson(Map<String, dynamic> json) {
    return StateVariable(
      id: json['id'] as String,
      type: json['type'] as String,
      defaultValue: json['defaultValue'],
      persistence: json['persistence'] as String? ?? 'session',
    );
  }
}

/// Data schema for structured persistence.
class DataSchema {
  final List<DataEntitySchema> entities;
  final int schemaVersion;

  const DataSchema({this.entities = const [], this.schemaVersion = 1});

  Map<String, dynamic> toJson() => {
    'entities': entities.map((e) => e.toJson()).toList(),
    'schemaVersion': schemaVersion,
  };

  factory DataSchema.fromJson(Map<String, dynamic> json) {
    return DataSchema(
      entities:
          (json['entities'] as List?)
              ?.map((e) => DataEntitySchema.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }
}

class DataEntitySchema {
  final String id;
  final String name;
  final List<DataFieldSchema> fields;

  const DataEntitySchema({
    required this.id,
    required this.name,
    this.fields = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fields': fields.map((f) => f.toJson()).toList(),
  };

  factory DataEntitySchema.fromJson(Map<String, dynamic> json) {
    return DataEntitySchema(
      id: json['id'] as String? ?? 'entity_${json['name']}',
      name: json['name'] as String,
      fields:
          (json['fields'] as List?)
              ?.map((f) => DataFieldSchema.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DataFieldSchema {
  final String id;
  final String name;
  final String type;
  final bool required;
  final dynamic defaultValue;
  final String? referenceEntityId;
  final List<String> allowedValues;
  final int? minLength;
  final int? maxLength;
  final num? minimum;
  final num? maximum;
  final String? hint;

  const DataFieldSchema({
    required this.id,
    required this.name,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.referenceEntityId,
    this.allowedValues = const [],
    this.minLength,
    this.maxLength,
    this.minimum,
    this.maximum,
    this.hint,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'required': required,
    'defaultValue': defaultValue,
    if (referenceEntityId != null) 'referenceEntityId': referenceEntityId,
    if (allowedValues.isNotEmpty) 'allowedValues': allowedValues,
    if (minLength != null) 'minLength': minLength,
    if (maxLength != null) 'maxLength': maxLength,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (hint != null) 'hint': hint,
  };

  factory DataFieldSchema.fromJson(Map<String, dynamic> json) {
    return DataFieldSchema(
      id: json['id'] as String? ?? 'field_${json['name']}',
      name: json['name'] as String,
      type: json['type'] as String,
      required: json['required'] as bool? ?? true,
      defaultValue: json['defaultValue'],
      referenceEntityId: json['referenceEntityId'] as String?,
      allowedValues: (json['allowedValues'] as List?)?.cast<String>() ?? [],
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      hint: json['hint'] as String?,
    );
  }
}

/// Service definition.
class ServiceDefinition {
  final String id;
  final String type;
  final Map<String, dynamic> config;

  const ServiceDefinition({
    required this.id,
    required this.type,
    this.config = const {},
  });

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'config': config};

  factory ServiceDefinition.fromJson(Map<String, dynamic> json) {
    return ServiceDefinition(
      id: json['id'] as String,
      type: json['type'] as String,
      config: Map<String, dynamic>.from(json['config'] ?? {}),
    );
  }
}

/// Network declaration.
class NetworkDeclaration {
  final String purpose;
  final List<String> allowedHosts;
  final bool requiresCredential;

  const NetworkDeclaration({
    required this.purpose,
    this.allowedHosts = const [],
    this.requiresCredential = false,
  });

  Map<String, dynamic> toJson() => {
    'purpose': purpose,
    'allowedHosts': allowedHosts,
    'requiresCredential': requiresCredential,
  };

  factory NetworkDeclaration.fromJson(Map<String, dynamic> json) {
    return NetworkDeclaration(
      purpose: json['purpose'] as String,
      allowedHosts: List<String>.from(json['allowedHosts'] ?? []),
      requiresCredential: json['requiresCredential'] as bool? ?? false,
    );
  }
}

/// Capability declaration.
class CapabilityDeclaration {
  final String capabilityId;
  final bool isRequired;

  const CapabilityDeclaration({
    required this.capabilityId,
    this.isRequired = true,
  });

  Map<String, dynamic> toJson() => {
    'capabilityId': capabilityId,
    'isRequired': isRequired,
  };

  factory CapabilityDeclaration.fromJson(Map<String, dynamic> json) {
    return CapabilityDeclaration(
      capabilityId: json['capabilityId'] as String,
      isRequired: json['isRequired'] as bool? ?? true,
    );
  }
}

/// Permission declaration.
class PermissionDeclaration {
  final String permission;
  final String reason;

  const PermissionDeclaration({required this.permission, required this.reason});

  Map<String, dynamic> toJson() => {'permission': permission, 'reason': reason};

  factory PermissionDeclaration.fromJson(Map<String, dynamic> json) {
    return PermissionDeclaration(
      permission: json['permission'] as String,
      reason: json['reason'] as String,
    );
  }
}

/// Protection metadata.
class ProtectionMetadata {
  final bool required;
  final String? mode;
  final String? protocolVersion;

  const ProtectionMetadata({
    this.required = false,
    this.mode,
    this.protocolVersion,
  });

  Map<String, dynamic> toJson() => {
    'required': required,
    'mode': mode,
    'protocolVersion': protocolVersion,
  };

  factory ProtectionMetadata.fromJson(Map<String, dynamic> json) {
    return ProtectionMetadata(
      required: json['required'] as bool? ?? false,
      mode: json['mode'] as String?,
      protocolVersion: json['protocolVersion'] as String?,
    );
  }
}

/// Package provenance.
class PackageProvenance {
  final List<String> resourcesConsulted;
  final List<String> packagesSelected;
  final String? modelProvider;
  final String creationEngineVersion;
  final int specVersion;
  final int planVersion;

  const PackageProvenance({
    this.resourcesConsulted = const [],
    this.packagesSelected = const [],
    this.modelProvider,
    required this.creationEngineVersion,
    required this.specVersion,
    required this.planVersion,
  });

  Map<String, dynamic> toJson() => {
    'resourcesConsulted': resourcesConsulted,
    'packagesSelected': packagesSelected,
    'modelProvider': modelProvider,
    'creationEngineVersion': creationEngineVersion,
    'specVersion': specVersion,
    'planVersion': planVersion,
  };

  factory PackageProvenance.fromJson(Map<String, dynamic> json) {
    return PackageProvenance(
      resourcesConsulted: List<String>.from(json['resourcesConsulted'] ?? []),
      packagesSelected: List<String>.from(json['packagesSelected'] ?? []),
      modelProvider: json['modelProvider'] as String?,
      creationEngineVersion: json['creationEngineVersion'] as String,
      specVersion: json['specVersion'] as int,
      planVersion: json['planVersion'] as int,
    );
  }
}

/// Package integrity metadata.
class PackageIntegrity {
  final String contentHash;
  final DateTime computedAt;

  const PackageIntegrity({required this.contentHash, required this.computedAt});

  Map<String, dynamic> toJson() => {
    'contentHash': contentHash,
    'computedAt': computedAt.toIso8601String(),
  };

  factory PackageIntegrity.fromJson(Map<String, dynamic> json) {
    return PackageIntegrity(
      contentHash: json['contentHash'] as String,
      computedAt: DateTime.parse(json['computedAt'] as String),
    );
  }
}
