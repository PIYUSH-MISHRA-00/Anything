/// Anything — application entry point.
///
/// The ONE entry point in this repository, certified by I-85: exactly one
/// `main()` reaching exactly one app widget, with no `ProviderScope` (the
/// clause that keeps the unreachable v1 application inert).
///
/// ERROR REPORTING (IS-P01). Before P01 this file had no error boundary of any
/// kind — measured: zero occurrences of `FlutterError.onError`,
/// `runZonedGuarded` or `PlatformDispatcher.instance.onError` anywhere in
/// `lib/`. An uncaught exception in a release build showed a red screen and
/// was never recorded, so a shipped failure was invisible to everyone.
///
/// The three handlers below cover the three genuinely distinct paths an error
/// can take out of a Flutter app — framework, platform, and asynchronous zone.
///
/// IS-P04: they now also PERSIST. The IS-P03 audit found that all three ended
/// at `debugPrint`, which reaches logcat and nothing else — so the evidence
/// died with the process and a user who hit a crash had nothing to send.
/// `CrashLog` keeps the last 20 failures in the app's own documents directory.
///
/// Still no crash-reporting SDK, and still deliberately: choosing a backend is
/// a product and privacy decision for a local-first project. `CrashLog` is the
/// seam that decision plugs into.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/crash_log.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Framework errors — build, layout and paint.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _report(details.exception, details.stack, 'flutter');
      };

      // Errors that reach the platform without passing through the framework.
      PlatformDispatcher.instance.onError = (error, stack) {
        _report(error, stack, 'platform');
        return true;
      };

      runApp(const AnythingApp());
    },
    // Uncaught asynchronous errors, which neither handler above sees.
    (error, stack) => _report(error, stack, 'zone'),
  );
}

/// Single reporting sink, so wiring a crash reporter later is one edit here
/// rather than three.
const CrashLog _crashLog = CrashLog();

void _report(Object error, StackTrace? stack, String source) {
  // Console first: during development this is what a developer actually sees,
  // and it costs nothing. Release stack traces stay readable because
  // proguard-rules.pro keeps SourceFile and LineNumberTable.
  debugPrint('[anything:$source] $error');
  if (stack != null) debugPrintStack(stackTrace: stack);

  // Then durably, so the failure survives the process. Deliberately NOT
  // awaited: this runs inside an error handler, and blocking one — or letting
  // it throw — turns a single failure into a compounded one. `CrashLog.record`
  // swallows its own errors for the same reason.
  unawaited(_crashLog.record(error, stack, source));
}
