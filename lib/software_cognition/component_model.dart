/// ComponentGraph / WidgetGraph — thin, named wrappers over a
/// component/widget-scoped SemanticSoftwareGraph, mirroring
/// RepositoryGraph/PackageGraph's pattern.
library;

import 'semantic_software_graph.dart';

class ComponentGraph {
  final SemanticSoftwareGraph graph;

  const ComponentGraph(this.graph);
}

class WidgetGraph {
  final SemanticSoftwareGraph graph;

  const WidgetGraph(this.graph);
}
