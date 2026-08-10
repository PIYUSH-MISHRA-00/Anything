/// Tests for Capability Platform.
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/capabilities/builtin/clock_capability.dart';
import 'package:anything/capabilities/builtin/notification_capability.dart';
import 'package:anything/capabilities/builtin/http_capability.dart';
import 'package:anything/capabilities/builtin/ai_capability.dart';
import 'package:anything/capabilities/builtin/knowledge_capability.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CapabilityPlatform', () {
    test('registers and invokes capabilities', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      expect(platform.isRegistered('clock'), isTrue);
      expect(platform.isRegistered('unknown'), isFalse);

      final result = await platform.invoke('clock', 'now', {});
      expect(result.status, equals(CapabilityResultStatus.success));
      expect(result.data.containsKey('timestamp'), isTrue);
    });

    test('rejects undeclared capability', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      final result = await platform.invoke(
        'clock',
        'now',
        {},
        declaredCapabilities: ['notifications'], // clock not declared
      );
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });

    test('rejects unknown capability', () async {
      final platform = CapabilityPlatform();
      final result = await platform.invoke('nonexistent', 'op', {});
      expect(result.status, equals(CapabilityResultStatus.unsupported));
    });

    test('rejects unsupported operation', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      final result = await platform.invoke('clock', 'fly', {});
      expect(result.status, equals(CapabilityResultStatus.unsupported));
    });

    test('enforces invocation budget', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());

      // Invoke 100 times (the limit)
      for (var i = 0; i < 100; i++) {
        await platform.invoke('clock', 'now', {});
      }

      // 101st should fail
      final result = await platform.invoke('clock', 'now', {});
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });

    test('ClockCapability returns current time', () async {
      final cap = ClockCapability();
      final result = await cap.execute('now', {});
      expect(result.status, equals(CapabilityResultStatus.success));
      expect(result.data.containsKey('year'), isTrue);
      expect(result.data.containsKey('hour'), isTrue);
    });
  });

  group('NotificationCapability', () {
    test('schedules notification', () async {
      final service = FakeNotificationService();
      final cap = NotificationCapability(
        service: service,
        experienceId: 'exp-test',
      );

      final result = await cap.execute('schedule', {
        'title': 'Reminder',
        'body': 'Time to exercise',
        'hour': 8,
        'minute': 0,
      });

      expect(result.status, equals(CapabilityResultStatus.success));
      expect(service.scheduled.length, equals(1));
      expect(service.scheduled[0]['experienceId'], equals('exp-test'));
    });

    test('rejects empty title', () async {
      final service = FakeNotificationService();
      final cap = NotificationCapability(
        service: service,
        experienceId: 'exp-test',
      );

      final result = await cap.execute('schedule', {'title': ''});
      expect(result.status, equals(CapabilityResultStatus.invalidArguments));
    });

    test('cancels notification', () async {
      final service = FakeNotificationService();
      final cap = NotificationCapability(
        service: service,
        experienceId: 'exp-test',
      );

      await service.schedule(
        id: 'notif-1',
        experienceId: 'exp-test',
        title: 'Test',
        body: 'Body',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final result = await cap.execute('cancel', {'notificationId': 'notif-1'});
      expect(result.status, equals(CapabilityResultStatus.success));
      expect(service.cancelled, contains('notif-1'));
    });

    test('ownership isolation', () async {
      final service = FakeNotificationService();
      final capA = NotificationCapability(
        service: service,
        experienceId: 'exp-A',
      );
      final capB = NotificationCapability(
        service: service,
        experienceId: 'exp-B',
      );

      // A schedules
      await capA.execute('schedule', {'title': 'A reminder', 'hour': 8});

      // B tries to cancel all for B
      await capB.execute('cancelAll', {});

      // A's notification should still exist
      expect(service.scheduled.length, equals(1));
      expect(service.scheduled[0]['experienceId'], equals('exp-A'));
    });
  });

  group('HttpCapability', () {
    test('allows valid HTTPS request', () async {
      final transport = FakeHttpTransport();
      transport.addResponse(
        'https://api.example.com/data',
        HttpResponse(statusCode: 200, body: '{"result": "ok"}'),
      );

      final cap = HttpCapability(
        transport: transport,
        allowedHosts: ['api.example.com'],
        // Fake resolver — DNS-rebinding re-validation must not depend on
        // live network in tests (see docs/security/RUNTIME_LIMITS.md).
        hostResolver: (host) async => [InternetAddress('93.184.216.34')],
      );

      final result = await cap.execute('get', {
        'url': 'https://api.example.com/data',
      });
      expect(result.status, equals(CapabilityResultStatus.success));
    });

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

    test('denies private IP', () async {
      final cap = HttpCapability(
        transport: FakeHttpTransport(),
        allowedHosts: ['192.168.1.1'],
      );

      final result = await cap.execute('get', {
        'url': 'https://192.168.1.1/data',
      });
      expect(result.status, equals(CapabilityResultStatus.policyDenied));
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

  group('AiCapability', () {
    test('generates through provider', () async {
      final provider = FakeAiProvider(response: 'Hello from AI');
      final cap = AiCapability(provider: provider, experienceId: 'exp-test');

      final result = await cap.execute('generate', {'prompt': 'Test'});
      expect(result.status, equals(CapabilityResultStatus.success));
      expect(result.data['response'], equals('Hello from AI'));
      expect(provider.callCount, equals(1));
    });

    test('rejects empty prompt', () async {
      final cap = AiCapability(
        provider: FakeAiProvider(),
        experienceId: 'exp-test',
      );

      final result = await cap.execute('generate', {'prompt': ''});
      expect(result.status, equals(CapabilityResultStatus.invalidArguments));
    });
  });

  group('KnowledgeCapability', () {
    test('retrieves knowledge', () async {
      final provider = FakeKnowledgeProvider(
        results: [
          {'title': 'Flutter Docs', 'source': 'flutter.dev'},
        ],
      );
      final cap = KnowledgeCapability(provider: provider);

      final result = await cap.execute('retrieve', {'query': 'Flutter'});
      expect(result.status, equals(CapabilityResultStatus.success));
    });

    test('rejects empty query', () async {
      final cap = KnowledgeCapability(provider: FakeKnowledgeProvider());

      final result = await cap.execute('retrieve', {'query': ''});
      expect(result.status, equals(CapabilityResultStatus.invalidArguments));
    });
  });

  group('Cross-Experience Security', () {
    test('Experience A cannot use undeclared capabilities', () async {
      final platform = CapabilityPlatform();
      platform.register(ClockCapability());
      platform.register(
        NotificationCapability(
          service: FakeNotificationService(),
          experienceId: 'exp-A',
        ),
      );

      // Experience A only declared clock
      final result = await platform.invoke(
        'notifications',
        'schedule',
        {'title': 'Attack', 'hour': 8},
        declaredCapabilities: ['clock'],
      );

      expect(result.status, equals(CapabilityResultStatus.policyDenied));
    });
  });
}
