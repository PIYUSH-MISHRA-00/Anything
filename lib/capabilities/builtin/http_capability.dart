/// HTTP capability — trusted network operations for Experiences.
library;

import 'dart:async';
import 'dart:io' show InternetAddress, InternetAddressType;

import '../../security/runtime_security_limits.dart';
import '../platform/capability_platform.dart';

/// Resolves a hostname to its IP addresses. Injectable so tests never touch
/// live DNS/network (see docs/security/RUNTIME_LIMITS.md "HTTP — DNS
/// resolution"); production default is [InternetAddress.lookup].
typedef HostResolver = Future<List<InternetAddress>> Function(String host);

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
  final HostResolver _resolveHost;

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
    HostResolver? hostResolver,
  }) : _transport = transport,
       _allowedHosts = allowedHosts,
       _resolveHost = hostResolver ?? InternetAddress.lookup,
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
    final directBlockError = _checkHostLiteral(host);
    if (directBlockError != null) return directBlockError;

    if (!_allowedHosts.contains(host)) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Host not declared in Experience package',
      );
    }

    // Request body size (defense-in-depth; no production caller sends a
    // body today, but a future one must not exceed the trusted cap).
    final body = params['body'] as String?;
    if (body != null &&
        body.length > RuntimeSecurityLimits.maxHttpRequestBytes) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Request body too large',
      );
    }

    // Resolve DNS and re-validate every resolved address. A host allowed by
    // name can still resolve to a private/loopback address (DNS rebinding);
    // hostname allow-listing alone is not sufficient (see
    // docs/security/RUNTIME_LIMITS.md "HTTP — DNS resolution").
    try {
      final addresses = await _resolveHost(host);
      for (final address in addresses) {
        if (_isPrivateOrReservedAddress(address)) {
          return const CapabilityInvocationResult(
            status: CapabilityResultStatus.policyDenied,
            error: 'Host resolves to a private/reserved network address',
          );
        }
      }
    } catch (_) {
      // Resolution failure — fail closed rather than proceed unresolved.
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Host could not be resolved',
      );
    }

    try {
      final response = await _transport.request(
        HttpRequest(method: operation.toUpperCase(), url: url),
      );
      if (response.body.length > RuntimeSecurityLimits.maxHttpResponseBytes) {
        return const CapabilityInvocationResult(
          status: CapabilityResultStatus.policyDenied,
          error: 'Response too large',
        );
      }
      // NOTE: this capability does not itself follow redirects — a 3xx
      // response is returned to the caller as-is. If a real HttpTransport
      // is ever introduced, it MUST NOT auto-follow redirects internally;
      // HttpCapability must own manual redirect following, re-running this
      // entire validation (scheme/host/DNS) against each hop's target, up
      // to RuntimeSecurityLimits.maxHttpRedirects.
      return CapabilityInvocationResult.success(
        data: {'statusCode': response.statusCode, 'body': response.body},
      );
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }

  /// String/literal checks that don't require DNS (fast-path, and the only
  /// path available when [host] is already a literal IP).
  CapabilityInvocationResult? _checkHostLiteral(String host) {
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
    final literal = InternetAddress.tryParse(host);
    if (literal != null && _isPrivateOrReservedAddress(literal)) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Access to private networks is denied',
      );
    }
    return null;
  }

  /// True for loopback, link-local, unique-local (IPv6 fc00::/7), and
  /// IPv4-mapped-IPv6 forms of the same, using Dart's own address parser
  /// rather than a hand-rolled string parser (per policy: trust the
  /// standard library's understanding of address syntax).
  bool _isPrivateOrReservedAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal) return true;

    if (address.type == InternetAddressType.IPv4) {
      return _blockedRanges.any((r) => address.address.startsWith(r));
    }

    if (address.type == InternetAddressType.IPv6) {
      final bytes = address.rawAddress;
      // fc00::/7 — unique local addresses.
      if (bytes.isNotEmpty && (bytes[0] & 0xfe) == 0xfc) return true;
      // ::ffff:0:0/96 — IPv4-mapped IPv6; re-check the embedded IPv4.
      final isV4Mapped =
          bytes.length == 16 &&
          bytes.take(10).every((b) => b == 0) &&
          bytes[10] == 0xff &&
          bytes[11] == 0xff;
      if (isV4Mapped) {
        final mapped = '${bytes[12]}.${bytes[13]}.${bytes[14]}.${bytes[15]}';
        final mappedAddr = InternetAddress.tryParse(mapped);
        if (mappedAddr != null &&
            (mappedAddr.isLoopback ||
                _blockedRanges.any((r) => mapped.startsWith(r)))) {
          return true;
        }
      }
    }

    return false;
  }
}
