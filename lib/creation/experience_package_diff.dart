/// Experience Diff — Implementation Milestone R4's fourth and final diff
/// stage, planning-only (see `requirement_graph_diff.dart` for the
/// established scope statement — this file computes what changed,
/// never applies it to a running Experience; runtime patching stays out
/// of scope for this milestone).
///
/// Operates on `ExperiencePackage` (the real, persisted artifact) rather
/// than `ExperienceSpec` (a transient, Kernel-internal, per-request type)
/// — this is what `ExperienceModificationCoordinator` actually has a real
/// "before" and "after" instance of, matching the spec's own named
/// dimensions (component/screen additions, capability additions, schema/
/// storage changes) far more directly than the higher-level spec would.
/// Mirrors the same id-keyed, explicit-remove+add-pair pattern the other
/// three diff types already established.
library;

import 'experience_package.dart';

class ExperienceDiff {
  final List<InterfaceScreen> addedScreens;
  final List<InterfaceScreen> removedScreens;
  final List<InterfaceNode> addedComponents;
  final List<InterfaceNode> removedComponents;
  final List<CapabilityDeclaration> addedCapabilities;
  final List<CapabilityDeclaration> removedCapabilities;
  final List<ServiceDefinition> addedServices;
  final List<ServiceDefinition> removedServices;
  final bool behaviorChanged;
  final bool stateChanged;
  final bool dataSchemaChanged;

  const ExperienceDiff({
    this.addedScreens = const [],
    this.removedScreens = const [],
    this.addedComponents = const [],
    this.removedComponents = const [],
    this.addedCapabilities = const [],
    this.removedCapabilities = const [],
    this.addedServices = const [],
    this.removedServices = const [],
    this.behaviorChanged = false,
    this.stateChanged = false,
    this.dataSchemaChanged = false,
  });

  bool get isEmpty =>
      addedScreens.isEmpty &&
      removedScreens.isEmpty &&
      addedComponents.isEmpty &&
      removedComponents.isEmpty &&
      addedCapabilities.isEmpty &&
      removedCapabilities.isEmpty &&
      addedServices.isEmpty &&
      removedServices.isEmpty &&
      !behaviorChanged &&
      !stateChanged &&
      !dataSchemaChanged;

  static const ExperienceDiff empty = ExperienceDiff();
}

class ExperienceDiffer {
  const ExperienceDiffer();

  ExperienceDiff diff(ExperiencePackage before, ExperiencePackage after) {
    final beforeScreens = {for (final s in before.interface.screens) s.id: s};
    final afterScreens = {for (final s in after.interface.screens) s.id: s};

    final addedScreens = <InterfaceScreen>[];
    final removedScreens = <InterfaceScreen>[];
    for (final entry in afterScreens.entries) {
      final beforeScreen = beforeScreens[entry.key];
      if (beforeScreen == null || beforeScreen.title != entry.value.title) {
        if (beforeScreen != null) removedScreens.add(beforeScreen);
        addedScreens.add(entry.value);
      }
    }
    for (final entry in beforeScreens.entries) {
      if (!afterScreens.containsKey(entry.key)) removedScreens.add(entry.value);
    }

    // Components are compared across the WHOLE tree (flattened), by id —
    // real screen membership/nesting isn't part of this diff's scope
    // (a component moving screens shows as remove+add, an honest,
    // conservative choice consistent with "never silently merge").
    final beforeComponents = <String, InterfaceNode>{};
    for (final screen in before.interface.screens) {
      _flatten(screen.children, beforeComponents);
    }
    final afterComponents = <String, InterfaceNode>{};
    for (final screen in after.interface.screens) {
      _flatten(screen.children, afterComponents);
    }
    final addedComponents = <InterfaceNode>[];
    final removedComponents = <InterfaceNode>[];
    for (final entry in afterComponents.entries) {
      final beforeNode = beforeComponents[entry.key];
      if (beforeNode == null || beforeNode.type != entry.value.type) {
        if (beforeNode != null) removedComponents.add(beforeNode);
        addedComponents.add(entry.value);
      }
    }
    for (final entry in beforeComponents.entries) {
      if (!afterComponents.containsKey(entry.key)) removedComponents.add(entry.value);
    }

    final beforeCaps = {for (final c in before.capabilityDeclarations) c.capabilityId: c};
    final afterCaps = {for (final c in after.capabilityDeclarations) c.capabilityId: c};
    final addedCapabilities = afterCaps.entries.where((e) => !beforeCaps.containsKey(e.key)).map((e) => e.value).toList();
    final removedCapabilities = beforeCaps.entries.where((e) => !afterCaps.containsKey(e.key)).map((e) => e.value).toList();

    final beforeServices = {for (final s in before.services) s.id: s};
    final afterServices = {for (final s in after.services) s.id: s};
    final addedServices = afterServices.entries.where((e) => !beforeServices.containsKey(e.key)).map((e) => e.value).toList();
    final removedServices = beforeServices.entries.where((e) => !afterServices.containsKey(e.key)).map((e) => e.value).toList();

    return ExperienceDiff(
      addedScreens: addedScreens,
      removedScreens: removedScreens,
      addedComponents: addedComponents,
      removedComponents: removedComponents,
      addedCapabilities: addedCapabilities,
      removedCapabilities: removedCapabilities,
      addedServices: addedServices,
      removedServices: removedServices,
      behaviorChanged: before.behavior.toJson().toString() != after.behavior.toJson().toString(),
      stateChanged: before.state.toJson().toString() != after.state.toJson().toString(),
      dataSchemaChanged: before.data?.toJson().toString() != after.data?.toJson().toString(),
    );
  }

  void _flatten(List<InterfaceNode> nodes, Map<String, InterfaceNode> out) {
    for (final node in nodes) {
      out[node.id] = node;
      if (node.children.isNotEmpty) _flatten(node.children, out);
    }
  }
}
