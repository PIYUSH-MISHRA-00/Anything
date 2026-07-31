/// Experience Data Runtime — manages local data for Experiences.
///
/// Maps DataSchema to controlled local SQLite persistence.
/// No arbitrary SQL from ExperiencePackage.
library;

import '../creation/experience_package.dart';
import '../storage/experience_database.dart';

/// Real persistent data runtime backed by SQLite.
class ExperienceDataRuntime {
  ExperienceDatabase? _database;

  /// Creates an ExperienceDataRuntime.
  /// If [database] is provided, uses that pre-created database instance.
  /// This allows tests to inject a database created outside testWidgets
  /// where FFI initialization works.
  ExperienceDataRuntime({ExperienceDatabase? database}) : _database = database;

  /// Initialize with a DataSchema and Experience ID.
  /// If a database was provided in the constructor, this is a no-op.
  void initialize(DataSchema schema, {String? experienceId}) {
    if (_database != null) return; // Already have a database
    if (experienceId != null) {
      _database = ExperienceDatabase(experienceId);
    }
  }

  /// Insert a record into an entity.
  Future<void> insert(String entity, Map<String, dynamic> record) async {
    if (_database == null) return;

    final recordWithId = Map<String, dynamic>.from(record);
    if (!recordWithId.containsKey('id')) {
      recordWithId['id'] = 'rec-${DateTime.now().millisecondsSinceEpoch}';
    }

    await _database!.insert(entity, recordWithId);
  }

  /// Read all records from an entity.
  Future<List<Map<String, dynamic>>> query(String entity) async {
    if (_database == null) return [];
    return await _database!.query(entity);
  }

  /// Read a single record by ID.
  Future<Map<String, dynamic>?> readById(String entity, String id) async {
    if (_database == null) return null;
    return await _database!.readById(entity, id);
  }

  /// Update a record by ID.
  Future<void> update(
    String entity,
    String id,
    Map<String, dynamic> updates,
  ) async {
    if (_database == null) return;
    await _database!.update(entity, id, updates);
  }

  /// Delete a record by ID.
  Future<void> delete(String entity, String id) async {
    if (_database == null) return;
    await _database!.delete(entity, id);
  }

  /// Count records in an entity.
  Future<int> count(String entity) async {
    if (_database == null) return 0;
    return await _database!.count(entity);
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}
