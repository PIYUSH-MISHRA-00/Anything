/// Structured creation diagnostics — IS-P10.
///
/// Correlates a single creation attempt across planning → validation →
/// install without logging secrets, API keys, or raw provider payloads.
library;

import '../diagnostics/log_entry.dart';
import '../diagnostics/structured_logger.dart';

/// Stage names for the production creation pipeline.
abstract final class CreationStage {
  static const provider = 'provider';
  static const planning = 'planning';
  static const reasoning = 'reasoning';
  static const knowledge = 'knowledge';
  static const capabilities = 'capabilities';
  static const schema = 'schema';
  static const validation = 'validation';
  static const repair = 'repair';
  static const creation = 'creation';
  static const install = 'install';
  static const runtime = 'runtime';
}

/// One structured creation diagnostic event.
class CreationDiagnostic {
  final String requestId;
  final String stage;
  final String? errorType;
  final String? errorMessage;
  final bool? retryable;
  final bool? userRecoverable;
  final String? provider;
  final String? model;
  final Map<String, String> details;
  final DateTime timestamp;

  CreationDiagnostic({
    required this.requestId,
    required this.stage,
    this.errorType,
    this.errorMessage,
    this.retryable,
    this.userRecoverable,
    this.provider,
    this.model,
    this.details = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Safe one-line summary for logs / Developer Mode (no secrets).
  String get summary {
    final buf = StringBuffer('[$requestId] stage=$stage');
    if (provider != null) buf.write(' provider=$provider');
    if (model != null) buf.write(' model=$model');
    if (errorType != null) buf.write(' errorType=$errorType');
    if (errorMessage != null) buf.write(' message=$errorMessage');
    if (retryable != null) buf.write(' retryable=$retryable');
    if (userRecoverable != null) {
      buf.write(' userRecoverable=$userRecoverable');
    }
    for (final e in details.entries) {
      buf.write(' ${e.key}=${e.value}');
    }
    return buf.toString();
  }
}

/// Ring of recent creation diagnostics for Developer Mode.
class CreationDiagnostics {
  CreationDiagnostics({StructuredLogger? logger}) : _logger = logger;

  final StructuredLogger? _logger;
  final List<CreationDiagnostic> _recent = [];
  static const _max = 40;

  List<CreationDiagnostic> get recent => List.unmodifiable(_recent);

  String nextRequestId() =>
      'cr-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';

  void record(CreationDiagnostic diagnostic) {
    _recent.add(diagnostic);
    if (_recent.length > _max) {
      _recent.removeRange(0, _recent.length - _max);
    }
    final severity = diagnostic.errorType == null
        ? LogSeverity.info
        : LogSeverity.error;
    _logger?.log(
      severity,
      LogCategory.creation,
      diagnostic.summary,
      requestId: diagnostic.requestId,
    );
  }

  void clear() => _recent.clear();
}
