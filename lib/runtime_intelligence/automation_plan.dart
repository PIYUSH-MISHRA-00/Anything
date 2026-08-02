/// AutomationPlan — a declarative description of what would happen, and
/// when. NOT executable code: every step names an existing capability id
/// only. Nothing in this file ever invokes anything.
library;

import '../software_architect/confidence.dart';
import 'automation_types.dart';

class AutomationCandidate {
  final String id;
  final String capabilityId;
  final String description;

  const AutomationCandidate({required this.id, required this.capabilityId, required this.description});
}

class AutomationPlan {
  final String id;
  final String description;
  final List<AutomationCandidate> steps;
  final AutomationSchedule schedule;
  final Confidence confidence;

  const AutomationPlan({
    required this.id,
    required this.description,
    required this.steps,
    required this.schedule,
    required this.confidence,
  });
}
