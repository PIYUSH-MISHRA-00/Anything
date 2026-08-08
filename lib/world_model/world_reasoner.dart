/// WorldReasoner — the single facade over Impact/Dependency/Context
/// analysis and semantic query, answering the literal questions this
/// milestone's User Experience section names ("What depends on this?",
/// "Which Experiences use this?", "Show everything related to X") —
/// entirely via real graph reasoning, never a template response.
library;

import 'context_analyzer.dart';
import 'dependency_analyzer.dart';
import 'entity_identity.dart';
import 'graph_view.dart';
import 'impact_analyzer.dart';
import 'semantic_query_engine.dart';
import 'world_graph.dart';
import 'world_node.dart';

class WorldReasoner {
  final ImpactAnalyzer _impact;
  final DependencyAnalyzer _dependency;
  final ContextAnalyzer _context;
  final SemanticQueryEngine _query;

  const WorldReasoner({
    ImpactAnalyzer impact = const ImpactAnalyzer(),
    DependencyAnalyzer dependency = const DependencyAnalyzer(),
    ContextAnalyzer context = const ContextAnalyzer(),
    SemanticQueryEngine query = const SemanticQueryEngine(),
  }) : _impact = impact,
       _dependency = dependency,
       _context = context,
       _query = query;

  ImpactReport whatDependsOn(WorldGraph graph, EntityIdentity subject) =>
      _impact.analyze(graph, subject);

  DependencyReport whatDoesThisDependOn(
    WorldGraph graph,
    EntityIdentity subject,
  ) => _dependency.analyze(graph, subject);

  GraphView? showEverythingRelatedTo(WorldGraph graph, WorldContext context) =>
      _context.relevantView(graph, context);

  List<WorldNode> answer(
    WorldGraph graph,
    String expression,
    EntityIdentity startId,
  ) {
    final query = _query.parseIntent(expression, startId);
    if (query == null) return const [];
    return _query.query(graph, query);
  }
}
