/// ExperienceRelationshipGraph — Multi Experience support. Confirmed by
/// repository audit: no Experience persists a link to another Experience
/// today (no foreign key, no tags field). This graph is therefore
/// honestly INFERRED, never a live/persisted relationship: it compares
/// independently-persisted, purely structural fingerprints (shared
/// capability ids, shared field-TYPE shapes — never field values or
/// record data) across Experiences and surfaces a real, explained
/// relationship only when a genuine structural overlap exists. Never by
/// keyword, never hardcoded.
library;

import 'ril_types.dart';

/// A purely structural summary of one Experience — no data, no content,
/// only shape.
class ExperienceFingerprint {
  final String experienceId;
  final String name;
  final List<String> capabilityIds;
  final List<String> entityFieldTypeNames;

  const ExperienceFingerprint({
    required this.experienceId,
    required this.name,
    this.capabilityIds = const [],
    this.entityFieldTypeNames = const [],
  });
}

class ExperienceRelationshipEdge {
  final String fromId;
  final String toId;
  final ExperienceRelationshipKind kind;
  final String rationale;

  const ExperienceRelationshipEdge({required this.fromId, required this.toId, required this.kind, required this.rationale});
}

class ExperienceRelationshipGraph {
  final List<RilNode> nodes;
  final List<ExperienceRelationshipEdge> edges;

  const ExperienceRelationshipGraph({this.nodes = const [], this.edges = const []});

  List<ExperienceRelationshipEdge> edgesFrom(String experienceId) => edges.where((e) => e.fromId == experienceId).toList();

  /// Infers relationships purely from structural overlap between
  /// fingerprints — never a hardcoded pair, never a keyword match.
  factory ExperienceRelationshipGraph.infer(List<ExperienceFingerprint> fingerprints) {
    final nodes = fingerprints
        .map((f) => RilNode(id: f.experienceId, kind: RilNodeKind.experience, label: f.name))
        .toList();

    final edges = <ExperienceRelationshipEdge>[];
    for (var i = 0; i < fingerprints.length; i++) {
      for (var j = i + 1; j < fingerprints.length; j++) {
        final a = fingerprints[i];
        final b = fingerprints[j];

        final sharedCapabilities = a.capabilityIds.toSet().intersection(b.capabilityIds.toSet());
        if (sharedCapabilities.isNotEmpty) {
          edges.add(
            ExperienceRelationshipEdge(
              fromId: a.experienceId,
              toId: b.experienceId,
              kind: ExperienceRelationshipKind.sharesCapability,
              rationale: 'Both use: ${sharedCapabilities.join(', ')}',
            ),
          );
        }

        final sharedFieldTypes = a.entityFieldTypeNames.toSet().intersection(b.entityFieldTypeNames.toSet());
        if (sharedFieldTypes.length >= 2) {
          edges.add(
            ExperienceRelationshipEdge(
              fromId: a.experienceId,
              toId: b.experienceId,
              kind: ExperienceRelationshipKind.sharesDataShape,
              rationale: 'Both have entities with field types: ${sharedFieldTypes.join(', ')}',
            ),
          );
        }
      }
    }

    return ExperienceRelationshipGraph(nodes: nodes, edges: edges);
  }
}
