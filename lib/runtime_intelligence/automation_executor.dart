/// AutomationExecutor — validates that an AutomationPlan's steps
/// reference real, resolvable capabilities. Deliberately never executes
/// anything: this milestone's own directive is "NOT executable code.
/// Declarative plans," and the repository audit confirmed no real OS-
/// level background execution exists yet (NotificationCapability
/// delegates to an in-memory FakeNotificationService only). Reuses the
/// EXISTING CapabilityRegistry.resolve() — never a second capability
/// resolution mechanism.
library;

import '../capabilities/registry/capability_registry.dart';
import 'automation_plan.dart';
import 'ril_types.dart';

class AutomationStepReport {
  final AutomationCandidate step;
  final AutomationStepEligibility eligibility;
  final String reason;

  const AutomationStepReport({required this.step, required this.eligibility, required this.reason});
}

class AutomationExecutionReport {
  final AutomationPlan plan;
  final List<AutomationStepReport> steps;

  const AutomationExecutionReport({required this.plan, required this.steps});

  bool get allEligible => steps.every((s) => s.eligibility == AutomationStepEligibility.eligible);
}

class AutomationExecutor {
  const AutomationExecutor();

  /// Validates structural soundness only — never invokes a capability,
  /// never schedules anything, never runs any code.
  AutomationExecutionReport validate(AutomationPlan plan, CapabilityRegistry registry) {
    final resolutions = registry.resolve(plan.steps.map((s) => s.capabilityId).toList());
    final resolutionById = {for (final r in resolutions) r.capabilityId: r};

    final reports = plan.steps.map((step) {
      final resolution = resolutionById[step.capabilityId];
      final eligible = resolution?.isResolved ?? false;
      return AutomationStepReport(
        step: step,
        eligibility: eligible ? AutomationStepEligibility.eligible : AutomationStepEligibility.blockedMissingCapability,
        reason: eligible ? 'Capability "${step.capabilityId}" is registered and available.' : (resolution?.reason ?? 'Capability not registered.'),
      );
    }).toList();

    return AutomationExecutionReport(plan: plan, steps: reports);
  }
}
