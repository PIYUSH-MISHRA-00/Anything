/// Feature Classifier — de-duplicates FeatureCandidates that structurally
/// resolve to the same feature (identical id), merging their source node
/// ids rather than silently dropping evidence.
library;

import 'feature_types.dart';

class FeatureClassifier {
  const FeatureClassifier();

  List<FeatureCandidate> classify(List<FeatureCandidate> candidates) {
    final byId = <String, FeatureCandidate>{};
    for (final candidate in candidates) {
      final existing = byId[candidate.id];
      if (existing == null) {
        byId[candidate.id] = candidate;
        continue;
      }
      final mergedSources = {...existing.sourceNodeIds, ...candidate.sourceNodeIds}.toList();
      byId[candidate.id] = FeatureCandidate(
        id: existing.id,
        name: existing.name,
        category: existing.category,
        sourceNodeIds: mergedSources,
        rationale: existing.rationale,
      );
    }
    return byId.values.toList();
  }
}
