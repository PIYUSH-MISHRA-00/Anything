/// NotificationPlanner — plans a declarative notification for an
/// AutomationPlan that includes a `notifications` capability step. Never
/// delivers a notification itself — the existing `notifications`
/// capability (lib/capabilities/builtin/notification_capability.dart)
/// would eventually do that, and today only has an in-memory
/// FakeNotificationService backing it (confirmed by repository audit).
library;

import 'automation_plan.dart';
import 'automation_types.dart';

class NotificationPlan {
  final String id;
  final String description;
  final AutomationSchedule schedule;

  const NotificationPlan({
    required this.id,
    required this.description,
    required this.schedule,
  });
}

class NotificationPlanner {
  const NotificationPlanner();

  NotificationPlan? plan(AutomationPlan automationPlan) {
    final hasNotificationStep = automationPlan.steps.any(
      (s) => s.capabilityId == 'notifications',
    );
    if (!hasNotificationStep) return null;

    return NotificationPlan(
      id: 'notification:${automationPlan.id}',
      description: automationPlan.description,
      schedule: automationPlan.schedule,
    );
  }
}
