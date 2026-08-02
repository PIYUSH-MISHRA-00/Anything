/// Confidence — the typed result every planner attaches to its decisions.
///
/// Deterministic and explainable: a confidence score is always paired with
/// the concrete reason, missing knowledge, and risk that produced it, so
/// "low confidence" is never an unexplained number.
library;

enum RiskLevel { none, low, medium, high }

class Confidence {
  /// 0.0 (no confidence) to 1.0 (fully confident).
  final double score;
  final String reason;
  final List<String> missingKnowledge;
  final RiskLevel risk;
  final List<String> alternatives;

  const Confidence({
    required this.score,
    required this.reason,
    this.missingKnowledge = const [],
    this.risk = RiskLevel.none,
    this.alternatives = const [],
  });

  bool get isLow => score < 0.5;

  static const Confidence full = Confidence(
    score: 1.0,
    reason: 'Directly and unambiguously derived from explicit input.',
  );
}

/// A category of architectural decision — mirrors the planning stages.
enum ArchitectureDecisionCategory {
  data,
  entity,
  field,
  relationship,
  state,
  navigation,
  interaction,
  capability,
  permission,
  security,
  offline,
  synchronization,
  storage,
  validation,
}

/// One concrete, justified architectural decision.
///
/// This is the atomic unit every planner produces — a typed record of
/// *what* was decided and *why*, never a bare value with no rationale.
class ArchitectureDecision {
  final String id;
  final ArchitectureDecisionCategory category;
  final String subjectId;
  final String decision;
  final String rationale;
  final Confidence confidence;
  final List<String> alternatives;
  final String? securityImplication;
  final String? offlineImplication;

  const ArchitectureDecision({
    required this.id,
    required this.category,
    required this.subjectId,
    required this.decision,
    required this.rationale,
    required this.confidence,
    this.alternatives = const [],
    this.securityImplication,
    this.offlineImplication,
  });
}
