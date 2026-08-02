/// LearningMemory — every LearningRecord ever learned, in order and
/// versioned. Nothing is ever removed or overwritten; Recommendation and
/// Automation Planning reuse this record rather than re-learning.
library;

import 'learning_record.dart';

class LearningMemory {
  final List<LearningRecord> _records = [];

  void record(LearningRecord record) => _records.add(record);

  List<LearningRecord> get records => List.unmodifiable(_records);

  int get currentVersion => _records.isEmpty ? 0 : _records.map((r) => r.version).reduce((a, b) => a > b ? a : b);

  LearningRecord? latestForPattern(String patternId) {
    for (var i = _records.length - 1; i >= 0; i--) {
      if (_records[i].pattern.id == patternId) return _records[i];
    }
    return null;
  }
}
