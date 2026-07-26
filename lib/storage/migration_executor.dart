/// Migration Executor — executes typed data migrations against real SQLite storage.
///
/// All SQL identifiers originate from trusted SchemaStorageMapper.
/// No untrusted string becomes raw SQL syntax.
library;

import 'package:sqflite/sqflite.dart';

import 'migration.dart';
import 'schema_storage_mapper.dart';

/// Result of migration execution.
class MigrationExecutionResult {
  final bool success;
  final int fromVersion;
  final int toVersion;
  final String? error;

  const MigrationExecutionResult({
    required this.success,
    required this.fromVersion,
    required this.toVersion,
    this.error,
  });
}

/// Executes data migrations against Experience SQLite databases.
class MigrationExecutor {
  final SchemaStorageMapper _mapper;

  MigrationExecutor(this._mapper);

  /// Execute a migration plan against a specific database file.
  Future<MigrationExecutionResult> execute(
    DataMigrationPlan plan,
    String databasePath,
  ) async {
    final validation = MigrationValidator.validate(plan);
    if (!validation.isValid) {
      return MigrationExecutionResult(
        success: false,
        fromVersion: plan.fromVersion,
        toVersion: plan.toVersion,
        error: validation.errors.join('; '),
      );
    }

    try {
      final db = await openDatabase(databasePath);

      try {
        await db.transaction((txn) async {
          for (final op in plan.operations) {
            final result = await _executeOperation(txn, op);
            if (!result) {
              throw Exception('Migration operation failed: ${op.type}');
            }
          }

          await txn.update(
            'data_schema_versions',
            {
              'schema_version': plan.toVersion,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'experience_id = ?',
            whereArgs: [plan.experienceId],
          );
        });

        await db.close();
        return MigrationExecutionResult(
          success: true,
          fromVersion: plan.fromVersion,
          toVersion: plan.toVersion,
        );
      } catch (e) {
        await db.close();
        return MigrationExecutionResult(
          success: false,
          fromVersion: plan.fromVersion,
          toVersion: plan.toVersion,
          error: e.toString(),
        );
      }
    } catch (e) {
      return MigrationExecutionResult(
        success: false,
        fromVersion: plan.fromVersion,
        toVersion: plan.toVersion,
        error: e.toString(),
      );
    }
  }

  Future<bool> _executeOperation(Transaction txn, MigrationOperation op) async {
    switch (op.type) {
      case MigrationOperationType.addField:
        return _addField(txn, op);
      case MigrationOperationType.addEntity:
        return _addEntity(txn, op);
      case MigrationOperationType.addIndex:
        return _addIndex(txn, op);
    }
  }

  bool _addField(Transaction txn, MigrationOperation op) {
    final entityId = op.entityId;
    final fieldId = op.params['fieldId'] as String?;
    final typeStr = op.params['type'] as String?;

    if (fieldId == null) return false;

    final tableName = _mapper.getTableName(entityId);
    if (tableName == null) return false;

    final columnName = _mapper.getColumnName(entityId, fieldId);
    if (columnName == null) return false;

    final storageType = SchemaStorageMapper.mapDomainType(typeStr ?? 'string');

    txn.execute(
      'ALTER TABLE [$tableName] ADD COLUMN [$columnName] ${SchemaStorageMapper.sqlType(storageType)}',
    );
    return true;
  }

  bool _addEntity(Transaction txn, MigrationOperation op) {
    final entityId = op.entityId;
    final tableName = _mapper.getTableName(entityId);
    if (tableName == null) return false;

    txn.execute('''
      CREATE TABLE IF NOT EXISTS [$tableName] (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    return true;
  }

  bool _addIndex(Transaction txn, MigrationOperation op) {
    final entityId = op.entityId;
    final fieldId = op.params['fieldId'] as String?;

    if (fieldId == null) return false;

    final tableName = _mapper.getTableName(entityId);
    if (tableName == null) return false;

    final columnName = _mapper.getColumnName(entityId, fieldId);
    if (columnName == null) return false;

    final indexName = 'idx_${tableName}_$columnName';
    txn.execute(
      'CREATE INDEX IF NOT EXISTS [$indexName] ON [$tableName]([$columnName])',
    );
    return true;
  }
}
