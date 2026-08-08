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

  LogEntry({
    required this.severity,
    required this.category,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] ${severity.name.toUpperCase()} (${category.name}) $message';
}
