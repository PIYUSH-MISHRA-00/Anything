/// LearningRecord — one Pattern the LearningEngine has learned, versioned
/// and timestamped. Everything anonymous and structural: a LearningRecord
/// never carries anything beyond the Pattern that produced it.
library;

import 'pattern.dart';

class LearningRecord {
  final String id;
  final Pattern pattern;
  final DateTime learnedAt;
  final int version;

  const LearningRecord({required this.id, required this.pattern, required this.learnedAt, required this.version});
}
