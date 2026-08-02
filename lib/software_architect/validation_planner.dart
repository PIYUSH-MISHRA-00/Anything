/// Validation Planner — derives typed, per-field validation rules
/// directly from the SemanticApp's own field bounds. No regex/rule text
/// is invented; every rule traces back to an explicit field property.
library;

import '../synthesis/application_reasoner.dart';
import 'architecture_types.dart';

class ValidationPlanner {
  const ValidationPlanner();

  List<ValidationRule> plan(List<SemanticEntity> entities) {
    final rules = <ValidationRule>[];
    for (final entity in entities) {
      for (final field in entity.fields) {
        if (field.required) {
          rules.add(
            ValidationRule(
              entityId: entity.id,
              fieldId: field.id,
              type: ValidationRuleType.required,
              description: '${field.name} is required',
            ),
          );
        }
        if (field.minLength != null) {
          rules.add(
            ValidationRule(
              entityId: entity.id,
              fieldId: field.id,
              type: ValidationRuleType.minLength,
              description:
                  '${field.name} must be at least ${field.minLength} characters',
            ),
          );
        }
        if (field.maxLength != null) {
          rules.add(
            ValidationRule(
              entityId: entity.id,
              fieldId: field.id,
              type: ValidationRuleType.maxLength,
              description:
                  '${field.name} must be at most ${field.maxLength} characters',
            ),
          );
        }
        if (field.minimum != null) {
          rules.add(
            ValidationRule(
              entityId: entity.id,
              fieldId: field.id,
              type: ValidationRuleType.minimum,
              description: '${field.name} must be >= ${field.minimum}',
            ),
          );
        }
        if (field.maximum != null) {
          rules.add(
            ValidationRule(
              entityId: entity.id,
              fieldId: field.id,
              type: ValidationRuleType.maximum,
              description: '${field.name} must be <= ${field.maximum}',
            ),
          );
        }
        if (field.allowedValues.isNotEmpty) {
          rules.add(
            ValidationRule(
              entityId: entity.id,
              fieldId: field.id,
              type: ValidationRuleType.allowedValues,
              description:
                  '${field.name} must be one of: ${field.allowedValues.join(', ')}',
            ),
          );
        }
        if (field.referenceEntityId != null && field.required) {
          rules.add(
            ValidationRule(
              entityId: entity.id,
              fieldId: field.id,
              type: ValidationRuleType.crossField,
              description:
                  '${field.name} must reference an existing ${field.referenceEntityId} record',
            ),
          );
        }
      }
    }
    return rules;
  }
}
