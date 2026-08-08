/// Pattern — a real, structural regularity PatternDetector found in a
/// UsageGraph. Never a domain template: every pattern traces to real,
/// counted UsageGraph nodes/edges via [PatternEvidence].
library;

import 'ril_types.dart';

class PatternEvidence {
  final String usageGraphNodeOrEdgeId;
  final int occurrenceCount;

  const PatternEvidence({
    required this.usageGraphNodeOrEdgeId,
    required this.occurrenceCount,
  });
}

/// RIL's own confidence type (distinct from `software_architect`'s
/// `Confidence`, since a pattern's confidence is derived purely from
/// observed occurrence counts, not from planning-time reasoning).
class PatternConfidence {
  final double score;
  final String reason;

  const PatternConfidence({required this.score, required this.reason});
}

class Pattern {
  final String id;
  final PatternKind kind;
  final String description;
  final List<PatternEvidence> evidence;
  final PatternConfidence confidence;

  const Pattern({
    required this.id,
    required this.kind,
    required this.description,
    required this.evidence,
    required this.confidence,
  });
}
