/// AutomationHistory — every AutomationPlan ever planned and validated,
/// in order, versioned. Nothing is ever removed or overwritten.
library;

import 'automation_executor.dart';
import 'automation_plan.dart';

class AutomationRecord {
  final AutomationPlan plan;
  final AutomationExecutionReport report;
  final DateTime plannedAt;
  final int version;

  const AutomationRecord({
    required this.plan,
    required this.report,
    required this.plannedAt,
    required this.version,
  });
}

class AutomationHistory {
  final List<AutomationRecord> _records = [];

  void record(AutomationRecord record) => _records.add(record);

  List<AutomationRecord> get records => List.unmodifiable(_records);

  int get recordCount => _records.length;
}
