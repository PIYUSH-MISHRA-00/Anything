/// Immutable snapshot of a creation request at submission time.
///
/// Downstream planning/generation must use this object rather than reading
/// mutable composer UI state after submit.
library;

import 'package:uuid/uuid.dart';

/// Frozen creation request — IS-P12.
class CreationRequest {
  final String requestId;
  final String rawPrompt;
  final String normalizedPrompt;
  final DateTime timestamp;
  final String? providerId;
  final String? modelId;

  const CreationRequest({
    required this.requestId,
    required this.rawPrompt,
    required this.normalizedPrompt,
    required this.timestamp,
    this.providerId,
    this.modelId,
  });

  factory CreationRequest.capture({
    required String rawPrompt,
    String? providerId,
    String? modelId,
    DateTime? timestamp,
  }) {
    final raw = rawPrompt;
    return CreationRequest(
      requestId: const Uuid().v4(),
      rawPrompt: raw,
      normalizedPrompt: normalizePrompt(raw),
      timestamp: timestamp ?? DateTime.now(),
      providerId: providerId,
      modelId: modelId,
    );
  }

  static String normalizePrompt(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic> toDiagnosticJson() => {
    'requestId': requestId,
    'rawPrompt': rawPrompt,
    'normalizedPrompt': normalizedPrompt,
    'timestamp': timestamp.toIso8601String(),
    if (providerId != null) 'providerId': providerId,
    if (modelId != null) 'modelId': modelId,
  };
}
