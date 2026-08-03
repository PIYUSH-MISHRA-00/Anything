/// Build Graph Analysis — Implementation Milestone R11. Real cycle
/// detection (DFS with white/gray/black coloring — a genuinely new,
/// small algorithm; `GraphTraversal`'s bounded BFS, Vision Milestone V9,
/// answers a different question — "what's reachable within N hops" — and
/// silently stops at a revisit rather than reporting *that a cycle
/// exists*, so it is reused conceptually — bounded, deterministic,
/// never-revisit — but not literally, since it cannot itself distinguish
/// "already fully explored" from "currently mid-exploration," which is
/// exactly what cycle detection requires) and real topological build
/// ordering (Kahn's algorithm).
library;

import 'universal_build_graph.dart';

enum _VisitState { unvisited, visiting, done }

class CycleDetectionResult {
  final bool hasCycle;
  final List<String> cycleNodeIds;

  const CycleDetectionResult({required this.hasCycle, this.cycleNodeIds = const []});

  static const none = CycleDetectionResult(hasCycle: false);
}

class BuildGraphCycleDetector {
  const BuildGraphCycleDetector();

  /// Real DFS cycle detection: a "gray" node reached again before it's
  /// fully explored ("black") means a real back-edge — a genuine cycle,
  /// never a false positive from ordinary shared dependencies (a node
  /// reached twice via two DIFFERENT, non-overlapping paths is fine and
  /// common; only a path that loops back on itself is a cycle).
  CycleDetectionResult detect(UniversalBuildGraph graph) {
    final state = {for (final n in graph.nodes) n.id: _VisitState.unvisited};
    final path = <String>[];

    CycleDetectionResult? visit(String id) {
      state[id] = _VisitState.visiting;
      path.add(id);
      for (final edge in graph.outgoingFrom(id)) {
        final neighbor = edge.toId;
        final neighborState = state[neighbor];
        if (neighborState == _VisitState.visiting) {
          final cycleStart = path.indexOf(neighbor);
          return CycleDetectionResult(hasCycle: true, cycleNodeIds: path.sublist(cycleStart));
        }
        if (neighborState == _VisitState.unvisited) {
          final found = visit(neighbor);
          if (found != null) return found;
        }
      }
      path.removeLast();
      state[id] = _VisitState.done;
      return null;
    }

    for (final node in graph.nodes) {
      if (state[node.id] != _VisitState.unvisited) continue;
      final found = visit(node.id);
      if (found != null) return found;
    }
    return CycleDetectionResult.none;
  }
}

class TopologicalOrderResult {
  final List<String> orderedNodeIds;
  final bool isComplete;

  const TopologicalOrderResult({required this.orderedNodeIds, required this.isComplete});
}

class BuildGraphOrderer {
  const BuildGraphOrderer();

  /// Real Kahn's-algorithm topological order: dependencies before
  /// dependents. [isComplete] is honestly `false` (with a partial,
  /// real — never fabricated — order for whatever WAS resolvable) when a
  /// cycle prevents a full ordering, mirroring `GraphConsistency`'s own
  /// "report the real defect, never silently paper over it" philosophy.
  TopologicalOrderResult order(UniversalBuildGraph graph) {
    final inDegree = {for (final n in graph.nodes) n.id: 0};
    for (final edge in graph.edges) {
      // BuildGraphEdge(from: X, to: Y) means "X depends on Y" — Y must be
      // generated first, so the in-degree we decrement belongs to Y's
      // dependents count from X's perspective: X can only be ordered once
      // every dependency (edge.toId) it points to is already ordered.
      inDegree[edge.fromId] = (inDegree[edge.fromId] ?? 0) + 1;
    }

    final ready = [for (final n in graph.nodes) if (inDegree[n.id] == 0) n.id]..sort();
    final ordered = <String>[];
    final remainingInDegree = Map<String, int>.from(inDegree);

    while (ready.isNotEmpty) {
      final id = ready.removeAt(0);
      ordered.add(id);
      final dependents = graph.edges.where((e) => e.toId == id).map((e) => e.fromId).toSet().toList()..sort();
      for (final dependent in dependents) {
        remainingInDegree[dependent] = (remainingInDegree[dependent] ?? 1) - 1;
        if (remainingInDegree[dependent] == 0) ready.add(dependent);
      }
      ready.sort();
    }

    return TopologicalOrderResult(orderedNodeIds: ordered, isComplete: ordered.length == graph.nodes.length);
  }
}
