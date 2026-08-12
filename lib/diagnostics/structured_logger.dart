/// StructuredLogger — writes typed LogEntries via `dart:developer`'s
/// real, already-available `log()` (never a new logging dependency),
/// with a real (if intentionally modest) redaction pass. Also retains an
/// in-memory ring buffer so Diagnostics reports can show "recent log
/// activity" without a second logging destination.
library;

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'log_entry.dart';

class StructuredLogger {
  final int _maxBuffer;
  final List<LogEntry> _buffer = [];

  StructuredLogger({int maxBuffer = 200}) : _maxBuffer = maxBuffer;

  /// A deliberately modest, honest redaction: strips patterns that look
  /// like emails or bearer/API tokens. This is NOT a comprehensive PII
  /// scrubber — callers must still avoid passing sensitive content in
  /// the first place; this is a last-resort safety net, documented as
  /// such, never oversold as complete.
  static String redact(String message) {
    var result = message.replaceAll(
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'),
      '[redacted-email]',
    );
    result = result.replaceAll(
      RegExp(
        r'\b(?:Bearer|token)[:=]?\s*[A-Za-z0-9._-]{8,}',
        caseSensitive: false,
      ),
      '[redacted-token]',
    );
    return result;
  }

  void log(
    LogSeverity severity,
    LogCategory category,
    String message, {
    String? requestId,
  }) {
    final entry = LogEntry(
      severity: severity,
      category: category,
      message: redact(message),
      requestId: requestId,
    );
    _buffer.add(entry);
    if (_buffer.length > _maxBuffer) _buffer.removeAt(0);

    developer.log(
      requestId == null ? entry.message : '[$requestId] ${entry.message}',
      name: category.name,
      level: _levelFor(severity),
      time: entry.timestamp,
    );

    // `dart:developer`'s log() is invisible in `adb logcat` on release
    // builds, which made runtime subsystem activity (knowledge acquisition,
    // protection) unprovable on a real device. Mirror info+ entries through
    // debugPrint — same redacted message, same `[anything:<category>]`
    // convention main.dart already uses for crash reporting.
    if (severity != LogSeverity.debug) {
      debugPrint('[anything:${category.name}] ${entry.message}');
    }
  }

  void debug(LogCategory category, String message, {String? requestId}) =>
      log(LogSeverity.debug, category, message, requestId: requestId);
  void info(LogCategory category, String message, {String? requestId}) =>
      log(LogSeverity.info, category, message, requestId: requestId);
  void warning(LogCategory category, String message, {String? requestId}) =>
      log(LogSeverity.warning, category, message, requestId: requestId);
  void error(LogCategory category, String message, {String? requestId}) =>
      log(LogSeverity.error, category, message, requestId: requestId);

  List<LogEntry> get recent => List.unmodifiable(_buffer);

  List<LogEntry> recentOfCategory(LogCategory category) =>
      _buffer.where((e) => e.category == category).toList();

  int _levelFor(LogSeverity severity) => switch (severity) {
    LogSeverity.debug => 500,
    LogSeverity.info => 800,
    LogSeverity.warning => 900,
    LogSeverity.error => 1000,
  };
}
