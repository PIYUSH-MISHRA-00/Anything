/// Requirement Graph Diff — Implementation Milestone R3's "Incremental
/// Engineering" pipeline, planning-only (per the milestone's own explicit
/// scope: "Runtime patching belongs to R5" — this file computes what
/// changed, never applies it to a running Experience).
///
/// Mirrors `GraphMerge`/`GraphConflict`'s already-established structural-
/// comparison shape (Vision Milestone V9) rather than inventing a new
/// diffing paradigm — nodes are compared by [RequirementNode.id]
/// (identity), relations by their full `(fromId, toId, type)` triple
/// (there is no separate relation identity in this graph, matching
/// `RequirementGraph`'s own existing shape).
///
/// Scope, stated honestly: this is the Requirement Graph's diff. A real,
/// scoped extension of the exact same pattern to Architecture/Engineering/
/// Experience Diff is a natural next step (see R3's Known Limitations),
/// deferred rather than built half-finished under this milestone's time
/// budget — Rule 6, "no TODO architecture," means shipping one complete,
/// tested diff type is preferable to four incomplete ones.
library;

import 'requirement_graph.dart';

/// One node that changed between two `RequirementGraph`s. A "changed"
/// node (same id, different label/description/source) is a delete+add
/// pair (removed old-shape, added new-shape) — deliberately never a third
/// "modified" bucket, since that would require an update-in-place
/// semantics `RequirementNode`'s existing immutable design doesn't have,
/// and this stays consistent with `GraphMerge`'s own "identity match with
/// differing content is surfaced explicitly, never silently merged"
/// philosophy.
class RequirementGraphDiff {
  final List<RequirementNode> addedNodes;
  final List<RequirementNode> removedNodes;
  final List<RequirementRelation> addedRelations;
  final List<RequirementRelation> removedRelations;

  const RequirementGraphDiff({
    this.addedNodes = const [],
    this.removedNodes = const [],
    this.addedRelations = const [],
    this.removedRelations = const [],
  });

  bool get isEmpty =>
      addedNodes.isEmpty && removedNodes.isEmpty && addedRelations.isEmpty && removedRelations.isEmpty;

  static const RequirementGraphDiff empty = RequirementGraphDiff();
}

class RequirementGraphDiffer {
  const RequirementGraphDiffer();

  /// Real, deterministic structural diff — same two graphs in, same diff
  /// out, every time (Rule 7: nothing here reduces determinism).
  RequirementGraphDiff diff(RequirementGraph before, RequirementGraph after) {
    final beforeNodesById = {for (final n in before.nodes) n.id: n};
    final afterNodesById = {for (final n in after.nodes) n.id: n};

    final addedNodes = <RequirementNode>[];
    final removedNodes = <RequirementNode>[];

    for (final entry in afterNodesById.entries) {
      final beforeNode = beforeNodesById[entry.key];
      if (beforeNode == null) {
        addedNodes.add(entry.value);
      } else if (!_nodesEqual(beforeNode, entry.value)) {
        // Same identity, different content: an explicit remove+add pair,
        // never a silent overwrite — matches GraphMerge's philosophy.
        removedNodes.add(beforeNode);
        addedNodes.add(entry.value);
      }
    }
    for (final entry in beforeNodesById.entries) {
      if (!afterNodesById.containsKey(entry.key)) {
        removedNodes.add(entry.value);
      }
    }

    final beforeRelations = before.relations.map(_RelationKey.of).toSet();
    final afterRelations = after.relations.map(_RelationKey.of).toSet();

    final addedRelations = after.relations.where((r) => !beforeRelations.contains(_RelationKey.of(r))).toList();
    final removedRelations = before.relations.where((r) => !afterRelations.contains(_RelationKey.of(r))).toList();

    return RequirementGraphDiff(
      addedNodes: addedNodes,
      removedNodes: removedNodes,
      addedRelations: addedRelations,
      removedRelations: removedRelations,
    );
  }

  bool _nodesEqual(RequirementNode a, RequirementNode b) =>
      a.type == b.type && a.label == b.label && a.description == b.description && a.source == b.source;
}

class _RelationKey {
  final String fromId;
  final String toId;
  final RequirementRelationType type;

  const _RelationKey(this.fromId, this.toId, this.type);

  factory _RelationKey.of(RequirementRelation r) => _RelationKey(r.fromId, r.toId, r.type);

  @override
  bool operator ==(Object other) =>
      other is _RelationKey && other.fromId == fromId && other.toId == toId && other.type == type;

  @override
  int get hashCode => Object.hash(fromId, toId, type);
}
