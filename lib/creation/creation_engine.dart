/// Creation Engine — converts specifications into Experience Packages.
///
/// Takes CreationContext and produces ExperiencePackage.
/// Does NOT execute arbitrary code.
library;

import '../kernel/specification/experience_spec.dart';
import 'creation_context.dart';
import 'experience_package.dart';

/// Status of creation phases.
enum CreationPhase {
  prepare,
  design,
  buildInterface,
  buildBehavior,
  buildData,
  wireServices,
  validate,
  package,
  ready,
}

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

      // Check for unsupported requirements
      final unsupported = _checkUnsupported(spec, context);
      if (unsupported.isNotEmpty) {
        return CreationUnsupported(
          unsupportedRequirements: unsupported,
          message: 'Some requirements cannot be met yet',
          timestamp: DateTime.now(),
        );
      }

      // Build interface
      final interface = _buildInterface(spec);

      // Build behavior
      final behavior = _buildBehavior(spec);

      // Build state
      final state = _buildState(spec);

      // Build data schema if needed
      DataSchema? data;
      if (spec.storageRequirements.requiresDatabase) {
        data = _buildDataSchema(spec);
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
}
