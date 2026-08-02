/// AutomationMemory — accepted/blocked automation plans, retrievable by
/// plan id. Mirrors EvolutionMemory (V7)'s recall-by-key shape.
library;

import 'automation_history.dart';

class AutomationMemory {
  final List<AutomationRecord> _records = [];

  void record(AutomationRecord record) => _records.add(record);

  AutomationRecord? recall(String planId) {
    for (var i = _records.length - 1; i >= 0; i--) {
      if (_records[i].plan.id == planId) return _records[i];
    }
    return null;
  }

  List<AutomationRecord> get records => List.unmodifiable(_records);

  int get recordCount => _records.length;
}
