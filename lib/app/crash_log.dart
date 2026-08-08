/// Durable crash log — Implementation Specification IS-P04.
///
/// WHAT THE IS-P03 AUDIT FOUND. `main.dart` installed three error handlers in
/// IS-P01, and all three ended at `debugPrint`. That reaches logcat and
/// nothing else: the moment the process ends, the evidence is gone. A user who
/// hits a crash has nothing to send, and a maintainer has nothing to read.
/// Recorded as security finding S-2 and Play category 4 ("crash resilience").
///
/// WHAT THIS IS, AND DELIBERATELY IS NOT.
///
/// It is a small on-device ring buffer: the last [maxEntries] crashes, written
/// to one file inside the app's own documents directory. It adds NO
/// dependency -- `path_provider` is already used by `RealFileService` (R49) --
/// and it sends nothing anywhere.
///
/// It is NOT telemetry. Choosing a crash-reporting backend is a product and
/// privacy decision for a local-first project, and the IS-P03 audit recorded
/// it as an open decision rather than something to smuggle into an entry
/// point. When that decision is made, this class is the seam it plugs into.
///
/// FAILING SAFELY IS THE WHOLE POINT. Every operation is wrapped: a crash
/// logger that throws while logging a crash turns one failure into two, and
/// on the zone path it could recurse. Nothing here rethrows, and nothing here
/// awaits inside the caller's error handler.
library;

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CrashLog {
  /// How many entries survive. Small on purpose: this is a diagnostic aid, not
  /// an archive, and an unbounded file on a phone is a bug waiting to happen.
  static const int maxEntries = 20;

  static const String fileName = 'anything_crashes.log';

  /// Separates entries. Chosen so a stack trace, which is full of newlines,
  /// cannot be mistaken for a record boundary.
  static const String separator = '\n===== ANYTHING CRASH =====\n';

  final Directory? _rootOverride;

  const CrashLog({Directory? rootOverride}) : _rootOverride = rootOverride;

  Future<File?> _file() async {
    try {
      final base = _rootOverride ?? await getApplicationDocumentsDirectory();
      return File('${base.path}${Platform.pathSeparator}$fileName');
    } catch (_) {
      // No documents directory (a test host, a locked-down device). Logging is
      // best-effort by definition.
      return null;
    }
  }

  /// Records one failure. Never throws, and never rethrows.
  Future<void> record(
    Object error,
    StackTrace? stack,
    String source, {
    DateTime? at,
  }) async {
    try {
      final file = await _file();
      if (file == null) return;

      final entry = StringBuffer()
        ..writeln('when   : ${(at ?? DateTime.now()).toIso8601String()}')
        ..writeln('source : $source')
        ..writeln('error  : $error');
      if (stack != null) entry.writeln('stack  :\n$stack');

      final existing = file.existsSync() ? file.readAsStringSync() : '';
      final entries = _split(existing)..add(entry.toString().trimRight());

      // Keep the most recent. Trimming on write rather than on read means the
      // file cannot grow between reads.
      final kept = entries.length > maxEntries
          ? entries.sublist(entries.length - maxEntries)
          : entries;

      file.parent.createSync(recursive: true);
      file.writeAsStringSync(kept.map((e) => separator + e).join());
    } catch (_) {
      // Swallowed on purpose. A logger that throws while logging a crash makes
      // one failure into two, and on the zone path it can recurse.
    }
  }

  /// Every recorded crash, oldest first. Empty when nothing has been recorded.
  Future<List<String>> read() async {
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return const [];
      return _split(file.readAsStringSync());
    } catch (_) {
      return const [];
    }
  }

  /// Clears the log. Exposed so a future "send report" or "clear diagnostics"
  /// action has something to call.
  Future<void> clear() async {
    try {
      final file = await _file();
      if (file != null && file.existsSync()) file.deleteSync();
    } catch (_) {
      // Same reasoning as `record`.
    }
  }

  static List<String> _split(String raw) => raw
      .split(separator)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
