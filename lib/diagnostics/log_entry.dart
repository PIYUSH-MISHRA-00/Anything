/// Structured Logging — Vision Milestone V10. Repository audit confirmed
/// zero centralized logging infrastructure exists today (the only prior
/// art was an ad hoc, uncategorized `debugPrint` shadow in
/// lib/services/analytics_service.dart) — this is the first real,
/// typed, categorized logging vocabulary in this codebase.
library;

enum LogSeverity { debug, info, warning, error }

/// Every category this milestone's Diagnostics section names — "Everything
/// categorized," never an uncategorized log line.
enum LogCategory {
  kernel,
  runtime,
  knowledge,
  worldModel,
  evolution,
  reviewEngine,
  storage,
  security,
  ui,
  automation,

  /// The AI provider boundary — provider selection and verification, model
  /// selection, and every outbound model call (IS-P07). Added because the
  /// one subsystem that reaches the network on a user's behalf, spends their
  /// quota and fails in a dozen distinguishable ways had no category at all.
  aiProvider,

  /// The creation pipeline — reasoning, package assembly, validation and
  /// persistence (IS-P07). Added because a creation that fails validation
  /// tells the user only "Could not complete this app": the specific
  /// validator errors existed, were attached to the result, and were then
  /// displayed nowhere at all.
  creation,
}

/// One structured log line. [message] must never contain raw exception
/// text, stack traces, or personal content — callers are responsible for
/// passing an already-safe string (see ErrorReport for the typed
/// exception-to-safe-message boundary).
class LogEntry {
  final LogSeverity severity;
  final LogCategory category;
  final String message;
  final DateTime timestamp;

  /// Correlates the lines belonging to one operation (IS-P07).
  ///
  /// A single model call emits a request line, a result line and possibly a
  /// failure line. Without an id they are three unrelated lines in a log that
  /// also contains everything else happening at the same moment.
  final String? requestId;

  LogEntry({
    required this.severity,
    required this.category,
    required this.message,
    this.requestId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] ${severity.name.toUpperCase()} '
      '(${category.name})${requestId == null ? '' : ' [$requestId]'} $message';
}
