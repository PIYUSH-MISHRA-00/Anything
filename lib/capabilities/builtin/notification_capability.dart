/// Notification capability — trusted local notification operations.
library;

import '../platform/capability_platform.dart';

/// Notification service abstraction.
abstract class NotificationService {
  Future<void> schedule({
    required String id,
    required String experienceId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  });
  Future<void> cancel(String id);
  Future<void> cancelAllForExperience(String experienceId);
}

/// Fake notification service for testing.
class FakeNotificationService implements NotificationService {
  final List<Map<String, dynamic>> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> schedule({
    required String id,
    required String experienceId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    scheduled.add({
      'id': id,
      'experienceId': experienceId,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
    });
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }

  @override
  Future<void> cancelAllForExperience(String experienceId) async {
    scheduled.removeWhere((n) => n['experienceId'] == experienceId);
  }
}

/// Notification capability for Experiences.
class NotificationCapability extends PlatformCapability {
  final NotificationService _service;
  final String _experienceId;

  NotificationCapability({
    required NotificationService service,
    required String experienceId,
  }) : _service = service,
       _experienceId = experienceId,
       super(
         id: 'notifications',
         name: 'Notifications',
         description: 'Local notification scheduling',
         supportedOperations: ['schedule', 'cancel', 'cancelAll'],
       );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    switch (operation) {
      case 'schedule':
        final title = params['title'] as String? ?? '';
        final body = params['body'] as String? ?? '';
        final hour = params['hour'] as int?;
        final minute = params['minute'] as int? ?? 0;

        if (title.isEmpty) {
          return const CapabilityInvocationResult(
            status: CapabilityResultStatus.invalidArguments,
            error: 'Notification title required',
          );
        }

        final now = DateTime.now();
        var scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour ?? 8,
          minute,
        );
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        final id = 'notif-${DateTime.now().millisecondsSinceEpoch}';
        await _service.schedule(
          id: id,
          experienceId: _experienceId,
          title: title,
          body: body,
          scheduledTime: scheduledTime,
        );

        return CapabilityInvocationResult.success(data: {'notificationId': id});

      case 'cancel':
        final id = params['notificationId'] as String?;
        if (id == null) {
          return const CapabilityInvocationResult(
            status: CapabilityResultStatus.invalidArguments,
            error: 'notificationId required',
          );
        }
        await _service.cancel(id);
        return CapabilityInvocationResult.success();

      case 'cancelAll':
        await _service.cancelAllForExperience(_experienceId);
        return CapabilityInvocationResult.success();

      default:
        return CapabilityInvocationResult(
          status: CapabilityResultStatus.unsupported,
          error: 'Unknown notification operation: $operation',
        );
    }
  }
}
