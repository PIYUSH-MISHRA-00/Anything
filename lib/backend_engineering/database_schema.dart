/// Database Schema — Implementation Milestone R8. A real, typed,
/// deterministic representation of what a backend database for this
/// application would need: tables, columns, foreign keys. Derived
/// entirely from the SemanticEntity/SemanticField shape the reasoning
/// layer already produces — never SQL, never a migration script, never
/// executed. No Maps, no dynamic — every model is a real class,
/// matching this codebase's established typed-vocabulary discipline
/// (RequirementGraph, ArchitectureCandidate).
library;

/// A column's logical type — deliberately small and storage-agnostic
/// (this is a specification, not a dialect-specific SQL type list).
/// `derived` fields (BlueprintFieldType.derived) are NOT represented as
/// columns at all — a derived value is computed, not stored, matching
/// DataEngineering's own existing aggregation-decision treatment of
/// derived values.
enum DatabaseColumnType { text, integer, decimal, boolean, dateTime, reference }

class DatabaseColumn {
  final String id;
  final String name;
  final DatabaseColumnType type;
  final bool required;
  final bool isPrimaryKey;

  const DatabaseColumn({
    required this.id,
    required this.name,
    required this.type,
    this.required = false,
    this.isPrimaryKey = false,
  });
}

/// A foreign-key relationship between two tables — mirrors
/// `RelationshipDecision`'s already-real fromEntityId/toEntityId/
/// deletePolicy, never re-deciding delete policy independently.
class ForeignKeyConstraint {
  final String columnId;
  final String referencesTableId;
  final String
  onDelete; // 'restrict' | 'setNull' — mirrors RelationshipDeletePolicy.name

  const ForeignKeyConstraint({
    required this.columnId,
    required this.referencesTableId,
    required this.onDelete,
  });
}

class DatabaseTable {
  final String id;
  final String name;
  final List<DatabaseColumn> columns;
  final List<ForeignKeyConstraint> foreignKeys;

  const DatabaseTable({
    required this.id,
    required this.name,
    this.columns = const [],
    this.foreignKeys = const [],
  });
}

class DatabaseSchemaModel {
  final List<DatabaseTable> tables;

  const DatabaseSchemaModel({this.tables = const []});

  static const empty = DatabaseSchemaModel();

  bool get isEmpty => tables.isEmpty;

  DatabaseTable? tableById(String id) =>
      tables.where((t) => t.id == id).firstOrNull;
}
