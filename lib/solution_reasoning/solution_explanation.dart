/// Solution Explanation — the substrate for a future "why did you choose
/// this architecture?" surface, mirroring FeatureExplanation's (V4) shape.
library;

class SolutionExplanation {
  final String solutionId;
  final String whyGenerated;
  final String? whySelected;
  final String? whyRejected;
  final List<String> keyTradeoffs;

  const SolutionExplanation({
    required this.solutionId,
    required this.whyGenerated,
    this.whySelected,
    this.whyRejected,
    this.keyTradeoffs = const [],
  });
}
