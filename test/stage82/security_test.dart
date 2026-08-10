/// Stage 8.2 security and hardening tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/capabilities/builtin/file_capability.dart';
import 'package:anything/capabilities/builtin/notification_capability.dart';
import 'package:anything/capabilities/builtin/http_capability.dart';
import 'package:anything/capabilities/builtin/clock_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FileCapability', () {
    test('picks file', () async {
      final service = FakeFileService();
      service.addFile(
        const FileReference(
          id: 'file-1',
          displayName: 'doc.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
        ),
      );
      final cap = FileCapability(service: service, experienceId: 'exp-test');
      final result = await cap.execute('pickFile', {});
      expect(result.status, equals(CapabilityResultStatus.success));
    });

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
      final result = await cap.execute('pickFile', {
        'maxSizeBytes': 50 * 1024 * 1024,
      });
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
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

  group('HTTP Security', () {
    test('denies HTTP scheme', () async {
      final cap = HttpCapability(
        transport: FakeHttpTransport(),
        allowedHosts: ['example.com'],
      );
      final result = await cap.execute('get', {
        'url': 'http://example.com/data',
      });
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });

    test('denies localhost', () async {
      final cap = HttpCapability(
        transport: FakeHttpTransport(),
        allowedHosts: ['localhost'],
      );
      final result = await cap.execute('get', {
        'url': 'https://localhost/data',
      });
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });

    test('denies private IPs', () async {
      final cap = HttpCapability(
        transport: FakeHttpTransport(),
        allowedHosts: ['10.0.0.1', '172.16.0.1', '192.168.1.1'],
      );
      expect(
        (await cap.execute('get', {'url': 'https://10.0.0.1/data'})).status,
        equals(CapabilityResultStatus.policyDenied),
      );
      expect(
        (await cap.execute('get', {'url': 'https://172.16.0.1/data'})).status,
        equals(CapabilityResultStatus.policyDenied),
      );
      expect(
        (await cap.execute('get', {'url': 'https://192.168.1.1/data'})).status,
        equals(CapabilityResultStatus.policyDenied),
      );
    });

    test('denies undeclared host', () async {
      final cap = HttpCapability(
        transport: FakeHttpTransport(),
        allowedHosts: ['api.example.com'],
      );
      final result = await cap.execute('get', {'url': 'https://evil.com/data'});
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
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
