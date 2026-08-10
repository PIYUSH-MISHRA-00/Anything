/// Experience Package Validator.
///
/// Validates structure, references, limits, component tree budgets, and integrity.
library;

import 'dart:convert';

import 'experience_package.dart';
import '../runtime/component_registry.dart';
import '../security/runtime_security_limits.dart';

/// Validation result.
class PackageValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const PackageValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory PackageValidationResult.valid() =>
      const PackageValidationResult(isValid: true);
  factory PackageValidationResult.invalid(List<String> errors) =>
      PackageValidationResult(isValid: false, errors: errors);
}

/// Validates ExperiencePackage structure and content.
class ExperiencePackageValidator {
  /// Validate a package.
  static PackageValidationResult validate(ExperiencePackage package) {
    final errors = <String>[];
    final warnings = <String>[];

    // Reject oversized packages first, before any structural walk — a
    // generated package must not be allowed to force expensive processing
    // just by being huge (e.g. a pathological string outside the component
    // tree, such as provenance/metadata blobs).
    final serializedBytes = utf8.encode(jsonEncode(package.toJson())).length;
    if (serializedBytes > RuntimeSecurityLimits.maxPackageBytes) {
      return PackageValidationResult.invalid([
        'package_size_exceeded: serialized package is $serializedBytes bytes '
            '(max ${RuntimeSecurityLimits.maxPackageBytes})',
      ]);
    }

    // Validate version
    if (package.packageVersion > experiencePackageVersion) {
      errors.add('Package version ${package.packageVersion} not supported');
    }

    // Validate manifest
    if (package.manifest.experienceId.isEmpty) {
      errors.add('Manifest missing experienceId');
    }
    if (package.manifest.name.isEmpty) {
      errors.add('Manifest missing name');
    }
    if (package.manifest.name.length >
        RuntimeSecurityLimits.maxMetadataFieldLength) {
      errors.add(
        'metadata_field_too_long: manifest name exceeds '
        '${RuntimeSecurityLimits.maxMetadataFieldLength} characters',
      );
    }
    if (package.manifest.description.length >
        RuntimeSecurityLimits.maxMetadataFieldLength) {
      errors.add(
        'metadata_field_too_long: manifest description exceeds '
        '${RuntimeSecurityLimits.maxMetadataFieldLength} characters',
      );
    }

    // Validate interface
    if (package.interface.screens.isEmpty) {
      warnings.add('Package has no screens');
    }
    if (package.interface.screens.length >
        RuntimeSecurityLimits.maxScreensPerPackage) {
      errors.add(
        'ui_screen_count_exceeded: package has '
        '${package.interface.screens.length} screens '
        '(max ${RuntimeSecurityLimits.maxScreensPerPackage})',
      );
    }

    // Validate component tree budgets for each screen
    for (final screen in package.interface.screens) {
      final treeErrors = ComponentTreeValidator.validateScreen(screen);
      errors.addAll(treeErrors);
    }

    // Validate behavior
    if (package.behavior.nodes.isEmpty) {
      warnings.add('Package has no behavior nodes');
    }
    if (package.behavior.nodes.length >
        RuntimeSecurityLimits.maxBehaviorNodesPerPackage) {
      errors.add(
        'behavior_node_count_exceeded: package declares '
        '${package.behavior.nodes.length} behavior nodes '
        '(max ${RuntimeSecurityLimits.maxBehaviorNodesPerPackage})',
      );
    }

    // Validate state references in behavior
    final stateIds = package.state.variables.map((v) => v.id).toSet();
    for (final node in package.behavior.nodes) {
      if (node.config.containsKey('stateRef')) {
        final ref = node.config['stateRef'] as String;
        if (!stateIds.contains(ref)) {
          errors.add('Behavior node ${node.id} references unknown state: $ref');
        }
      }
    }

    // Validate data references
    if (package.data != null) {
      final entityNames = package.data!.entities.map((e) => e.name).toSet();
      for (final node in package.behavior.nodes) {
        if (node.config.containsKey('dataRef')) {
          final ref = node.config['dataRef'] as String;
          if (!entityNames.contains(ref)) {
            errors.add(
              'Behavior node ${node.id} references unknown data entity: $ref',
            );
          }
        }
      }
    }

    // Validate integrity
    if (package.integrity.contentHash.isEmpty) {
      warnings.add('Package missing integrity hash');
    }

    // IS-P08 quality gate: every visible create/update control must resolve
    // to a form that can collect values. A button that dispatches create with
    // no destination is the exact "Add task does nothing" defect — reject it
    // before install rather than shipping a dead control.
    errors.addAll(_validateActionDestinations(package));

    return PackageValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Create/update actions bound to UI must have a resolvable entityForm.
  static List<String> _validateActionDestinations(ExperiencePackage package) {
    final errors = <String>[];

    bool hasForm(String entityId, String mode) {
      for (final screen in package.interface.screens) {
        for (final node in _walk(screen.children)) {
          if (node.type == 'entityForm' &&
              node.properties['entityId'] == entityId &&
              node.properties['mode'] == mode) {
            return true;
          }
        }
      }
      return false;
    }

    for (final screen in package.interface.screens) {
      for (final node in _walk(screen.children)) {
        final binding = node.actionBinding;
        if (binding == null) continue;
        final entityId = binding.parameters['entityId']?.toString();
        if (entityId == null || entityId.isEmpty) continue;

        final actionId = binding.actionId.toLowerCase();
        final looksCreate =
            actionId.contains('create') ||
            actionId.contains('add') ||
            actionId.startsWith('new');
        final looksUpdate =
            actionId.contains('update') ||
            actionId.contains('edit') ||
            actionId.contains('modify');

        if (looksCreate && !hasForm(entityId, 'create')) {
          errors.add(
            'dead_create_action: control "${node.id}" binds '
            '"${binding.actionId}" for entity "$entityId" but no create '
            'form exists',
          );
        }
        if (looksUpdate && !hasForm(entityId, 'edit')) {
          errors.add(
            'dead_update_action: control "${node.id}" binds '
            '"${binding.actionId}" for entity "$entityId" but no edit '
            'form exists',
          );
        }
      }
    }
    return errors;
  }

  static Iterable<InterfaceNode> _walk(List<InterfaceNode> roots) sync* {
    for (final node in roots) {
      yield node;
      yield* _walk(node.children);
    }
  }
}

/// Validates InterfaceNode trees against trusted component budget limits.
///
/// Depth semantics: root node is depth 0.
/// Maximum legal depth = RuntimeComponentRegistry.maxDepth (20).
/// A tree with root at depth 0 and deepest leaf at depth 20 is valid.
/// A tree with a node at depth 21 is invalid.
class ComponentTreeValidator {
  /// Validate a screen's node tree against budget limits.
  static List<String> validateScreen(InterfaceScreen screen) {
    final errors = <String>[];
    int totalNodes = 0;

    for (final child in screen.children) {
      _validateNode(child, 0, errors, () => totalNodes++);
    }

    if (totalNodes > RuntimeComponentRegistry.maxTotalComponents) {
      errors.add(
        'ui_component_count_exceeded: screen "${screen.id}" has $totalNodes components '
        '(max ${RuntimeComponentRegistry.maxTotalComponents})',
      );
    }

    return errors;
  }

  static void _validateNode(
    InterfaceNode node,
    int depth,
    List<String> errors,
    void Function() countNode,
  ) {
    countNode();

    // Depth check: root is depth 0, max allowed is maxDepth
    if (depth > RuntimeComponentRegistry.maxDepth) {
      errors.add(
        'ui_depth_exceeded: node "${node.id}" at depth $depth '
        '(max ${RuntimeComponentRegistry.maxDepth})',
      );
      // Still count children for total but don't recurse further to avoid
      // exponential error spam
      return;
    }

    // Children count check
    if (node.children.length > RuntimeComponentRegistry.maxChildrenPerNode) {
      errors.add(
        'ui_children_exceeded: node "${node.id}" has ${node.children.length} children '
        '(max ${RuntimeComponentRegistry.maxChildrenPerNode})',
      );
    }

    // Property text size check — a generated node must not smuggle a
    // multi-megabyte string into a presentation property.
    for (final entry in node.properties.entries) {
      final value = entry.value;
      if (value is String &&
          value.length > RuntimeSecurityLimits.maxComponentPropertyTextLength) {
        errors.add(
          'ui_property_text_too_long: node "${node.id}" property '
          '"${entry.key}" exceeds '
          '${RuntimeSecurityLimits.maxComponentPropertyTextLength} characters',
        );
      }
    }

    // Recurse into children
    for (final child in node.children) {
      _validateNode(child, depth + 1, errors, countNode);
    }
  }
}

// `experiencePackageVersion` was ALSO declared here, shadowing the canonical
// `const int experiencePackageVersion = 1` in experience_package.dart (which
// this library already imports). Two independent sources of truth for the
// package-format version: bump one and the validator silently kept enforcing
// the other. Removed in IS-R54 — found because a new importer of both
// libraries could not compile (`ambiguous_import`), which is the only reason
// this was ever visible. No consumer imported it from here.
