/// Architecture-to-Blueprint conversion — turns an approved
/// ArchitectureCandidate into the existing, already-certified AppBlueprint
/// type, so everything downstream (BlueprintToSpecConverter, CreationEngine,
/// ExperiencePackageValidator, AnythingRuntime) is completely unchanged.
///
/// Reuses SynthesisPlanner.convertToBlueprint (real, tested, certified —
/// not reimplemented here) as the base conversion, then applies exactly
/// the corrections RefinementPlanner actually made (entity disambiguation,
/// dropped dangling relationships) so refinement has a real, visible
/// effect on the final blueprint rather than being decorative.
library;

import '../synthesis/app_blueprint.dart';
import '../synthesis/application_reasoner.dart';
import '../synthesis/synthesis_planner.dart';
import 'architecture_candidate.dart';

class ArchitectureToBlueprintConverter {
  const ArchitectureToBlueprintConverter();

  AppBlueprint convert({
    required SemanticApp originalApp,
    required ArchitectureCandidate approved,
    required ApplicationReasoner reasonerForConversion,
  }) {
    final blueprint = SynthesisPlanner(
      reasonerForConversion,
    ).convertToBlueprint(originalApp);

    final renames = {
      for (final e in approved.entities)
        if (e.name != _originalNameOf(originalApp, e.entityId))
          e.entityId: e.name,
    };
    final droppedReferenceFields = _droppedReferenceFields(
      originalApp,
      approved,
    );

    if (renames.isEmpty && droppedReferenceFields.isEmpty) return blueprint;

    final correctedEntities = blueprint.entities.map((entity) {
      final newName = renames[entity.id];
      final fields = entity.fields.map((field) {
        final fieldKey = '${entity.id}.${field.id}';
        if (!droppedReferenceFields.contains(fieldKey)) return field;
        return BlueprintField(
          id: field.id,
          name: field.name,
          type: field.type,
          required: field.required,
          defaultValue: field.defaultValue,
          minimum: field.minimum,
          maximum: field.maximum,
          minLength: field.minLength,
          maxLength: field.maxLength,
          allowedValues: field.allowedValues,
          description: field.description,
          referenceEntityId: null,
        );
      }).toList();

      if (newName == null && identical(fields, entity.fields)) return entity;
      return BlueprintEntity(
        id: entity.id,
        name: newName ?? entity.name,
        description: entity.description,
        fields: fields,
        displayField: entity.displayField,
      );
    }).toList();

    return blueprint.copyWith(entities: correctedEntities);
  }

  String _originalNameOf(SemanticApp app, String entityId) {
    return app.entities
        .firstWhere((e) => e.id == entityId, orElse: () => app.entities.first)
        .name;
  }

  Set<String> _droppedReferenceFields(
    SemanticApp originalApp,
    ArchitectureCandidate approved,
  ) {
    final originalRefs = <String>{};
    for (final entity in originalApp.entities) {
      for (final field in entity.fields) {
        if (field.referenceEntityId != null) {
          originalRefs.add('${entity.id}.${field.id}');
        }
      }
    }
    final survivingRefs = approved.relationships
        .map((r) => '${r.fromEntityId}.${r.fieldId}')
        .toSet();
    return originalRefs.difference(survivingRefs);
  }
}
