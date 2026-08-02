/// Tradeoff Engine — every solution must explain its advantages and
/// disadvantages across a fixed, typed set of dimensions. Never arbitrary:
/// every SolutionTradeoff instance carries a concrete rationale tracing to
/// a real property of the candidate that produced it.
library;

enum TradeoffDimension {
  complexity,
  maintainability,
  battery,
  performance,
  memory,
  storage,
  network,
  offline,
  modificationCost,
  testingCost,
  security,
  privacy,
  scalability,
  accessibility,
  futureEvolution,
}

enum TradeoffDirection { advantage, disadvantage, neutral }

class SolutionTradeoff {
  final TradeoffDimension dimension;
  final TradeoffDirection direction;
  final String description;
  final String rationale;

  const SolutionTradeoff({
    required this.dimension,
    required this.direction,
    required this.description,
    required this.rationale,
  });
}
