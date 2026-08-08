/// Real HttpTransport backing HttpCapability, using the already-real
/// `package:http` dependency (already used by `GroqModelProvider`) — a
/// thin I/O adapter, not a second HTTP client abstraction. All
/// scheme/host/DNS/size validation happens in `HttpCapability` itself,
/// before this transport is ever called (R1: wiring, not redesign).
library;

import 'package:http/http.dart' as http;

import '../builtin/http_capability.dart';

class RealHttpTransport implements HttpTransport {
  final http.Client _client;

  RealHttpTransport({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<HttpResponse> request(HttpRequest request) async {
    final uri = Uri.parse(request.url);
    final response = await switch (request.method) {
      'GET' =>
        _client.get(uri, headers: request.headers).timeout(request.timeout),
      'POST' =>
        _client
            .post(uri, headers: request.headers, body: request.body)
            .timeout(request.timeout),
      _ => throw UnsupportedError('Unsupported HTTP method: ${request.method}'),
    };
    return HttpResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }
}
