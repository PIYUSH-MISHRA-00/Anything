/// M2 — HTTP capability SSRF hardening adversarial tests.
///
/// Covers gaps not exercised by stage81/stage82: IPv6 private/link-local/
/// unique-local/IPv4-mapped coverage, DNS-rebinding re-validation (a
/// declared, allowed hostname that resolves to a private address), response
/// size bounding, and fail-closed behavior on resolution failure.
///
/// No live network: DNS resolution is always injected via a fake resolver.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/builtin/http_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/security/runtime_security_limits.dart';

void main() {
  group('IPv6 / literal address coverage', () {
    Future<CapabilityInvocationResult> request(String url) {
      final cap = HttpCapability(
        transport: FakeHttpTransport(),
        allowedHosts: [Uri.parse(url).host],
      );
      return cap.execute('get', {'url': url});
    }

    test('IPv6 loopback ::1 denied', () async {
      final result = await request('https://[::1]/x');
      expect(result.status, CapabilityResultStatus.policyDenied);
    });

    test('IPv6 unique-local (fc00::/7) denied', () async {
      final result = await request('https://[fd00::1]/x');
      expect(result.status, CapabilityResultStatus.policyDenied);
    });

    test('IPv6 link-local (fe80::/10) denied', () async {
      final result = await request('https://[fe80::1]/x');
      expect(result.status, CapabilityResultStatus.policyDenied);
    });

    test('IPv4-mapped IPv6 loopback (::ffff:127.0.0.1) denied', () async {
      final result = await request('https://[::ffff:127.0.0.1]/x');
      expect(result.status, CapabilityResultStatus.policyDenied);
    });

    test('IPv4-mapped IPv6 private (::ffff:10.0.0.5) denied', () async {
      final result = await request('https://[::ffff:10.0.0.5]/x');
      expect(result.status, CapabilityResultStatus.policyDenied);
    });
  });

  group('DNS-rebinding re-validation', () {
    test(
      'a declared, publicly-named host that resolves to a private IP is denied',
      () async {
        final transport = FakeHttpTransport();
        transport.addResponse(
          'https://evil-rebind.example.com/data',
          HttpResponse(statusCode: 200, body: 'should not be reachable'),
        );
        final cap = HttpCapability(
          transport: transport,
          allowedHosts: ['evil-rebind.example.com'],
          hostResolver: (host) async => [InternetAddress('127.0.0.1')],
        );

        final result = await cap.execute('get', {
          'url': 'https://evil-rebind.example.com/data',
        });

        expect(result.status, CapabilityResultStatus.policyDenied);
      },
    );

    test('a host resolving to a public address is allowed', () async {
      final transport = FakeHttpTransport();
      transport.addResponse(
        'https://good.example.com/data',
        HttpResponse(statusCode: 200, body: 'ok'),
      );
      final cap = HttpCapability(
        transport: transport,
        allowedHosts: ['good.example.com'],
        hostResolver: (host) async => [InternetAddress('93.184.216.34')],
      );

      final result = await cap.execute('get', {
        'url': 'https://good.example.com/data',
      });

      expect(result.status, CapabilityResultStatus.success);
    });

    test('DNS resolution failure fails closed, not open', () async {
      final cap = HttpCapability(
        transport: FakeHttpTransport(),
        allowedHosts: ['unresolvable.example.com'],
        hostResolver: (host) async =>
            throw const SocketException('no such host'),
      );

      final result = await cap.execute('get', {
        'url': 'https://unresolvable.example.com/data',
      });

      expect(result.status, CapabilityResultStatus.policyDenied);
    });
  });

  group('Response/request size bounds', () {
    test('oversized response body is rejected, not buffered through', () async {
      final transport = FakeHttpTransport();
      final huge = 'x' * (RuntimeSecurityLimits.maxHttpResponseBytes + 1);
      transport.addResponse(
        'https://good.example.com/data',
        HttpResponse(statusCode: 200, body: huge),
      );
      final cap = HttpCapability(
        transport: transport,
        allowedHosts: ['good.example.com'],
        hostResolver: (host) async => [InternetAddress('93.184.216.34')],
      );

      final result = await cap.execute('get', {
        'url': 'https://good.example.com/data',
      });

      expect(result.status, CapabilityResultStatus.policyDenied);
    });

    test(
      'oversized request body is rejected before any transport call',
      () async {
        final transport = FakeHttpTransport();
        final cap = HttpCapability(
          transport: transport,
          allowedHosts: ['good.example.com'],
          hostResolver: (host) async => [InternetAddress('93.184.216.34')],
        );

        final result = await cap.execute('post', {
          'url': 'https://good.example.com/data',
          'body': 'x' * (RuntimeSecurityLimits.maxHttpRequestBytes + 1),
        });

        expect(result.status, CapabilityResultStatus.policyDenied);
      },
    );
  });
}
