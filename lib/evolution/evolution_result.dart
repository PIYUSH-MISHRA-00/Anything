/// EvolutionResult — one full evolution pass: the iteration(s) run,
/// the final roadmap, the prediction, and the graph. Mirrors
/// ReviewResult/ReviewIteration (V6)'s proven shape.
library;

import 'evolution_candidate.dart';
import 'evolution_graph.dart';
import 'evolution_opportunity.dart';
import 'evolution_prediction.dart';
import 'evolution_roadmap.dart';
import 'evolution_types.dart';

class EvolutionIteration {
  final int index;
  final List<EvolutionOpportunity> opportunities;
  final List<EvolutionCandidate> candidates;
  final List<EvolutionDecision> decisions;

  const EvolutionIteration({
    required this.index,
    this.opportunities = const [],
    this.candidates = const [],
    this.decisions = const [],
  });

  List<EvolutionCandidate> get acceptedCandidates {
    final acceptedIds = decisions.where((d) => d.kind == EvolutionDecisionKind.accepted).map((d) => d.subjectId).toSet();
    return candidates.where((c) => acceptedIds.contains(c.id)).toList();
  }
}

enum EvolutionOutcome { planned, noOpportunities, budgetExhausted }

class EvolutionCycle {
  final List<EvolutionIteration> iterations;
  final EvolutionOutcome outcome;

  const EvolutionCycle({required this.iterations, required this.outcome});

  EvolutionIteration get finalIteration => iterations.last;
}

class EvolutionResult {
  final EvolutionCycle cycle;
  final EvolutionRoadmap roadmap;
  final EvolutionPrediction prediction;
  final EvolutionGraph graph;

  const EvolutionResult({required this.cycle, required this.roadmap, required this.prediction, required this.graph});
}
