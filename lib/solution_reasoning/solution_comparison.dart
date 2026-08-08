/// Solution Comparison — builds the typed SolutionGraph of pairwise
/// relations (dominates/equivalentTo/alternativeTo) between every refined
/// candidate, the structural basis SolutionSelector picks from.
library;

import 'solution_types.dart';

class SolutionComparisonResult {
  final SolutionGraph graph;

  const SolutionComparisonResult({required this.graph});
}

class SolutionComparison {
  const SolutionComparison();

  static const double _epsilon = 0.01;

  SolutionComparisonResult compare(List<SolutionCandidate> candidates) {
    final scored = candidates.where((c) => c.score != null).toList();

    final nodes = scored
        .map(
          (c) => SolutionNode(
            candidateId: c.id,
            label: c.label,
            overallScore: c.score!.overall.score,
          ),
        )
        .toList();

    final edges = <SolutionEdge>[];
    for (final a in scored) {
      for (final b in scored) {
        if (a.id == b.id) continue;
        final aScore = a.score!.overall.score;
        final bScore = b.score!.overall.score;
        final aComplexity = solutionComplexityRank(a.complexity);
        final bComplexity = solutionComplexityRank(b.complexity);

        final aAtLeastAsGood =
            aScore >= bScore - _epsilon && aComplexity <= bComplexity;
        final aStrictlyBetter =
            aScore > bScore + _epsilon || aComplexity < bComplexity;

        if (aAtLeastAsGood && aStrictlyBetter) {
          edges.add(
            SolutionEdge(
              fromCandidateId: a.id,
              toCandidateId: b.id,
              kind: SolutionRelationKind.dominates,
              rationale:
                  '"${a.label}" scores at least as well (${aScore.toStringAsFixed(2)} vs '
                  '${bScore.toStringAsFixed(2)}) at no greater complexity ($aComplexity vs $bComplexity).',
            ),
          );
        } else if ((aScore - bScore).abs() < _epsilon &&
            aComplexity == bComplexity &&
            a.id.compareTo(b.id) < 0) {
          edges.add(
            SolutionEdge(
              fromCandidateId: a.id,
              toCandidateId: b.id,
              kind: SolutionRelationKind.equivalentTo,
              rationale:
                  'Both score ${aScore.toStringAsFixed(2)} at the same complexity rank ($aComplexity).',
            ),
          );
        } else if (a.id.compareTo(b.id) < 0) {
          edges.add(
            SolutionEdge(
              fromCandidateId: a.id,
              toCandidateId: b.id,
              kind: SolutionRelationKind.alternativeTo,
              rationale:
                  'Neither dominates the other — a genuine tradeoff between them.',
            ),
          );
        }
      }
    }

    return SolutionComparisonResult(
      graph: SolutionGraph(nodes: nodes, edges: edges),
    );
  }
}
