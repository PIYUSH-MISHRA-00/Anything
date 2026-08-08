/// Automation + Scheduling — shared typed vocabulary. Every schedule and
/// constraint is fully typed; nothing here ever runs arbitrary code —
/// these are declarative descriptions of when/whether an AutomationPlan
/// would be eligible to run, consulted by BackgroundCoordinator.
library;

import 'ril_types.dart';

class AutomationConstraint {
  final AutomationConstraintKind kind;
  final String? requiredCapabilityId;

  const AutomationConstraint({required this.kind, this.requiredCapabilityId});
}

class AutomationSchedule {
  final ScheduleFrequency frequency;
  final List<AutomationConstraint> constraints;
  final DateTime? at;

  const AutomationSchedule({
    required this.frequency,
    this.constraints = const [],
    this.at,
  });
}

class BackgroundBudget {
  final int maxJobs;

  const BackgroundBudget({this.maxJobs = 20});
}

class BackgroundPolicy {
  final bool allowConditionalSchedules;

  const BackgroundPolicy({this.allowConditionalSchedules = true});
}
