/// Feature Confidence Analyzer — the real mean of every discovered
/// feature's own decision confidence, mirroring
/// software_architect/confidence_analyzer.dart and
/// application_engineering/engineering_confidence.dart's design.
///
/// Implementation Milestone R3: optionally blends in two real, structural
/// (never textual/keyword) enrichment signals — acquired-knowledge trust
/// (from the SAME `KnowledgeGraph` Knowledge/Software Cognition already
/// produce, per R1/R2) and prior-capability familiarity (from the World
/// Graph's already-real `capability` nodes, per R1's Experience ingestion).
/// Both are optional and additive: omitted, this method's output is
/// byte-for-byte identical to pre-R3.
library;

import '../software_architect/confidence.dart';
import '../software_architect/knowledge_graph.dart';
import 'feature_types.dart';

class FeatureConfidenceAnalyzer {
  const FeatureConfidenceAnalyzer();

  /// [knowledge] — when a real, non-empty `KnowledgeGraph` was acquired
  /// (Knowledge and/or Software Cognition both flow through this same
  /// type, per R1's `seedKnowledge`/R2's `KnowledgeGraphBuilder`), its
  /// nodes' mean `trust.confidence` is a genuine, structural signal —
  /// this domain's design isn't merely guessed, it's grounded in real,
  /// externally-acquired, trust-scored evidence.
  ///
  /// [priorCapabilityIds] — capability ids already observed as real
  /// `WorldNodeKind.capability` nodes in the World Graph (from this
  /// user's own prior Experiences/Evolution roadmaps/Software Cognition,
  /// per R1's Experience ingestion) — a capability this pipeline is about
  /// to require, that the user has already used before, is genuine,
  /// structural corroborating evidence, never a fabricated boost.
  Confidence analyze(
    List<FeatureDecision> decisions, {
    KnowledgeGraph? knowledge,
    Set<String> priorCapabilityIds = const {},
  }) {
    if (decisions.isEmpty) {
      return const Confidence(
        score: 0.0,
        reason: 'No features were discovered.',
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
    final lowCount = decisions.where((d) => d.confidence.isLow).length;

    final reasonParts = <String>[
      'Mean of ${decisions.length} discovered feature(s); $lowCount below 0.5.',
    ];

    // Real, structural, bounded blend — never overrides the base score,
    // only nudges it by a small, explainable amount capped at ±0.1 total,
    // so a single evidence source can never dominate the real per-feature
    // analysis above.
    var adjustedScore = meanScore;

    if (knowledge != null && !knowledge.isEmpty && knowledge.nodes.isNotEmpty) {
      final meanTrust =
          knowledge.nodes
              .map((n) => n.trust.confidence)
              .reduce((a, b) => a + b) /
          knowledge.nodes.length;
      // Centered on 0.5 trust (neutral) — genuinely high-trust knowledge
      // nudges up, genuinely low-trust knowledge nudges down, never a
      // one-directional "knowledge exists therefore confident" fallacy.
      final knowledgeAdjustment = (meanTrust - 0.5) * 0.1;
      adjustedScore += knowledgeAdjustment;
      reasonParts.add(
        'Grounded in ${knowledge.nodes.length} acquired knowledge resource(s) '
        '(mean trust ${meanTrust.toStringAsFixed(2)}).',
      );
    }

    if (priorCapabilityIds.isNotEmpty) {
      reasonParts.add(
        '${priorCapabilityIds.length} capability(ies) already familiar from prior Experiences.',
      );
      adjustedScore += 0.05;
    }

    return Confidence(
      score: adjustedScore.clamp(0.0, 1.0),
      reason: reasonParts.join(' '),
      missingKnowledge: missing,
      risk: worstRisk,
    );
  }
}
