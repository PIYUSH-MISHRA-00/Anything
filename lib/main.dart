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
/// They REPORT and nothing else: no crash-reporting SDK is a dependency of
/// this project, and adding one is a product decision (recorded as the
/// telemetry gap), not something to smuggle into an entry point.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';

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
void _report(Object error, StackTrace? stack, String source) {
  // `debugPrint` is rate-limited by Flutter and is a no-op-ish sink in
  // release; it is deliberately the whole implementation until a reporting
  // backend is chosen. Release stack traces stay readable because
  // proguard-rules.pro keeps SourceFile and LineNumberTable.
  debugPrint('[anything:$source] $error');
  if (stack != null) debugPrintStack(stackTrace: stack);
}
