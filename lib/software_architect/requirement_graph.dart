/// Requirement Graph — a typed, semantic graph of what an application must
/// do, derived structurally from reasoning output (SemanticApp) and intent
/// understanding. No Maps, no dynamic, no JSON blobs: every node and edge
/// is a real, typed value.
library;

/// The kind of thing a requirement node describes.
enum RequirementNodeType {
  entity,
  field,
  relationship,
  view,
  action,
  capability,
  constraint,
  permission,
  storage,
  navigation,
  state,
  validation,
}

/// Where a requirement came from — load-bearing for ConfidenceAnalyzer:
/// an explicit requirement is more trustworthy than a defaulted one.
enum RequirementSource { explicit, inferred, defaulted }

/// One node in the requirement graph.
class RequirementNode {
  final String id;
  final RequirementNodeType type;
  final String label;
  final String description;
  final RequirementSource source;

  const RequirementNode({
    required this.id,
    required this.type,
    required this.label,
    this.description = '',
    this.source = RequirementSource.inferred,
  });
}

/// The kind of relationship between two requirement nodes.
enum RequirementRelationType {
  dependsOn,
  constrains,
  implements,
  references,
  belongsTo,
}

/// A directed edge between two requirement nodes.
class RequirementRelation {
  final String fromId;
  final String toId;
  final RequirementRelationType type;

  const RequirementRelation({
    required this.fromId,
    required this.toId,
    required this.type,
  });
}

/// A category of non-functional requirement (cross-cutting, not tied to a
/// single entity/field node).
enum NonFunctionalCategory {
  offline,
  security,
  performance,
  futureModification,
  lifecycle,
}

/// A non-functional requirement — "the app must work offline", "changes
/// must be modifiable later" — derived from intent understanding rather
/// than the entity/field structure.
class NonFunctionalRequirement {
  final NonFunctionalCategory category;
  final String description;
  final RequirementSource source;

  const NonFunctionalRequirement({
    required this.category,
    required this.description,
    this.source = RequirementSource.inferred,
  });
}

/// The complete, typed requirement graph for one application intent.
///
/// Structural by construction: nothing here knows what a "plant" or an
/// "invoice" is — it only knows entities/fields/relationships/views/
/// actions/capabilities/constraints, however they're named.
class RequirementGraph {
  final List<RequirementNode> nodes;
  final List<RequirementRelation> relations;
  final List<NonFunctionalRequirement> nonFunctional;

  const RequirementGraph({
    this.nodes = const [],
    this.relations = const [],
    this.nonFunctional = const [],
  });

  List<RequirementNode> nodesOfType(RequirementNodeType type) =>
      nodes.where((n) => n.type == type).toList();

  RequirementNode? nodeById(String id) =>
      nodes.where((n) => n.id == id).firstOrNull;

  List<RequirementRelation> relationsFrom(String nodeId) =>
      relations.where((r) => r.fromId == nodeId).toList();

  List<RequirementRelation> relationsTo(String nodeId) =>
      relations.where((r) => r.toId == nodeId).toList();

  /// A relation is dangling if either endpoint doesn't exist as a node —
  /// SelfCritic treats this as a real structural defect.
  List<RequirementRelation> get danglingRelations => relations
      .where((r) => nodeById(r.fromId) == null || nodeById(r.toId) == null)
      .toList();
}
