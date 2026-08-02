/// An EvolutionOpportunity — a real, structurally-detected gap between
/// what the current design does and what it could do next. Never a
/// template: every opportunity's [EvolutionEvidence] traces to a real
/// FeatureGraph node, architecture posture decision, or non-critical
/// Design Review finding.
library;

import 'evolution_types.dart';

class EvolutionOpportunity {
  final String id;
  final EvolutionOpportunityCategory category;
  final String description;
  final EvolutionReason reason;

  const EvolutionOpportunity({
    required this.id,
    required this.category,
    required this.description,
    required this.reason,
  });
}
