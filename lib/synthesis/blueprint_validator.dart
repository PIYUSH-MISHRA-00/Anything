/// Blueprint Validator — validates AppBlueprints before synthesis.
///
/// Ensures the blueprint is structurally sound, has valid references,
/// meets security limits, and can be safely synthesized into an ExperiencePackage.
library;

import 'app_archetype.dart';
import 'app_blueprint.dart';

/// Validation result for a blueprint.
class BlueprintValidation {
  const BlueprintValidation({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  static const valid = BlueprintValidation(isValid: true);
}

/// Security limits for synthesized blueprints.
class BlueprintLimits {
  static const maxEntities = 10;
  static const maxFieldsPerEntity = 20;
  static const maxViews = 20;
  static const maxActions = 50;
  static const maxDerivedValues = 20;
  static const maxCapabilities = 10;
  static const maxViewSections = 10;
}

/// Validates AppBlueprints for structural integrity and security.
class BlueprintValidator {
  /// Validate a blueprint for synthesis readiness.
  static BlueprintValidation validate(AppBlueprint blueprint) {
    final errors = <String>[];
    final warnings = <String>[];

    _validateIdentity(blueprint, errors);
    _validateArchetypes(blueprint, errors);
    _validateEntities(blueprint, errors, warnings);
    _validateViews(blueprint, errors, warnings);
    _validateActions(blueprint, errors, warnings);
    _validateDerivedValues(blueprint, errors, warnings);
    _validateReferences(blueprint, errors);
    _validateLimits(blueprint, errors);
    _validateNetworkConsistency(blueprint, warnings);

    return BlueprintValidation(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  static void _validateIdentity(AppBlueprint blueprint, List<String> errors) {
    if (blueprint.id.isEmpty) errors.add('Blueprint ID is required');
    if (blueprint.name.isEmpty) errors.add('Blueprint name is required');
    if (blueprint.name.length > 100) {
      errors.add('Blueprint name must be 100 characters or fewer');
    }
    if (blueprint.description.length > 500) {
      errors.add('Blueprint description must be 500 characters or fewer');
    }
  }

  static void _validateArchetypes(AppBlueprint blueprint, List<String> errors) {
    if (blueprint.archetypes.isEmpty) {
      errors.add('At least one archetype is required');
    }
  }

  static void _validateEntities(
    AppBlueprint blueprint,
    List<String> errors,
    List<String> warnings,
  ) {
    if (blueprint.entities.isEmpty) {
      if (!blueprint.archetypes.contains(AppArchetype.utility)) {
        warnings.add('No entities defined for non-utility app');
      }
    }

    final entityIds = <String>{};
    for (final entity in blueprint.entities) {
      if (entity.id.isEmpty) {
        errors.add('Entity ID is required');
        continue;
      }
      if (entityIds.contains(entity.id)) {
        errors.add('Duplicate entity ID: ${entity.id}');
      }
      entityIds.add(entity.id);

      if (entity.name.isEmpty) {
        errors.add('Entity name is required for ${entity.id}');
      }

      if (entity.fields.isEmpty) {
        errors.add('Entity ${entity.id} has no fields');
      }

      for (final field in entity.fields) {
        if (field.id.isEmpty) {
          errors.add('Field ID is required in entity ${entity.id}');
        }
        if (field.name.isEmpty) {
          errors.add('Field name is required for ${field.id} in ${entity.id}');
        }
      }
    }
  }

  static void _validateViews(
    AppBlueprint blueprint,
    List<String> errors,
    List<String> warnings,
  ) {
    if (blueprint.views.isEmpty) {
      warnings.add('No views defined');
    }

    final viewIds = <String>{};
    for (final view in blueprint.views) {
      if (view.id.isEmpty) {
        errors.add('View ID is required');
        continue;
      }
      if (viewIds.contains(view.id)) {
        errors.add('Duplicate view ID: ${view.id}');
      }
      viewIds.add(view.id);

      if (view.sections.length > BlueprintLimits.maxViewSections) {
        errors.add(
          'View ${view.id} exceeds max sections (${BlueprintLimits.maxViewSections})',
        );
      }
    }
  }

  static void _validateActions(
    AppBlueprint blueprint,
    List<String> errors,
    List<String> warnings,
  ) {
    if (blueprint.actions.isEmpty &&
        !blueprint.archetypes.contains(AppArchetype.utility)) {
      warnings.add('No actions defined for non-utility app');
    }

    final actionIds = <String>{};
    for (final action in blueprint.actions) {
      if (action.id.isEmpty) {
        errors.add('Action ID is required');
        continue;
      }
      if (actionIds.contains(action.id)) {
        errors.add('Duplicate action ID: ${action.id}');
      }
      actionIds.add(action.id);
    }
  }

  static void _validateDerivedValues(
    AppBlueprint blueprint,
    List<String> errors,
    List<String> warnings,
  ) {
    for (final dv in blueprint.derivedValues) {
      if (dv.id.isEmpty) {
        errors.add('Derived value ID is required');
        continue;
      }
      if (dv.sourceEntityId.isEmpty) {
        errors.add('Derived value ${dv.id} has no source entity');
      }
    }
  }

  static void _validateReferences(AppBlueprint blueprint, List<String> errors) {
    final entityIds = blueprint.entities.map((e) => e.id).toSet();

    // Validate action entity references
    for (final action in blueprint.actions) {
      if (!entityIds.contains(action.targetEntityId)) {
        errors.add(
          'Action ${action.id} references unknown entity ${action.targetEntityId}',
        );
      }
    }

    // Validate view entity references
    for (final view in blueprint.views) {
      if (view.sourceEntityId != null &&
          !entityIds.contains(view.sourceEntityId)) {
        errors.add(
          'View ${view.id} references unknown entity ${view.sourceEntityId}',
        );
      }
    }

    // Validate derived value entity references
    for (final dv in blueprint.derivedValues) {
      if (!entityIds.contains(dv.sourceEntityId)) {
        errors.add(
          'Derived value ${dv.id} references unknown entity ${dv.sourceEntityId}',
        );
      }
    }
  }

  static void _validateLimits(AppBlueprint blueprint, List<String> errors) {
    if (blueprint.entities.length > BlueprintLimits.maxEntities) {
      errors.add(
        'Too many entities (${blueprint.entities.length} > ${BlueprintLimits.maxEntities})',
      );
    }

    for (final entity in blueprint.entities) {
      if (entity.fields.length > BlueprintLimits.maxFieldsPerEntity) {
        errors.add(
          'Entity ${entity.id} has too many fields (${entity.fields.length} > ${BlueprintLimits.maxFieldsPerEntity})',
        );
      }
    }

    if (blueprint.views.length > BlueprintLimits.maxViews) {
      errors.add(
        'Too many views (${blueprint.views.length} > ${BlueprintLimits.maxViews})',
      );
    }

    if (blueprint.actions.length > BlueprintLimits.maxActions) {
      errors.add(
        'Too many actions (${blueprint.actions.length} > ${BlueprintLimits.maxActions})',
      );
    }

    if (blueprint.derivedValues.length > BlueprintLimits.maxDerivedValues) {
      errors.add(
        'Too many derived values (${blueprint.derivedValues.length} > ${BlueprintLimits.maxDerivedValues})',
      );
    }

    if (blueprint.requiredCapabilities.length >
        BlueprintLimits.maxCapabilities) {
      errors.add(
        'Too many capabilities (${blueprint.requiredCapabilities.length} > ${BlueprintLimits.maxCapabilities})',
      );
    }
  }

  static void _validateNetworkConsistency(
    AppBlueprint blueprint,
    List<String> warnings,
  ) {
    final needsNetwork = blueprint.networkConfig != null;
    final hasNetworkArchetype = blueprint.archetypes.contains(
      AppArchetype.reference,
    );

    if (hasNetworkArchetype && !needsNetwork) {
      warnings.add('Reference archetype without network configuration');
    }
    if (needsNetwork && blueprint.offlinePolicy == OfflinePolicy.full) {
      warnings.add(
        'Network configured but offline policy is full — consider partial',
      );
    }
  }
}
