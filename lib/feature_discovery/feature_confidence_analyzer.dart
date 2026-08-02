/// Feature Confidence Analyzer — the real mean of every discovered
/// feature's own decision confidence, mirroring
/// software_architect/confidence_analyzer.dart and
/// application_engineering/engineering_confidence.dart's design.
library;

import '../software_architect/confidence.dart';
import 'feature_types.dart';

class FeatureConfidenceAnalyzer {
  const FeatureConfidenceAnalyzer();

  Confidence analyze(List<FeatureDecision> decisions) {
    if (decisions.isEmpty) {
      return const Confidence(score: 0.0, reason: 'No features were discovered.', risk: RiskLevel.high);
    }

    final meanScore = decisions.map((d) => d.confidence.score).reduce((a, b) => a + b) / decisions.length;
    final missing = decisions.expand((d) => d.confidence.missingKnowledge).toSet().toList();
    final worstRisk = decisions
        .map((d) => d.confidence.risk)
        .fold(RiskLevel.none, (worst, r) => r.index > worst.index ? r : worst);
    final lowCount = decisions.where((d) => d.confidence.isLow).length;

    return Confidence(
      score: meanScore,
      reason: 'Mean of ${decisions.length} discovered feature(s); $lowCount below 0.5.',
      missingKnowledge: missing,
      risk: worstRisk,
    );
  }
}
