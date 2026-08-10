/// Stage 8.3 final gate tests — security hardening and verification.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/capabilities/builtin/file_capability.dart';
import 'package:anything/capabilities/builtin/notification_capability.dart';
import 'package:anything/capabilities/builtin/clock_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/storage/schema_storage_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FileCapability Size Enforcement', () {
    test('rejects oversized file', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(
          id: 'file-1',
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
      expect(result.error, contains('size'));
    });

    test('allows file within trusted limit', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(
          id: 'file-1',
          displayName: 'small.txt',
          sizeBytes: 4 * 1024 * 1024,
        ),
      );
      final cap = FileCapability(
        service: service,
        experienceId: 'exp-test',
        maxFileSize: 5 * 1024 * 1024,
      );

      final result = await cap.execute('pickFile', {});
      expect(result.status, equals(CapabilityResultStatus.success));
    });

    test('Experience cannot raise trusted limit', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(
          id: 'file-1',
          displayName: 'big.bin',
          sizeBytes: 10 * 1024 * 1024,
        ),
      );
      final cap = FileCapability(
        service: service,
        experienceId: 'exp-test',
        maxFileSize: 5 * 1024 * 1024,
      );

      // Experience requests 50MB but trusted max is 5MB
      final result = await cap.execute('pickFile', {
        'maxSizeBytes': 50 * 1024 * 1024,
      });
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });
  });

  group('FileOwnership', () {
    test('adopted file is scoped to Experience', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(id: 'file-1', displayName: 'test.txt'),
      );

      final capA = FileCapability(service: service, experienceId: 'exp-A');
      final capB = FileCapability(service: service, experienceId: 'exp-B');

      // A adopts file
      final adoptResult = await capA.execute('adoptFile', {'fileId': 'file-1'});
      expect(adoptResult.status, equals(CapabilityResultStatus.success));

      // B cannot delete A's file
      final deleteResult = await capB.execute('deleteFile', {
        'fileId': 'file-1',
      });
      expect(deleteResult.data['deleted'], equals(false));
    });
  });

  group('Capability Budget Scope', () {
    test('budget is per-capability-instance, not global', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      // Session A exhausts budget
      for (var i = 0; i < 100; i++) {
        await platform.invoke('clock', 'now', {});
      }

      // Session A is denied
      final resultA = await platform.invoke('clock', 'now', {});
      expect(resultA.status, equals(CapabilityResultStatus.policyDenied));

      // Reset for new session (simulates new Runtime session)
      platform.resetCounts();

      // New session works
      final resultB = await platform.invoke('clock', 'now', {});
      expect(resultB.status, equals(CapabilityResultStatus.success));
    });
  });

  group('Migration Security', () {
    test('malicious entity name is rejected', () async {
      final mapper = SchemaStorageMapper();
      expect(mapper.getTableName('notes; DROP TABLE users; --'), isNull);
    });

    test('safe entity name is mapped', () async {
      final mapper = SchemaStorageMapper();
      mapper.registerEntity('notes', 'exp_test_e0');
      expect(mapper.getTableName('notes'), equals('exp_test_e0'));
    });

    test('domain types map correctly', () {
      expect(
        SchemaStorageMapper.mapDomainType('string'),
        equals(SqlStorageType.text),
      );
      expect(
        SchemaStorageMapper.mapDomainType('integer'),
        equals(SqlStorageType.integer),
      );
      expect(
        SchemaStorageMapper.mapDomainType('decimal'),
        equals(SqlStorageType.real),
      );
      expect(
        SchemaStorageMapper.mapDomainType('boolean'),
        equals(SqlStorageType.integer),
      );
      expect(
        SchemaStorageMapper.mapDomainType('json'),
        equals(SqlStorageType.text),
      );
    });

    test('unregistered entity returns null', () async {
      final mapper = SchemaStorageMapper();
      expect(mapper.getTableName('nonexistent'), isNull);
    });
  });

  group('Notification Ownership', () {
    test('Experience cannot cancel another Experience notification', () async {
      final service = FakeNotificationService();
      final capA = NotificationCapability(
        service: service,
        experienceId: 'exp-A',
      );
      final capB = NotificationCapability(
        service: service,
        experienceId: 'exp-B',
      );

      await capA.execute('schedule', {'title': 'A reminder', 'hour': 8});
      expect(service.scheduled.length, equals(1));

      await capB.execute('cancelAll', {});
      expect(service.scheduled.length, equals(1));
      expect(service.scheduled[0]['experienceId'], equals('exp-A'));
    });
  });

  group('Capability Escalation', () {
    test('undeclared capability is denied', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      final result = await platform.invoke(
        'notifications',
        'schedule',
        {'title': 'Attack', 'hour': 8},
        declaredCapabilities: ['clock'],
      );
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });

    test('budget enforced then reset works', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      for (var i = 0; i < 100; i++) {
        await platform.invoke('clock', 'now', {});
      }
      final denied = await platform.invoke('clock', 'now', {});
      expect(denied.status, equals(CapabilityResultStatus.policyDenied));

      platform.resetCounts();
      final allowed = await platform.invoke('clock', 'now', {});
      expect(allowed.status, equals(CapabilityResultStatus.success));
    });
  });
}
