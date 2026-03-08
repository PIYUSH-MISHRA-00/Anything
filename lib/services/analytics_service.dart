import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

class AnalyticsService {
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    // In production, integrate Firebase or Mixpanel
    debugPrint('Analytics: $eventName - $parameters');
  }

  void recordError(dynamic exception, StackTrace stack) {
    // In production, integrate Crashlytics or Sentry
    debugPrint('Crash Log: $exception\\n$stack');
  }

  void logPerformance(String traceName, int durationMs) {
    // Performance monitoring metric
    debugPrint('Performance [id=$traceName]: ${durationMs}ms');
  }
}

void debugPrint(String message) {
  // Safe print for internal stub usage
  // ignore: avoid_print
  print(message);
}
