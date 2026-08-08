/// UsageGraph — real usage frequencies aggregated across every session in
/// ObservationMemory: how often each screen/entity/capability was used,
/// and how often two screens were used back-to-back. The structural
/// substrate PatternDetector reasons over — never raw content, only
/// counts.
library;

import 'observation_record.dart';
import 'ril_types.dart';

class UsageNode {
  final RilNode node;
  final int usageCount;

  const UsageNode({required this.node, required this.usageCount});

  String get id => node.id;
}

class UsageEdge {
  final String fromId;
  final String toId;
  final int coOccurrenceCount;

  const UsageEdge({
    required this.fromId,
    required this.toId,
    required this.coOccurrenceCount,
  });
}

class UsageGraph {
  final List<UsageNode> nodes;
  final List<UsageEdge> edges;

  const UsageGraph({this.nodes = const [], this.edges = const []});

  UsageNode? nodeById(String id) => nodes.where((n) => n.id == id).firstOrNull;

  List<UsageEdge> edgesFrom(String id) =>
      edges.where((e) => e.fromId == id).toList();

  /// Aggregates usage counts and screen-to-screen co-occurrence across
  /// every record in memory, grouped by experience so one session's
  /// navigation chain never bleeds into another's.
  factory UsageGraph.fromRecords(List<ObservationRecord> records) {
    final usageCounts = <String, int>{};
    final kinds = <String, RilNodeKind>{};

    void tally(String? id, RilNodeKind kind) {
      if (id == null) return;
      usageCounts[id] = (usageCounts[id] ?? 0) + 1;
      kinds[id] = kind;
    }

    for (final record in records) {
      tally(record.screenId, RilNodeKind.screen);
      tally(record.entityId, RilNodeKind.entity);
      tally(record.capabilityId, RilNodeKind.capability);
    }

    final byExperience = <String?, List<ObservationRecord>>{};
    for (final record in records) {
      byExperience.putIfAbsent(record.experienceId, () => []).add(record);
    }

    final coOccurrence = <String, int>{};
    for (final sessionRecords in byExperience.values) {
      final screenSequence = sessionRecords
          .where(
            (r) =>
                r.category == ObservationCategory.navigation &&
                r.screenId != null,
          )
          .map((r) => r.screenId!)
          .toList();
      for (var i = 1; i < screenSequence.length; i++) {
        final from = screenSequence[i - 1];
        final to = screenSequence[i];
        if (from == to) continue;
        final key = '$from->$to';
        coOccurrence[key] = (coOccurrence[key] ?? 0) + 1;
      }
    }

    final nodes = usageCounts.entries
        .map(
          (e) => UsageNode(
            node: RilNode(id: e.key, kind: kinds[e.key]!, label: e.key),
            usageCount: e.value,
          ),
        )
        .toList();
    final edges = coOccurrence.entries.map((e) {
      final parts = e.key.split('->');
      return UsageEdge(
        fromId: parts[0],
        toId: parts[1],
        coOccurrenceCount: e.value,
      );
    }).toList();

    return UsageGraph(nodes: nodes, edges: edges);
  }
}
