/// Experience Package Validator.
///
/// Validates structure, references, limits, and integrity.
library;

import 'experience_package.dart';

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

const int experiencePackageVersion = 1;
