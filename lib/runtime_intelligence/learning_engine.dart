/// LearningEngine — Learning. Runs PatternDetector over a UsageGraph and
/// records the result into LearningMemory, versioned. Deterministic:
/// given the same UsageGraph and threshold, produces the same patterns
/// every time — never a probabilistic model.
library;

import 'learning_memory.dart';
import 'learning_record.dart';
import 'pattern_detector.dart';
import 'usage_graph.dart';

class LearningEngine {
  final PatternDetector _detector;

  const LearningEngine({PatternDetector detector = const PatternDetector()})
    : _detector = detector;

  List<LearningRecord> learn(
    UsageGraph graph,
    LearningMemory memory, {
    int minOccurrences = 2,
  }) {
    final patterns = _detector.detect(graph, minOccurrences: minOccurrences);
    final version = memory.currentVersion + 1;
    final now = DateTime.now();

    final records = patterns
        .map(
          (pattern) => LearningRecord(
            id: 'learning:${pattern.id}:v$version',
            pattern: pattern,
            learnedAt: now,
            version: version,
          ),
        )
        .toList();

    for (final record in records) {
      memory.record(record);
    }
    return records;
  }
}
