/// HTTP capability — trusted network operations for Experiences.
library;

import 'dart:async';

import '../platform/capability_platform.dart';

/// HTTP transport abstraction.
abstract class HttpTransport {
  Future<HttpResponse> request(HttpRequest request);
}

class HttpRequest {
  final String method;
  final String url;
  final Map<String, String> headers;
  final String? body;
  final Duration timeout;

  const HttpRequest({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    this.timeout = const Duration(seconds: 30),
  });
}

class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const HttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}

/// Fake HTTP transport for testing.
class FakeHttpTransport implements HttpTransport {
  final Map<String, HttpResponse> _responses = {};

  void addResponse(String url, HttpResponse response) {
    _responses[url] = response;
  }

  @override
  Future<HttpResponse> request(HttpRequest request) async {
    final response = _responses[request.url];
    if (response == null) {
      return const HttpResponse(statusCode: 404, body: 'Not found');
    }
    return response;
  }
}

/// HTTP capability for Experiences.
class HttpCapability extends PlatformCapability {
  final HttpTransport _transport;
  final List<String> _allowedHosts;

  static const List<String> _blockedHosts = [
    'localhost',
    '127.0.0.1',
    '::1',
    '0.0.0.0',
  ];

  static const List<String> _blockedRanges = [
    '10.',
    '172.16.',
    '172.17.',
    '172.18.',
    '172.19.',
    '172.20.',
    '172.21.',
    '172.22.',
    '172.23.',
    '172.24.',
    '172.25.',
    '172.26.',
    '172.27.',
    '172.28.',
    '172.29.',
    '172.30.',
    '172.31.',
    '192.168.',
    '169.254.',
  ];

  HttpCapability({
    required HttpTransport transport,
    required List<String> allowedHosts,
  }) : _transport = transport,
       _allowedHosts = allowedHosts,
       super(
         id: 'http',
         name: 'HTTP',
         description: 'Network requests',
         supportedOperations: ['get', 'post'],
       );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    final url = params['url'] as String?;
    if (url == null) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.invalidArguments,
        error: 'URL required',
      );
    }

    // Validate scheme
    if (!url.startsWith('https://')) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Only HTTPS is allowed',
      );
    }

    // Validate host
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.invalidArguments,
        error: 'Invalid URL',
      );
    }

    final host = uri.host;
    if (_blockedHosts.contains(host)) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Access to this host is denied',
      );
    }

    for (final range in _blockedRanges) {
      if (host.startsWith(range)) {
        return const CapabilityInvocationResult(
          status: CapabilityResultStatus.policyDenied,
          error: 'Access to private networks is denied',
        );
      }
    }

    if (!_allowedHosts.contains(host)) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Host not declared in Experience package',
      );
    }

    try {
      final response = await _transport.request(
        HttpRequest(method: operation.toUpperCase(), url: url),
      );
      return CapabilityInvocationResult.success(
        data: {'statusCode': response.statusCode, 'body': response.body},
      );
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }
}
