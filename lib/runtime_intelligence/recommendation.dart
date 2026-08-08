/// Recommendation — a real, structural suggestion RecommendationEngine
/// derived from a learned Pattern. Never automatic: a Recommendation is
/// always reviewed (RecommendationReview) before it can ever become an
/// AutomationPlan.
library;

import '../software_architect/confidence.dart';
import 'ril_types.dart';

class RecommendationEvidence {
  final String patternId;
  final String usageGraphNodeOrEdgeId;

  const RecommendationEvidence({
    required this.patternId,
    required this.usageGraphNodeOrEdgeId,
  });
}

class RecommendationReason {
  final String summary;
  final RecommendationEvidence evidence;
  final Confidence confidence;

  const RecommendationReason({
    required this.summary,
    required this.evidence,
    required this.confidence,
  });
}

class Recommendation {
  final String id;
  final RecommendationKind kind;
  final String description;
  final RecommendationReason reason;

  const Recommendation({
    required this.id,
    required this.kind,
    required this.description,
    required this.reason,
  });
}
