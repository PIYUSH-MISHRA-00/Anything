/// Engineering Confidence — the real, computed mean of every decision an
/// EngineeringCandidate is built from, mirroring
/// software_architect/confidence_analyzer.dart's design.
library;

import '../software_architect/confidence.dart';
import 'engineering_candidate.dart';

class EngineeringConfidence {
  const EngineeringConfidence();

  Confidence analyze(EngineeringCandidate candidate) {
    final decisions = candidate.allDecisions;
    if (decisions.isEmpty) {
      return const Confidence(score: 0.0, reason: 'No decisions were planned.', risk: RiskLevel.high);
    }

    final meanScore = decisions.map((d) => d.confidence.score).reduce((a, b) => a + b) / decisions.length;
    final missing = decisions.expand((d) => d.confidence.missingKnowledge).toSet().toList();
    final worstRisk = decisions
        .map((d) => d.confidence.risk)
        .fold(RiskLevel.none, (worst, r) => r.index > worst.index ? r : worst);
    final lowCount = decisions.where((d) => d.confidence.isLow).length;

    return Confidence(
      score: meanScore,
      reason: 'Mean of ${decisions.length} engineering decision(s); $lowCount below 0.5.',
      missingKnowledge: missing,
      risk: worstRisk,
    );
  }
}
