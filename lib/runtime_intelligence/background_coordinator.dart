/// BackgroundCoordinator — Background Execution. Produces a typed,
/// declarative queue of BackgroundJobs from validated AutomationPlans.
/// Only declarative jobs: no isolate is ever spawned here, no arbitrary
/// code is ever referenced — a BackgroundJob only ever names an
/// AutomationPlan and its schedule. Real OS-level scheduling does not
/// exist in this codebase (confirmed by repository audit: no
/// flutter_local_notifications/workmanager/cron dependency, no
/// Timer.periodic/AlarmManager usage anywhere) — this coordinator
/// produces the typed plan a future milestone's real scheduler would
/// consume, honestly, never fabricating live execution.
library;

import 'automation_plan.dart';
import 'automation_types.dart';
import 'ril_types.dart';

class BackgroundJob {
  final String id;
  final AutomationPlan plan;
  final AutomationSchedule schedule;

  const BackgroundJob({
    required this.id,
    required this.plan,
    required this.schedule,
  });
}

class BackgroundCoordinator {
  final BackgroundBudget budget;
  final BackgroundPolicy policy;

  const BackgroundCoordinator({
    this.budget = const BackgroundBudget(),
    this.policy = const BackgroundPolicy(),
  });

  /// Only ever reads AutomationPlans already validated eligible by
  /// AutomationExecutor — never plans a job for a blocked plan.
  List<BackgroundJob> queue(List<AutomationPlan> eligiblePlans) {
    final filtered = policy.allowConditionalSchedules
        ? eligiblePlans
        : eligiblePlans
              .where(
                (p) => p.schedule.frequency != ScheduleFrequency.conditional,
              )
              .toList();

    return filtered
        .take(budget.maxJobs)
        .map(
          (plan) => BackgroundJob(
            id: 'job:${plan.id}',
            plan: plan,
            schedule: plan.schedule,
          ),
        )
        .toList();
  }
}
