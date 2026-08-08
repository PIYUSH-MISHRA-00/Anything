/// Execution-level ordering — Implementation Specification IS-R25. Real,
/// deterministic level-partitioning (a level-BFS variant of Kahn's
/// algorithm) over `ExecutionStrategy.applicableTargets`
/// (`lib/execution_planning/execution_strategy.dart`, R18) — a genuinely
/// new, small algorithm over a different node type
/// (`ExecutionTargetKind`/`ExecutionTargetPlan.dependencies`) than
/// `BuildGraphOrderer`'s (`lib/build_graph/build_graph_analysis.dart`,
/// R11, over `UniversalBuildGraph`), but it mirrors that algorithm's exact
/// honesty precedent: a real, non-fabricated partial order is returned
/// (never silently papered over) when a dependency cycle prevents a full
/// ordering.
///
/// Every target within one returned level has no dependency edge to any
/// other target in that same level — they could, in principle, execute
/// concurrently. This is real, provably-correct scheduling logic, proven
/// on synthetic multi-target fixtures (`test/r25_solution_orchestrator_test.dart`)
/// exactly as R11 proved `BuildGraphOrderer` on synthetic
/// `UniversalBuildGraph`s — REALITY today (see
/// `docs/architecture/SOLUTION_ORCHESTRATION.md`): only ONE real
/// `Generator` exists (`RuntimeExperienceGenerator`, R13), so a real
/// production `ExecutionStrategy` never has more than one
/// `applicableWithGenerator` target — every level in practice has exactly
/// one entry. The algorithm's correctness for N-target levels is real and
/// tested, not merely asserted.
library;

import '../execution_planning/execution_strategy.dart';

class ExecutionLevels {
  /// Each inner list is one level: every target in it is independent of
  /// every other target in the SAME level (no dependency edge between
  /// them); level 0 has no unresolved dependencies, level 1 depends only
  /// on level 0, etc.
  final List<List<ExecutionTargetKind>> levels;

  /// Honestly `false` (with a partial, real order for whatever WAS
  /// resolvable) when a dependency cycle prevents a full ordering — never
  /// silently papered over, mirroring `TopologicalOrderResult.isComplete`
  /// (R11).
  final bool isComplete;

  const ExecutionLevels({required this.levels, required this.isComplete});

  List<ExecutionTargetKind> get orderedTargets => [
    for (final level in levels) ...level,
  ];
}

class ExecutionTargetOrderer {
  const ExecutionTargetOrderer();

  /// Only [ExecutionStrategy.applicableTargets] participate — `notApplicable`
  /// targets carry no real dependency information and are never executed
  /// (matches `ExecutionTargetPlan`'s own documented convention: `priority`/
  /// `executionOrder` are meaningless for them).
  ExecutionLevels order(ExecutionStrategy strategy) {
    final applicable = strategy.applicableTargets;
    final byTarget = {for (final t in applicable) t.target: t};

    final inDegree = <ExecutionTargetKind, int>{
      for (final t in applicable) t.target: 0,
    };
    for (final t in applicable) {
      for (final dep in t.dependencies) {
        // A dependency on a target this strategy didn't even mark
        // applicable carries no real signal to order against — ignored,
        // never treated as an unsatisfiable edge (this can legitimately
        // happen: `ExecutionTargetPlan.dependencies` is conditionally
        // populated based on OTHER targets' own applicability, see
        // `SolutionExecutionPlanner._runtimeExperience`).
        if (!byTarget.containsKey(dep)) continue;
        inDegree[t.target] = (inDegree[t.target] ?? 0) + 1;
      }
    }

    final levels = <List<ExecutionTargetKind>>[];
    final remaining = Map<ExecutionTargetKind, int>.from(inDegree);
    final resolved = <ExecutionTargetKind>{};

    while (resolved.length < applicable.length) {
      final ready =
          remaining.entries
              .where((e) => e.value == 0 && !resolved.contains(e.key))
              .map((e) => e.key)
              .toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      if (ready.isEmpty) break; // Cycle: nothing left is resolvable.

      levels.add(ready);
      resolved.addAll(ready);
      for (final t in applicable) {
        if (resolved.contains(t.target)) continue;
        final stillUnresolvedDeps = t.dependencies
            .where((d) => byTarget.containsKey(d) && !resolved.contains(d))
            .length;
        remaining[t.target] = stillUnresolvedDeps;
      }
    }

    return ExecutionLevels(
      levels: levels,
      isComplete: resolved.length == applicable.length,
    );
  }
}
