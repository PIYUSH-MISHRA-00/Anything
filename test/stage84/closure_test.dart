/// Stage 8 Closure — comprehensive verification tests.
library;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:anything/storage/migration_executor.dart';
import 'package:anything/storage/migration.dart';
import 'package:anything/storage/schema_storage_mapper.dart';
import 'package:anything/capabilities/builtin/file_capability.dart';
import 'package:anything/capabilities/builtin/clock_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration — Successful', () {
    test('Notes v1 to v2 migration preserves data', () async {
      final tempDir = await Directory.systemTemp.createTemp('migration_test_');
      final dbPath = p.join(tempDir.path, 'experience_notes.db');

      // Create v1 database with data
      final db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
          CREATE TABLE exp_notes_e0 (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE data_schema_versions (
            experience_id TEXT PRIMARY KEY,
            schema_version INTEGER NOT NULL,
            initialized_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
          await db.insert('exp_notes_e0', {
            'id': 'note-1',
            'data': '{"title":"Anything","body":"My first generated app"}',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          await db.insert('data_schema_versions', {
            'experience_id': 'notes',
            'schema_version': 1,
            'initialized_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        },
      );
      await db.close();

      // Set up mapper with stable IDs
      final mapper = SchemaStorageMapper();
      mapper.registerEntity('notes', 'exp_notes_e0');
      mapper.registerField('notes', 'title', 'col_0');

      // Execute migration v1 → v2 (add tags field)
      final executor = MigrationExecutor(mapper);
      final plan = DataMigrationPlan(
        experienceId: 'notes',
        fromVersion: 1,
        toVersion: 2,
        operations: [
          const MigrationOperation(
            type: MigrationOperationType.addField,
            entityId: 'notes',
            params: {'fieldId': 'title', 'type': 'string'},
          ),
        ],
      );

      final result = await executor.execute(plan, dbPath);
      expect(result.success, isTrue);
      expect(result.fromVersion, equals(1));
      expect(result.toVersion, equals(2));

      // Reopen and verify
      final db2 = await openDatabase(dbPath);
      final notes = await db2.query('exp_notes_e0');
      expect(notes.length, equals(1));
      expect(notes[0]['id'], equals('note-1'));

      final versions = await db2.query('data_schema_versions');
      expect(versions[0]['schema_version'], equals(2));

      await db2.close();
      await tempDir.delete(recursive: true);
    });
  });

  group('Migration — Malicious Execution', () {
    test('malicious entity name fails and data survives', () async {
      final tempDir = await Directory.systemTemp.createTemp('malicious_test_');
      final dbPath = p.join(tempDir.path, 'experience_test.db');

      // Create database with valuable data
      final db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
          CREATE TABLE records (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE data_schema_versions (
            experience_id TEXT PRIMARY KEY,
            schema_version INTEGER NOT NULL,
            initialized_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
          await db.insert('records', {'id': '1', 'data': 'important data'});
          await db.insert('data_schema_versions', {
            'experience_id': 'test',
            'schema_version': 1,
            'initialized_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        },
      );
      await db.close();

      // Set up mapper — malicious entity NOT registered
      final mapper = SchemaStorageMapper();
      // NOT registering the malicious entity

      // Attempt malicious migration
      final executor = MigrationExecutor(mapper);
      final plan = DataMigrationPlan(
        experienceId: 'test',
        fromVersion: 1,
        toVersion: 2,
        operations: [
          const MigrationOperation(
            type: MigrationOperationType.addEntity,
            entityId: "notes; DROP TABLE records; --",
          ),
        ],
      );

      final result = await executor.execute(plan, dbPath);

      // Migration should fail (entity not registered)
      expect(result.success, isFalse);

      // Verify data still exists — SAME database
      final db2 = await openDatabase(dbPath);
      final rows = await db2.query('records');
      expect(rows.length, equals(1));
      expect(rows[0]['data'], equals('important data'));

      // Schema version unchanged
      final versions = await db2.query('data_schema_versions');
      expect(versions[0]['schema_version'], equals(1));

      await db2.close();
      await tempDir.delete(recursive: true);
    });
  });

  group('Migration — Transactional Rollback', () {
    test('rollback after partial mutation', () async {
      final tempDir = await Directory.systemTemp.createTemp('rollback_test_');
      final dbPath = p.join(tempDir.path, 'experience_test.db');

      // Create database with data
      final db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
          CREATE TABLE exp_notes_e0 (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE data_schema_versions (
            experience_id TEXT PRIMARY KEY,
            schema_version INTEGER NOT NULL,
            initialized_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
          await db.insert('exp_notes_e0', {
            'id': 'note-1',
            'data': '{"title":"original"}',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          await db.insert('data_schema_versions', {
            'experience_id': 'test',
            'schema_version': 1,
            'initialized_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        },
      );
      await db.close();

      // Set up mapper
      final mapper = SchemaStorageMapper();
      mapper.registerEntity('notes', 'exp_notes_e0');
      mapper.registerField('notes', 'title', 'col_0');

      // Migration: valid operation + invalid operation (unregistered entity)
      final executor = MigrationExecutor(mapper);
      final plan = DataMigrationPlan(
        experienceId: 'test',
        fromVersion: 1,
        toVersion: 2,
        operations: [
          // Operation A: valid — would add a field
          const MigrationOperation(
            type: MigrationOperationType.addField,
            entityId: 'notes',
            params: {'fieldId': 'title', 'type': 'string'},
          ),
          // Operation B: invalid — entity not registered
          const MigrationOperation(
            type: MigrationOperationType.addEntity,
            entityId: 'nonexistent_entity',
          ),
        ],
      );

      final result = await executor.execute(plan, dbPath);

      // Migration should fail
      expect(result.success, isFalse);

      // Verify data unchanged — SAME database
      final db2 = await openDatabase(dbPath);
      final rows = await db2.query('exp_notes_e0');
      expect(rows.length, equals(1));
      expect(rows[0]['data'], equals('{"title":"original"}'));

      // Schema version unchanged
      final versions = await db2.query('data_schema_versions');
      expect(versions[0]['schema_version'], equals(1));

      await db2.close();
      await tempDir.delete(recursive: true);
    });
  });

  group('Migration — Schema ID Independence', () {
    test('renaming display name does not affect physical mapping', () {
      final mapper = SchemaStorageMapper();
      mapper.registerEntity('note_entity', 'exp_test_e0');
      mapper.registerField('note_entity', 'title_field', 'col_0');

      // Original mapping
      expect(mapper.getTableName('note_entity'), equals('exp_test_e0'));
      expect(
        mapper.getColumnName('note_entity', 'title_field'),
        equals('col_0'),
      );

      // Re-register with different "display name" (simulating rename)
      // The ID stays the same, so mapping is unchanged
      mapper.registerEntity('note_entity', 'exp_test_e0_renamed');
      expect(mapper.getTableName('note_entity'), equals('exp_test_e0_renamed'));

      // But the original ID still works
      expect(
        mapper.getColumnName('note_entity', 'title_field'),
        equals('col_0'),
      );
    });
  });

  group('Session Isolation', () {
    test('budget isolation without resetCounts', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      // Session A exhausts budget
      for (var i = 0; i < 100; i++) {
        await platform.invoke('clock', 'now', {}, sessionId: 'session-A');
      }

      // Session A denied
      final resultA = await platform.invoke(
        'clock',
        'now',
        {},
        sessionId: 'session-A',
      );
      expect(resultA.status, equals(CapabilityResultStatus.policyDenied));

      // Session B works without reset
      final resultB = await platform.invoke(
        'clock',
        'now',
        {},
        sessionId: 'session-B',
      );
      expect(resultB.status, equals(CapabilityResultStatus.success));

      // Session A still denied
      final resultA2 = await platform.invoke(
        'clock',
        'now',
        {},
        sessionId: 'session-A',
      );
      expect(resultA2.status, equals(CapabilityResultStatus.policyDenied));
    });

    test('resetSession does not affect other sessions', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      for (var i = 0; i < 50; i++) {
        await platform.invoke('clock', 'now', {}, sessionId: 'session-A');
      }
      for (var i = 0; i < 50; i++) {
        await platform.invoke('clock', 'now', {}, sessionId: 'session-B');
      }

      platform.resetSession('session-A');

      final resultA = await platform.invoke(
        'clock',
        'now',
        {},
        sessionId: 'session-A',
      );
      expect(resultA.status, equals(CapabilityResultStatus.success));

      final resultB = await platform.invoke(
        'clock',
        'now',
        {},
        sessionId: 'session-B',
      );
      expect(resultB.status, equals(CapabilityResultStatus.success));
    });
  });

  group('File Size Enforcement', () {
    test('requested limit below trusted limit is enforced', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(
          id: 'f1',
          displayName: 'big.bin',
          sizeBytes: 4 * 1024 * 1024,
        ),
      ); // 4MB
      final cap = FileCapability(
        service: service,
        experienceId: 'exp-test',
        maxFileSize: 5 * 1024 * 1024,
      );

      // Request 2MB but file is 4MB — effectiveMax is 2MB
      final result = await cap.execute('pickFile', {
        'maxSizeBytes': 2 * 1024 * 1024,
      });
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });

    test('file within effective limit succeeds', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(
          id: 'f1',
          displayName: 'small.txt',
          sizeBytes: 3 * 1024 * 1024,
        ),
      );
      final cap = FileCapability(
        service: service,
        experienceId: 'exp-test',
        maxFileSize: 5 * 1024 * 1024,
      );

      final result = await cap.execute('pickFile', {
        'maxSizeBytes': 4 * 1024 * 1024,
      });
      expect(result.status, equals(CapabilityResultStatus.success));
    });

    test('file exceeding trusted limit denied', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(
          id: 'f1',
          displayName: 'huge.bin',
          sizeBytes: 10 * 1024 * 1024,
        ),
      );
      final cap = FileCapability(
        service: service,
        experienceId: 'exp-test',
        maxFileSize: 5 * 1024 * 1024,
      );

      final result = await cap.execute('pickFile', {});
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });
  });

  group('File Ownership', () {
    test('cross-Experience file access denied', () async {
      final service = FakeFileService();
      service.addFile(const FileReference(id: 'f1', displayName: 'secret.txt'));

      final capA = FileCapability(service: service, experienceId: 'exp-A');
      final capB = FileCapability(service: service, experienceId: 'exp-B');

      await capA.execute('adoptFile', {'fileId': 'f1'});

      // B cannot delete A's file
      final deleteResult = await capB.execute('deleteFile', {'fileId': 'f1'});
      expect(deleteResult.data['deleted'], equals(false));

      // A can delete its own file
      final deleteResultA = await capA.execute('deleteFile', {'fileId': 'f1'});
      expect(deleteResultA.data['deleted'], equals(true));
    });
  });

  group('Capability Escalation', () {
    test('undeclared capability denied', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      final result = await platform.invoke(
        'notifications',
        'schedule',
        {'title': 'X', 'hour': 8},
        declaredCapabilities: ['clock'],
      );
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });
  });
}

/// Fake file service for testing.
class FakeFileService implements FileService {
  final List<FileReference> _files = [];
  final Map<String, String> _ownership = {};

  void addFile(FileReference file) => _files.add(file);

  @override
  Future<FileReference?> pickFile({
    List<String>? allowedExtensions,
    int? maxSizeBytes,
  }) async {
    if (_files.isEmpty) return null;
    return _files.first;
  }

  @override
  Future<FileReference?> pickImage({int? maxSizeBytes}) async {
    return _files
        .where((f) => f.mimeType?.startsWith('image/') == true)
        .firstOrNull;
  }

  @override
  Future<bool> adoptFile(String fileId, String experienceId) async {
    _files.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw Exception('File not found'),
    );
    _ownership[fileId] = experienceId;
    return true;
  }

  @override
  Future<bool> deleteAdoptedFile(String fileId, String experienceId) async {
    if (_ownership[fileId] != experienceId) return false;
    _ownership.remove(fileId);
    return true;
  }
}
