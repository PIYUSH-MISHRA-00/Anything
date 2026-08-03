/// API Specification — Implementation Milestone R8. A real, typed,
/// deterministic representation of the REST-shaped endpoints a backend
/// for this application would expose — derived from
/// `InteractionDecision`'s already-real canCreate/canRead/canUpdate/
/// canDelete/supportsSearch flags (ArchitectureCandidate, Vision
/// Milestone V2) and each entity's real field shape. Never generates a
/// server-framework template, never executes, never listens on a real
/// port — a specification only.
library;

enum ApiOperation { list, get, create, update, delete, search }

enum HttpMethod { get, post, put, delete }

class ApiRequestField {
  final String name;
  final bool required;

  const ApiRequestField({required this.name, this.required = false});
}

class ApiEndpoint {
  final String id;
  final String path;
  final HttpMethod method;
  final ApiOperation operation;
  final String entityId;
  final List<ApiRequestField> requestFields;

  const ApiEndpoint({
    required this.id,
    required this.path,
    required this.method,
    required this.operation,
    required this.entityId,
    this.requestFields = const [],
  });
}

class ApiSpecificationModel {
  final List<ApiEndpoint> endpoints;

  const ApiSpecificationModel({this.endpoints = const []});

  static const empty = ApiSpecificationModel();

  bool get isEmpty => endpoints.isEmpty;

  List<ApiEndpoint> endpointsForEntity(String entityId) => endpoints.where((e) => e.entityId == entityId).toList();
}
