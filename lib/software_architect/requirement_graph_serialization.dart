/// RequirementGraph (de)serialization — Implementation Milestone R5.
///
/// Reuses the same convention `ExperiencePackage` already established
/// (hand-written `toJson()`/`fromJson()`, `jsonEncode`/`jsonDecode` at the
/// storage boundary) rather than introducing a codegen/reflection-based
/// serialization mechanism this codebase has never used. Full fidelity —
/// `RequirementGraph`'s type tree is shallow enough that no summary
/// tradeoff is needed (see `engineering_memory_summary.dart` for the
/// deliberately-different call made for `EngineeringPlan`, which is not).
library;

import 'requirement_graph.dart';

extension RequirementGraphJson on RequirementGraph {
  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'relations': relations.map((r) => r.toJson()).toList(),
    'nonFunctional': nonFunctional.map((n) => n.toJson()).toList(),
  };

  static RequirementGraph fromJson(
    Map<String, dynamic> json,
  ) => RequirementGraph(
    nodes: (json['nodes'] as List)
        .map((n) => RequirementNodeJson.fromJson(n as Map<String, dynamic>))
        .toList(),
    relations: (json['relations'] as List)
        .map((r) => RequirementRelationJson.fromJson(r as Map<String, dynamic>))
        .toList(),
    nonFunctional: (json['nonFunctional'] as List)
        .map(
          (n) =>
              NonFunctionalRequirementJson.fromJson(n as Map<String, dynamic>),
        )
        .toList(),
  );
}

extension RequirementNodeJson on RequirementNode {
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'label': label,
    'description': description,
    'source': source.name,
  };

  static RequirementNode fromJson(Map<String, dynamic> json) => RequirementNode(
    id: json['id'] as String,
    type: RequirementNodeType.values.byName(json['type'] as String),
    label: json['label'] as String,
    description: json['description'] as String? ?? '',
    source: RequirementSource.values.byName(
      json['source'] as String? ?? 'inferred',
    ),
  );
}

extension RequirementRelationJson on RequirementRelation {
  Map<String, dynamic> toJson() => {
    'fromId': fromId,
    'toId': toId,
    'type': type.name,
  };

  static RequirementRelation fromJson(Map<String, dynamic> json) =>
      RequirementRelation(
        fromId: json['fromId'] as String,
        toId: json['toId'] as String,
        type: RequirementRelationType.values.byName(json['type'] as String),
      );
}

extension NonFunctionalRequirementJson on NonFunctionalRequirement {
  Map<String, dynamic> toJson() => {
    'category': category.name,
    'description': description,
    'source': source.name,
  };

  static NonFunctionalRequirement fromJson(Map<String, dynamic> json) =>
      NonFunctionalRequirement(
        category: NonFunctionalCategory.values.byName(
          json['category'] as String,
        ),
        description: json['description'] as String,
        source: RequirementSource.values.byName(
          json['source'] as String? ?? 'inferred',
        ),
      );
}
