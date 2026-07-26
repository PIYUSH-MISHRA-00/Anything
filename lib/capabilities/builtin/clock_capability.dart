/// Clock capability — trusted time operations for Experiences.
library;

import '../platform/capability_platform.dart';

/// Clock capability providing time operations.
class ClockCapability extends PlatformCapability {
  ClockCapability()
    : super(
        id: 'clock',
        name: 'Clock',
        description: 'Time and date operations',
        supportedOperations: ['now', 'date', 'time', 'format'],
      );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    switch (operation) {
      case 'now':
        return CapabilityInvocationResult.success(
          data: {
            'timestamp': DateTime.now().toIso8601String(),
            'year': DateTime.now().year,
            'month': DateTime.now().month,
            'day': DateTime.now().day,
            'hour': DateTime.now().hour,
            'minute': DateTime.now().minute,
            'second': DateTime.now().second,
          },
        );
      case 'date':
        final now = DateTime.now();
        return CapabilityInvocationResult.success(
          data: {
            'year': now.year,
            'month': now.month,
            'day': now.day,
            'weekday': now.weekday,
          },
        );
      case 'time':
        final now = DateTime.now();
        return CapabilityInvocationResult.success(
          data: {'hour': now.hour, 'minute': now.minute, 'second': now.second},
        );
      default:
        return CapabilityInvocationResult(
          status: CapabilityResultStatus.unsupported,
          error: 'Unknown clock operation: $operation',
        );
    }
  }
}
