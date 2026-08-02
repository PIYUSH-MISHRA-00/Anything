/// Confidence Analyzer — aggregates every individual planner decision's
/// Confidence into one real, explainable overall score for a candidate.
/// Never a fixed/fabricated number: always the actual mean of what was
/// planned, plus the union of missing-knowledge/risk signals.
library;

import 'architecture_candidate.dart';
import 'confidence.dart';

class ConfidenceAnalyzer {
  const ConfidenceAnalyzer();

  Confidence analyze(ArchitectureCandidate candidate) {
    final decisions = candidate.allDecisions;
    if (decisions.isEmpty) {
      return const Confidence(
        score: 0.0,
        reason: 'No decisions were planned.',
        risk: RiskLevel.high,
      );
    }

    final meanScore =
        decisions.map((d) => d.confidence.score).reduce((a, b) => a + b) /
        decisions.length;

    final missing = decisions
        .expand((d) => d.confidence.missingKnowledge)
        .toSet()
        .toList();

    final worstRisk = decisions
        .map((d) => d.confidence.risk)
        .fold(RiskLevel.none, (worst, r) => r.index > worst.index ? r : worst);

    final lowConfidenceCount = decisions
        .where((d) => d.confidence.isLow)
        .length;

    return Confidence(
      score: meanScore,
      reason:
          'Mean of ${decisions.length} planning decision(s); '
          '$lowConfidenceCount below 0.5.',
      missingKnowledge: missing,
      risk: worstRisk,
    );
  }
}
