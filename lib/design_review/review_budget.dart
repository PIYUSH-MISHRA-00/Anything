/// Review Budget — the bounded, typed resource limit ReviewRefinement's
/// loop runs under. Mirrors RuntimeSecurityLimits' philosophy (a trusted,
/// named constant rather than a bare literal scattered through the code).
library;

class ReviewBudget {
  final int maxIterations;
  final int maxIssuesPerIteration;

  const ReviewBudget({this.maxIterations = 3, this.maxIssuesPerIteration = 200});
}
