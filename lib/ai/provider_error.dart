/// Provider error taxonomy — Implementation Specification IS-P06.
///
/// WHY THIS EXISTS.
///
/// Manual testing reported: a FRESH, VALID Groq key failed "Test Connection"
/// with HTTP 400. The key was never the problem (see
/// `GROQ_ROOT_CAUSE_ANALYSIS.md`), but the user could not have known that,
/// because every non-200 that was not 401/403/429 collapsed into the single
/// sentence "The provider returned HTTP 400."
///
/// A raw status code is not an error message. `400` from an OpenAI-compatible
/// API can mean a decommissioned model, a malformed body, an unknown
/// parameter, or a context-length overflow — four different user actions.
/// This file is the ONE place that turns a transport outcome into something a
/// person can act on, so no provider adapter invents its own wording.
///
/// OWNERSHIP: this module CLASSIFIES. It never performs I/O, never retries and
/// never decides policy. Adapters call it; the registry surfaces what it
/// returns.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What actually went wrong, independent of provider and of HTTP.
///
/// Ordered roughly "your fault" → "their fault" → "unknown".
enum ProviderFailure {
  /// No key was supplied at all.
  missingApiKey,

  /// The key was presented and refused. HTTP 401.
  invalidApiKey,

  /// The key is valid but not permitted to do this. HTTP 403.
  permissionDenied,

  /// The endpoint URL is wrong, or is not an OpenAI-compatible API.
  incorrectEndpoint,

  /// The requested model does not exist for this provider. HTTP 404 / 400.
  missingModel,

  /// The model existed once and has been retired by the provider.
  ///
  /// This is a DISTINCT case, not a flavour of [missingModel]: the user did
  /// nothing wrong and there is a documented replacement. It is exactly the
  /// defect IS-P06 was raised to fix, so it gets its own name.
  modelDecommissioned,

  /// Too many requests. HTTP 429.
  rateLimited,

  /// The provider is up but failed. HTTP 5xx.
  serverUnavailable,

  /// No route to the provider — offline, DNS failure, connection refused.
  networkUnavailable,

  /// TLS negotiation or certificate validation failed.
  sslFailure,

  /// The provider did not answer in time.
  timeout,

  /// A 2xx arrived but the body was not the shape the contract requires.
  unexpectedResponse,

  /// Genuinely unclassified. Kept deliberately rare.
  unknown,
}

/// A classified provider failure carrying a message fit for a user.
///
/// [message] is always a complete sentence and NEVER contains a stack trace,
/// a raw exception `toString()`, or an API key.
class ProviderException implements Exception {
  final ProviderFailure failure;
  final String message;

  /// The provider's own error text, when it supplied one. Diagnostics only —
  /// shown in Developer Mode, never on the configuration screen.
  final String? providerDetail;

  /// HTTP status, when the failure came from a response. Diagnostics only.
  final int? statusCode;

  const ProviderException(
    this.failure,
    this.message, {
    this.providerDetail,
    this.statusCode,
  });

  /// Whether retrying the identical request could plausibly succeed.
  bool get isTransient =>
      failure == ProviderFailure.rateLimited ||
      failure == ProviderFailure.serverUnavailable ||
      failure == ProviderFailure.networkUnavailable ||
      failure == ProviderFailure.timeout;

  /// Whether the user must change their key to proceed.
  bool get requiresNewKey =>
      failure == ProviderFailure.invalidApiKey ||
      failure == ProviderFailure.missingApiKey;

  @override
  String toString() => message;
}

/// Classifies provider outcomes into [ProviderException]s.
///
/// Pure and synchronous. Every branch is reachable from a real provider
/// response, and every branch is covered by a test.
abstract final class ProviderErrors {
  /// Classifies a non-2xx HTTP response.
  ///
  /// [body] is the raw response body. OpenAI-compatible APIs return
  /// `{"error": {"message": ..., "type": ..., "code": ...}}`, and the `code`
  /// is what separates a retired model from a typo.
  static ProviderException fromResponse({
    required int statusCode,
    required String body,
    required String providerName,
  }) {
    final detail = _extract(body);
    final code = detail.code?.toLowerCase() ?? '';
    final text = detail.message?.toLowerCase() ?? '';

    // Checked BEFORE the status switch: a decommissioned model arrives as a
    // 400, which is otherwise indistinguishable from a malformed request.
    // This is the exact signature of the defect IS-P06 fixes.
    if (code == 'model_decommissioned' || text.contains('decommissioned')) {
      return ProviderException(
        ProviderFailure.modelDecommissioned,
        'That model has been retired by $providerName and no longer accepts '
        'requests. Choose a current model — your API key is fine.',
        providerDetail: detail.message,
        statusCode: statusCode,
      );
    }

    if (code == 'model_not_found' ||
        (statusCode == 404 && text.contains('model'))) {
      return ProviderException(
        ProviderFailure.missingModel,
        '$providerName does not have a model with that name. Check the model '
        'ID, or refresh the model list.',
        providerDetail: detail.message,
        statusCode: statusCode,
      );
    }

    switch (statusCode) {
      case 400:
        return ProviderException(
          ProviderFailure.unexpectedResponse,
          '$providerName rejected the request as malformed. This is a defect '
          'in Anything rather than a problem with your key.',
          providerDetail: detail.message,
          statusCode: statusCode,
        );
      case 401:
        return ProviderException(
          ProviderFailure.invalidApiKey,
          'That key was rejected by $providerName. Check you copied all of '
          'it, and that it has not been revoked.',
          providerDetail: detail.message,
          statusCode: statusCode,
        );
      case 403:
        return ProviderException(
          ProviderFailure.permissionDenied,
          'That key is valid but is not allowed to use this model or '
          'endpoint. Check the permissions on your $providerName account.',
          providerDetail: detail.message,
          statusCode: statusCode,
        );
      case 404:
        return ProviderException(
          ProviderFailure.incorrectEndpoint,
          'Nothing was found at that address. Check the endpoint URL for '
          '$providerName.',
          providerDetail: detail.message,
          statusCode: statusCode,
        );
      case 408:
        return ProviderException(
          ProviderFailure.timeout,
          '$providerName timed out handling the request. Try again.',
          providerDetail: detail.message,
          statusCode: statusCode,
        );
      case 413:
        return ProviderException(
          ProviderFailure.unexpectedResponse,
          'The request was too large for $providerName. Try a shorter input.',
          providerDetail: detail.message,
          statusCode: statusCode,
        );
      case 429:
        return ProviderException(
          ProviderFailure.rateLimited,
          '$providerName is rate limiting this key. Wait a moment and try '
          'again.',
          providerDetail: detail.message,
          statusCode: statusCode,
        );
    }

    if (statusCode >= 500 && statusCode < 600) {
      return ProviderException(
        ProviderFailure.serverUnavailable,
        '$providerName is having trouble at their end. This is not a problem '
        'with your key — try again shortly.',
        providerDetail: detail.message,
        statusCode: statusCode,
      );
    }

    return ProviderException(
      ProviderFailure.unknown,
      '$providerName returned an unexpected response. Try again, and check '
      'Developer Mode if it keeps happening.',
      providerDetail: detail.message,
      statusCode: statusCode,
    );
  }

  /// Classifies a thrown transport error.
  ///
  /// A [ProviderException] passes through unchanged so callers can wrap a
  /// whole request without double-classifying.
  static ProviderException fromException(
    Object error, {
    required String providerName,
  }) {
    if (error is ProviderException) return error;

    if (error is TimeoutException) {
      return ProviderException(
        ProviderFailure.timeout,
        '$providerName did not respond in time. Check your connection and '
        'try again — this is not necessarily a problem with your key.',
        providerDetail: error.message,
      );
    }

    if (error is HandshakeException || error is CertificateException) {
      return ProviderException(
        ProviderFailure.sslFailure,
        'The secure connection to $providerName could not be established. '
        'This can happen on networks that intercept traffic.',
        providerDetail: error.toString(),
      );
    }

    if (error is SocketException) {
      return ProviderException(
        ProviderFailure.networkUnavailable,
        'Could not reach $providerName. Check your connection and try again '
        '— this is not necessarily a problem with your key.',
        providerDetail: error.message,
      );
    }

    if (error is FormatException) {
      return ProviderException(
        ProviderFailure.unexpectedResponse,
        '$providerName sent a response Anything could not read.',
        providerDetail: error.message,
      );
    }

    // Deliberately does NOT interpolate `error` into the user-facing message:
    // that is how stack traces reach a settings screen.
    return ProviderException(
      ProviderFailure.unknown,
      'Something went wrong talking to $providerName. Check Developer Mode '
      'for details if it keeps happening.',
      providerDetail: error.toString(),
    );
  }

  /// Pulls `error.message` / `error.code` out of an OpenAI-compatible body.
  ///
  /// Providers that return HTML (a proxy error page) or an empty body are
  /// normal, so this never throws.
  static ({String? message, String? code}) _extract(String body) {
    if (body.isEmpty) return (message: null, code: null);
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return (message: null, code: null);
      final error = decoded['error'];
      if (error is String) return (message: error, code: null);
      if (error is Map) {
        return (
          message: error['message'] as String?,
          // Some providers put the code on `code`, others on `type`.
          code: (error['code'] ?? error['type']) as String?,
        );
      }
      final message = decoded['message'];
      if (message is String) return (message: message, code: null);
    } catch (_) {
      // Not JSON. The status code alone still classifies it.
    }
    return (message: null, code: null);
  }
}
