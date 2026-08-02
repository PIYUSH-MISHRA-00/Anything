/// Feature Recommendation — a human-facing formatting of one FeatureNode +
/// its FeatureExplanation, the substrate for a future "Why did you create
/// this?" surface. Pure formatting, no new analysis.
library;

import 'feature_types.dart';

class FeatureRecommendation {
  final String featureName;
  final FeaturePriority priority;
  final String explanationText;

  const FeatureRecommendation({
    required this.featureName,
    required this.priority,
    required this.explanationText,
  });

  factory FeatureRecommendation.forNode(FeatureNode node) {
    final explanation = node.explanation;
    final parts = <String>[explanation.whyDiscovered];
    if (explanation.whyRequired != null) parts.add(explanation.whyRequired!);
    if (explanation.whyOptional != null) parts.add(explanation.whyOptional!);
    if (explanation.whyDependent != null) parts.add(explanation.whyDependent!);
    return FeatureRecommendation(
      featureName: node.name,
      priority: node.priority,
      explanationText: parts.join(' '),
    );
  }
}
