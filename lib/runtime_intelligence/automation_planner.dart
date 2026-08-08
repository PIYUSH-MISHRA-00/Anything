/// AutomationPlanner — Automation. Turns an accepted, automation-shaped
/// Recommendation into a declarative AutomationPlan — never executable
/// code, only a typed description of what would happen and when.
library;

import 'automation_plan.dart';
import 'automation_types.dart';
import 'recommendation.dart';
import 'ril_types.dart';

class AutomationPlanner {
  const AutomationPlanner();

  /// Returns null for recommendations that aren't automation/workflow
  /// shaped — never fabricates a plan for something that isn't one.
  AutomationPlan? plan(
    Recommendation recommendation, {
    ScheduleFrequency frequency = ScheduleFrequency.daily,
  }) {
    if (recommendation.kind != RecommendationKind.automation &&
        recommendation.kind != RecommendationKind.workflow) {
      return null;
    }

    return AutomationPlan(
      id: 'automation:${recommendation.id}',
      description: recommendation.description,
      steps: [
        AutomationCandidate(
          id: 'step:${recommendation.id}:trigger',
          capabilityId: 'clock',
          description: 'Trigger on schedule',
        ),
        AutomationCandidate(
          id: 'step:${recommendation.id}:notify',
          capabilityId: 'notifications',
          description: 'Notify the user the automation ran',
        ),
      ],
      schedule: AutomationSchedule(frequency: frequency),
      confidence: recommendation.reason.confidence,
    );
  }
}
