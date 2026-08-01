/// Schema-to-Storage Mapper — maps trusted schema IDs to safe SQL identifiers.
///
/// All SQL identifiers originate from this trusted mapping layer.
/// Model/user-visible names never become SQL identifiers directly.
library;

import '../creation/experience_package.dart';

/// Safe SQL storage types.
enum SqlStorageType { text, integer, real, blob }

/// Maps DataSchema entity/field IDs to safe SQLite identifiers.
class SchemaStorageMapper {
  final Map<String, String> _entityTableMap = {};
  final Map<String, String> _fieldColumnMap = {};

  /// Map a domain type to a safe SQL storage type.
  static SqlStorageType mapDomainType(String domainType) {
    switch (domainType.toLowerCase()) {
      case 'string':
        return SqlStorageType.text;
      case 'integer':
        return SqlStorageType.integer;
      case 'decimal':
      case 'number':
      case 'double':
      case 'float':
        return SqlStorageType.real;
      case 'boolean':
        return SqlStorageType.integer;
      case 'datetime':
      case 'date':
        return SqlStorageType.text;
      case 'json':
      case 'list':
      case 'map':
        return SqlStorageType.text;
      default:
        return SqlStorageType.text;
    }
  }

  /// Get the SQL type string for a storage type.
  static String sqlType(SqlStorageType type) {
    switch (type) {
      case SqlStorageType.text:
        return 'TEXT';
      case SqlStorageType.integer:
        return 'INTEGER';
      case SqlStorageType.real:
        return 'REAL';
      case SqlStorageType.blob:
        return 'BLOB';
    }
  }

  /// Register an entity mapping using stable entity ID.
  void registerEntity(String entityId, String tableName) {
    _entityTableMap[entityId] = tableName;
  }

  /// Register a field mapping using stable field ID.
  void registerField(String entityId, String fieldId, String columnName) {
    _fieldColumnMap['$entityId.$fieldId'] = columnName;
  }

  /// Get the safe table name for an entity.
  String? getTableName(String entityId) {
    return _entityTableMap[entityId];
  }

  /// Get the safe column name for a field.
  String? getColumnName(String entityId, String fieldId) {
    return _fieldColumnMap['$entityId.$fieldId'];
  }

  /// Build initial mappings from a DataSchema using stable IDs.
  ///
  /// [experienceId] may originate from model-generated content (an
  /// AppBlueprint id parsed from untrusted LLM JSON — see
  /// BlueprintToSpecConverter) and must never be trusted to already be a
  /// safe SQL identifier fragment: it is sanitized to a bounded
  /// alphanumeric/underscore token before being folded into a table name,
  /// so it can never break out of the `[...]` identifier quoting used by
  /// MigrationExecutor's DDL statements.
  void buildFromSchema(DataSchema schema, {required String experienceId}) {
    final safeExperienceId = _sanitizeIdentifierComponent(experienceId);
    for (var i = 0; i < schema.entities.length; i++) {
      final entity = schema.entities[i];
      final tableName = 'exp_${safeExperienceId}_e$i';
      registerEntity(entity.id, tableName);

      for (var j = 0; j < entity.fields.length; j++) {
        final field = entity.fields[j];
        final columnName = 'f$j';
        registerField(entity.id, field.id, columnName);
      }
    }
  }

  /// Reduce an untrusted string to a bounded-length token containing only
  /// `[a-zA-Z0-9_]`, safe to fold into a SQL identifier under any quoting
  /// style (bracket, double-quote, backtick) since it cannot contain the
  /// quote/terminator character of any of them.
  static String _sanitizeIdentifierComponent(String raw) {
    final stripped = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return stripped.isEmpty
        ? 'x'
        : stripped.substring(0, stripped.length > 64 ? 64 : stripped.length);
  }
}
