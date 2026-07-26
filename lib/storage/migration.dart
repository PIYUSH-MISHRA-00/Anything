/// Data migration architecture for Experience schemas.
library;

/// A migration operation using stable schema IDs.
class MigrationOperation {
  final MigrationOperationType type;
  final String entityId;
  final Map<String, dynamic> params;

  const MigrationOperation({
    required this.type,
    required this.entityId,
    this.params = const {},
  });
}

enum MigrationOperationType { addField, addEntity, addIndex }

/// A migration plan.
class DataMigrationPlan {
  final String experienceId;
  final int fromVersion;
  final int toVersion;
  final List<MigrationOperation> operations;

  const DataMigrationPlan({
    required this.experienceId,
    required this.fromVersion,
    required this.toVersion,
    required this.operations,
  });
}

/// Validates a migration plan.
class MigrationValidator {
  static MigrationValidationResult validate(DataMigrationPlan plan) {
    final errors = <String>[];

    if (plan.fromVersion >= plan.toVersion) {
      errors.add('Target version must be greater than source version');
    }

    if (plan.operations.isEmpty) {
      errors.add('Migration has no operations');
    }

    for (final op in plan.operations) {
      if (op.entityId.isEmpty) {
        errors.add('Migration operation has empty entity ID');
      }
    }

    return MigrationValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}

class MigrationValidationResult {
  final bool isValid;
  final List<String> errors;
  const MigrationValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}
