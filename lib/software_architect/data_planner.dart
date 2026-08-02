/// Data Planner — orchestrates EntityPlanner, FieldPlanner,
/// RelationshipPlanner, and StoragePlanner over a SemanticApp.
///
/// Every decision here is derived from the entity/field *shape* the
/// reasoner already produced (types, required-ness, bounds, references) —
/// never from an entity or field's name.
library;

import '../synthesis/application_reasoner.dart';
import 'architecture_types.dart';
import 'confidence.dart';

class StoragePlanner {
  const StoragePlanner();

  /// Every entity with persisted fields is stored via the real production
  /// storage layer (ExperienceDatabase / SQLite) — this mirrors, and does
  /// not reinvent, lib/storage/experience_database.dart's actual design.
  ArchitectureDecision planEntityStorage(SemanticEntity entity) {
    final kind = entity.fields.isEmpty
        ? StorageKind.memory
        : StorageKind.sqlite;
    return ArchitectureDecision(
      id: 'storage:${entity.id}',
      category: ArchitectureDecisionCategory.storage,
      subjectId: entity.id,
      decision: kind == StorageKind.sqlite
          ? 'Persist ${entity.name} records via SQLite'
          : 'Keep ${entity.name} in memory only (no fields to persist)',
      rationale: kind == StorageKind.sqlite
          ? '${entity.fields.length} field(s) declared; the production '
                'runtime persists every entity through '
                'ExperienceDatabase, one generic SQLite-backed table.'
          : 'An entity with zero fields carries no persistable state.',
      confidence: Confidence.full,
      offlineImplication:
          'SQLite persistence is fully local — no network dependency.',
    );
  }

  StorageKind kindFor(SemanticEntity entity) =>
      entity.fields.isEmpty ? StorageKind.memory : StorageKind.sqlite;
}

class EntityPlanner {
  final StoragePlanner _storage;
  const EntityPlanner({StoragePlanner storage = const StoragePlanner()})
    : _storage = storage;

  List<EntityDecision> plan(List<SemanticEntity> entities) {
    return entities.map((entity) {
      return EntityDecision(
        entityId: entity.id,
        name: entity.name,
        fieldCount: entity.fields.length,
        storage: _storage.kindFor(entity),
        storageDecision: _storage.planEntityStorage(entity),
      );
    }).toList();
  }
}

class FieldPlanner {
  const FieldPlanner();

  List<FieldDecision> plan(List<SemanticEntity> entities) {
    final decisions = <FieldDecision>[];
    for (final entity in entities) {
      for (final field in entity.fields) {
        final hasBounds =
            field.required ||
            field.minimum != null ||
            field.maximum != null ||
            field.minLength != null ||
            field.maxLength != null ||
            field.allowedValues.isNotEmpty;
        decisions.add(
          FieldDecision(
            entityId: entity.id,
            fieldId: field.id,
            name: field.name,
            validationDecision: ArchitectureDecision(
              id: 'field:${entity.id}.${field.id}',
              category: ArchitectureDecisionCategory.field,
              subjectId: '${entity.id}.${field.id}',
              decision: hasBounds
                  ? '${field.name} carries explicit validation bounds'
                  : '${field.name} is unconstrained',
              rationale: hasBounds
                  ? 'Declared as required=${field.required}, '
                        'min=${field.minimum ?? field.minLength}, '
                        'max=${field.maximum ?? field.maxLength}, '
                        'allowedValues=${field.allowedValues.length}.'
                  : 'No required/min/max/allowedValues declared for this field.',
              confidence: Confidence(
                score: field.description.isNotEmpty ? 1.0 : 0.7,
                reason: field.description.isNotEmpty
                    ? 'Field has an explicit description in addition to its type.'
                    : 'Field has a type but no description — plausible but unconfirmed intent.',
              ),
            ),
          ),
        );
      }
    }
    return decisions;
  }
}

class RelationshipPlanner {
  const RelationshipPlanner();

  List<RelationshipDecision> plan(List<SemanticEntity> entities) {
    final decisions = <RelationshipDecision>[];
    for (final entity in entities) {
      for (final field in entity.fields) {
        if (field.referenceEntityId == null) continue;
        // A required reference cannot be silently orphaned -> restrict.
        // An optional reference may be cleared -> setNull. Both are real,
        // generic policies (see docs/audit/V2_SECURITY_AUDIT.md §12 for
        // why "no cascade" is the deliberate default), never
        // domain-specific.
        final policy = field.required
            ? RelationshipDeletePolicy.restrict
            : RelationshipDeletePolicy.setNull;
        decisions.add(
          RelationshipDecision(
            fromEntityId: entity.id,
            toEntityId: field.referenceEntityId!,
            fieldId: field.id,
            deletePolicy: policy,
            decision: ArchitectureDecision(
              id: 'relationship:${entity.id}.${field.id}',
              category: ArchitectureDecisionCategory.relationship,
              subjectId: '${entity.id}.${field.id}',
              decision: policy == RelationshipDeletePolicy.restrict
                  ? 'Restrict deletion of ${field.referenceEntityId} while referenced'
                  : 'Clear reference on ${field.referenceEntityId} deletion',
              rationale: field.required
                  ? '${field.name} is a required reference; the '
                        'referenced record must not be allowed to vanish '
                        'out from under it.'
                  : '${field.name} is an optional reference; clearing it '
                        'on delete is safe and avoids blocking deletion.',
              confidence: Confidence.full,
            ),
          ),
        );
      }
    }
    return decisions;
  }
}
