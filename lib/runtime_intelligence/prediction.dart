/// Prediction — Prediction. A structural forecast about what's likely to
/// happen next, derived from real UsageGraph frequencies — never a
/// domain-specific guess.
library;

import 'ril_types.dart';

/// RIL's own confidence type (distinct from `Confidence`, since a
/// prediction is derived purely from observed frequency, not
/// planning-time reasoning) — mirrors PatternConfidence's shape.
class PredictionConfidence {
  final double score;
  final String reason;

  const PredictionConfidence({required this.score, required this.reason});
}

class Prediction {
  final String id;
  final PredictionKind kind;
  final String description;
  final PredictionConfidence confidence;

  const Prediction({required this.id, required this.kind, required this.description, required this.confidence});
}
