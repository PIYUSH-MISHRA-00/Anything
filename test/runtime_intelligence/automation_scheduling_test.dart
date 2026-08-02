/// Vision V8 RIL — AutomationPlanner, AutomationExecutor (validation-only,
/// NEVER executes), AutomationHistory/AutomationMemory, BackgroundCoordinator
/// (Scheduling), NotificationPlanner, ReminderPlanner.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/runtime_intelligence/automation_executor.dart';
import 'package:anything/runtime_intelligence/automation_history.dart';
import 'package:anything/runtime_intelligence/automation_memory.dart';
import 'package:anything/runtime_intelligence/automation_planner.dart';
import 'package:anything/runtime_intelligence/automation_types.dart';
import 'package:anything/runtime_intelligence/background_coordinator.dart';
import 'package:anything/runtime_intelligence/notification_planner.dart';
import 'package:anything/runtime_intelligence/recommendation.dart';
import 'package:anything/runtime_intelligence/reminder_planner.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/software_architect/confidence.dart';

Recommendation _recommendation(RecommendationKind kind) => Recommendation(
  id: 'rec-${kind.name}',
  kind: kind,
  description: 'Every morning, open dashboard, refresh knowledge, summarize updates, notify user',
  reason: const RecommendationReason(
    summary: 's',
    evidence: RecommendationEvidence(patternId: 'p', usageGraphNodeOrEdgeId: 'n'),
    confidence: Confidence.full,
  ),
);

CapabilityRegistry _registryWith(List<String> ids) {
  final registry = CapabilityRegistry();
  for (final id in ids) {
    registry.register(
      CapabilityDescriptor(
        id: id,
        version: '1.0.0',
        name: id,
        description: id,
        category: CapabilityCategory.storage,
        inputContract: 'x',
        outputContract: 'y',
      ),
    );
  }
  return registry;
}

void main() {
  group('AutomationPlanner', () {
    const planner = AutomationPlanner();

    test('plans a real declarative AutomationPlan for an automation-shaped recommendation', () {
      final plan = planner.plan(_recommendation(RecommendationKind.automation));
      expect(plan, isNotNull);
      expect(plan!.steps, isNotEmpty);
      expect(plan.steps.every((s) => s.capabilityId.isNotEmpty), isTrue);
    });

    test('plans nothing for a non-automation, non-workflow recommendation — never fabricates a plan', () {
      expect(planner.plan(_recommendation(RecommendationKind.newFeature)), isNull);
      expect(planner.plan(_recommendation(RecommendationKind.securityImprovement)), isNull);
    });
  });

  group('AutomationExecutor — validation only, never executes', () {
    const planner = AutomationPlanner();
    const executor = AutomationExecutor();

    test('every step resolves eligible when its capability is registered', () {
      final plan = planner.plan(_recommendation(RecommendationKind.automation))!;
      final registry = _registryWith(['clock', 'notifications']);
      final report = executor.validate(plan, registry);
      expect(report.allEligible, isTrue);
    });

    test('a step naming an unregistered capability is honestly blocked, never silently skipped', () {
      final plan = planner.plan(_recommendation(RecommendationKind.automation))!;
      final registry = _registryWith(['clock']); // 'notifications' missing
      final report = executor.validate(plan, registry);
      expect(report.allEligible, isFalse);
      expect(
        report.steps.any((s) => s.step.capabilityId == 'notifications' && s.eligibility == AutomationStepEligibility.blockedMissingCapability),
        isTrue,
      );
    });
  });

  group('AutomationHistory + AutomationMemory', () {
    test('every planned automation is recorded, versioned, and recallable by plan id', () {
      const planner = AutomationPlanner();
      const executor = AutomationExecutor();
      final history = AutomationHistory();
      final memory = AutomationMemory();
      final registry = _registryWith(['clock', 'notifications']);

      final plan = planner.plan(_recommendation(RecommendationKind.automation))!;
      final report = executor.validate(plan, registry);
      final record = AutomationRecord(plan: plan, report: report, plannedAt: DateTime.now(), version: 1);

      history.record(record);
      memory.record(record);

      expect(history.records, hasLength(1));
      expect(memory.recall(plan.id), isNotNull);
      expect(memory.recall('does-not-exist'), isNull);
    });
  });

  group('BackgroundCoordinator — declarative scheduling only', () {
    const planner = AutomationPlanner();

    test('queues eligible plans up to the budget, never exceeding it', () {
      final plans = List.generate(
        5,
        (i) => planner.plan(_recommendation(RecommendationKind.automation), frequency: ScheduleFrequency.daily)!,
      );
      const coordinator = BackgroundCoordinator(budget: BackgroundBudget(maxJobs: 3));
      final jobs = coordinator.queue(plans);
      expect(jobs, hasLength(3));
      for (final job in jobs) {
        expect(job.schedule.frequency, ScheduleFrequency.daily);
      }
    });

    test('a policy that disallows conditional schedules filters them out', () {
      final conditionalPlan = planner.plan(_recommendation(RecommendationKind.automation), frequency: ScheduleFrequency.conditional)!;
      const coordinator = BackgroundCoordinator(policy: BackgroundPolicy(allowConditionalSchedules: false));
      final jobs = coordinator.queue([conditionalPlan]);
      expect(jobs, isEmpty);
    });
  });

  group('NotificationPlanner + ReminderPlanner', () {
    const planner = AutomationPlanner();

    test('NotificationPlanner plans only for automation plans with a real notifications step', () {
      const notificationPlanner = NotificationPlanner();
      final plan = planner.plan(_recommendation(RecommendationKind.automation))!;
      expect(notificationPlanner.plan(plan), isNotNull);
    });

    test('ReminderPlanner plans only for "once"-scheduled automation plans', () {
      const reminderPlanner = ReminderPlanner();
      final oncePlan = planner.plan(_recommendation(RecommendationKind.automation), frequency: ScheduleFrequency.once)!;
      final dailyPlan = planner.plan(_recommendation(RecommendationKind.automation), frequency: ScheduleFrequency.daily)!;

      expect(reminderPlanner.plan(oncePlan), isNotNull);
      expect(reminderPlanner.plan(dailyPlan), isNull);
    });
  });
}
