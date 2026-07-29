/// Experience Package Validator.
///
/// Validates structure, references, limits, component tree budgets, and integrity.
library;

import 'experience_package.dart';
import '../runtime/component_registry.dart';

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

    // Validate interface
    if (package.interface.screens.isEmpty) {
      warnings.add('Package has no screens');
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

    return PackageValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
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

    // Recurse into children
    for (final child in node.children) {
      _validateNode(child, depth + 1, errors, countNode);
    }
  }
}

const int experiencePackageVersion = 1;
