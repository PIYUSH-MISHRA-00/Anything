/// ReminderPlanner — plans a declarative, one-time reminder for an
/// AutomationPlan scheduled `once` at a specific time. Never delivers
/// anything itself, same honesty boundary as NotificationPlanner.
library;

import 'automation_plan.dart';
import 'ril_types.dart';

class ReminderPlan {
  final String id;
  final String description;
  final DateTime? remindAt;

  const ReminderPlan({required this.id, required this.description, this.remindAt});
}

class ReminderPlanner {
  const ReminderPlanner();

  ReminderPlan? plan(AutomationPlan automationPlan) {
    if (automationPlan.schedule.frequency != ScheduleFrequency.once) return null;

    return ReminderPlan(id: 'reminder:${automationPlan.id}', description: automationPlan.description, remindAt: automationPlan.schedule.at);
  }
}
