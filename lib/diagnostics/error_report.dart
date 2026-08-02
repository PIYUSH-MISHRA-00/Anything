/// ErrorReport — the typed boundary between a real, raw exception and
/// what a user is ever shown. "Every user-facing error must be safe,
/// helpful, redacted, recoverable, consistent. No raw exceptions."
/// [safeMessage] is always a caller-supplied, pre-written string — the
/// raw exception is only ever logged (developer-facing, via
/// StructuredLogger), never surfaced to [safeMessage] itself.
library;

import 'log_entry.dart';
import 'structured_logger.dart';

class ErrorReport {
  final LogCategory category;
  final String safeMessage;
  final bool recoverable;
  final DateTime timestamp;

  ErrorReport({required this.category, required this.safeMessage, this.recoverable = true, DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();

  /// Logs the real exception (developer-facing only, via the given
  /// logger) and returns a report carrying ONLY the safe, pre-written
  /// [userFacingMessage] — the exception's own `toString()`/stack trace
  /// never reaches the returned report.
  factory ErrorReport.from(
    Object error, {
    required LogCategory category,
    required String userFacingMessage,
    bool recoverable = true,
    StructuredLogger? logger,
    StackTrace? stackTrace,
  }) {
    logger?.error(category, 'Handled exception: ${error.runtimeType}');
    return ErrorReport(category: category, safeMessage: userFacingMessage, recoverable: recoverable);
  }
}
