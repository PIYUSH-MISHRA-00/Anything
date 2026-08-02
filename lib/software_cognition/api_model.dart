/// APIGraph / EndpointGraph / SchemaGraph — thin, named wrappers over an
/// API-scoped SemanticSoftwareGraph, mirroring RepositoryGraph/
/// PackageGraph's pattern.
library;

import 'semantic_software_graph.dart';

class EndpointGraph {
  final SemanticSoftwareGraph graph;

  const EndpointGraph(this.graph);
}

class SchemaGraph {
  final SemanticSoftwareGraph graph;

  const SchemaGraph(this.graph);
}

class APIGraph {
  final EndpointGraph endpoints;
  final SchemaGraph schemas;

  const APIGraph({required this.endpoints, required this.schemas});

  SemanticSoftwareGraph get combined => endpoints.graph.concat(schemas.graph);
}
