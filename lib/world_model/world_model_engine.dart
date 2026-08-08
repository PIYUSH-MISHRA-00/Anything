/// WorldModelEngine — the top-level World Model orchestrator: Plan
/// (review + merge) -> Commit -> Version -> Record, mirroring
/// DesignReviewEngine (V6) / EvolutionEngine (V7) / RuntimeIntelligence
/// Engine (V8)'s role as the single facade over everything else in this
/// package. Deterministic: applying the same GraphUpdate to the same
/// base graph always produces the same resulting graph.
library;

import 'context_analyzer.dart';
import 'graph_update.dart';
import 'world_graph.dart';
import 'world_history.dart';
import 'world_memory.dart';
import 'world_model.dart';
import 'world_planner.dart';
import 'world_snapshot.dart';

class WorldModelEngine {
  final WorldPlanner _planner;

  const WorldModelEngine({WorldPlanner planner = const WorldPlanner()})
    : _planner = planner;

  /// Plans and, only if approved (clean merge + consistent graph),
  /// commits [update] onto [current]. Returns the new WorldModel and
  /// records a new versioned WorldSnapshot into [history]/[memory]. If
  /// not approved, the graph is left unchanged — never partially
  /// applied.
  WorldModel apply(
    WorldModel current,
    GraphUpdate update, {
    WorldHistory? history,
    WorldMemory? memory,
    WorldContext? context,
  }) {
    final planResult = _planner.plan(current.graph, update);
    if (!planResult.approved) {
      return current;
    }

    final newVersion = WorldVersion(
      number: current.version.number + 1,
      createdAt: DateTime.now(),
    );
    final newModel = WorldModel(
      graph: planResult.graph,
      context: context ?? current.context,
      version: newVersion,
    );

    final snapshot = WorldSnapshot(version: newVersion, graph: newModel.graph);
    history?.record(snapshot);
    memory?.record(snapshot);

    return newModel;
  }

  WorldModel empty() => WorldModel(
    graph: const WorldGraph(),
    version: WorldVersion(number: 0, createdAt: DateTime.now()),
  );
}
