/// PatternDetector — Pattern Detection. Finds real, structural
/// regularities in a UsageGraph: frequent screen pairs, frequent
/// capabilities, navigation loops, and multi-hop sequential workflows
/// (e.g. "creates a task app, then opens the calendar, then sets a
/// reminder" — never recognized by domain name, only by the shape of
/// real, counted co-occurrence edges).
library;

import 'pattern.dart';
import 'ril_types.dart';
import 'usage_graph.dart';

class PatternDetector {
  const PatternDetector();

  List<Pattern> detect(UsageGraph graph, {int minOccurrences = 2}) {
    return [
      ..._frequentFeaturePairs(graph, minOccurrences),
      ..._frequentCapabilities(graph, minOccurrences),
      ..._navigationLoops(graph, minOccurrences),
      ..._sequentialWorkflows(graph, minOccurrences),
    ];
  }

  List<Pattern> _frequentFeaturePairs(UsageGraph graph, int minOccurrences) {
    return graph.edges
        .where((e) => e.coOccurrenceCount >= minOccurrences)
        .map(
          (e) => Pattern(
            id: 'pattern:frequentFeaturePair:${e.fromId}->${e.toId}',
            kind: PatternKind.frequentFeaturePair,
            description: '"${e.fromId}" is frequently followed by "${e.toId}"',
            evidence: [
              PatternEvidence(
                usageGraphNodeOrEdgeId: '${e.fromId}->${e.toId}',
                occurrenceCount: e.coOccurrenceCount,
              ),
            ],
            confidence: PatternConfidence(
              score: (e.coOccurrenceCount / (minOccurrences * 2)).clamp(
                0.0,
                1.0,
              ),
              reason:
                  'Observed ${e.coOccurrenceCount} times, at or above the $minOccurrences-occurrence threshold.',
            ),
          ),
        )
        .toList();
  }

  List<Pattern> _frequentCapabilities(UsageGraph graph, int minOccurrences) {
    return graph.nodes
        .where(
          (n) =>
              n.node.kind == RilNodeKind.capability &&
              n.usageCount >= minOccurrences,
        )
        .map(
          (n) => Pattern(
            id: 'pattern:frequentCapability:${n.id}',
            kind: PatternKind.frequentCapability,
            description: 'Capability "${n.id}" is used frequently',
            evidence: [
              PatternEvidence(
                usageGraphNodeOrEdgeId: n.id,
                occurrenceCount: n.usageCount,
              ),
            ],
            confidence: PatternConfidence(
              score: (n.usageCount / (minOccurrences * 2)).clamp(0.0, 1.0),
              reason:
                  'Used ${n.usageCount} times, at or above the $minOccurrences-occurrence threshold.',
            ),
          ),
        )
        .toList();
  }

  List<Pattern> _navigationLoops(UsageGraph graph, int minOccurrences) {
    final patterns = <Pattern>[];
    final seen = <String>{};
    for (final edge in graph.edges) {
      if (edge.coOccurrenceCount < minOccurrences) continue;
      final reverseKey = '${edge.toId}->${edge.fromId}';
      final forwardKey = '${edge.fromId}->${edge.toId}';
      if (seen.contains(reverseKey) || seen.contains(forwardKey)) continue;
      final reverse = graph.edges
          .where((e) => e.fromId == edge.toId && e.toId == edge.fromId)
          .firstOrNull;
      if (reverse != null && reverse.coOccurrenceCount >= minOccurrences) {
        seen.add(forwardKey);
        patterns.add(
          Pattern(
            id: 'pattern:navigationLoop:${edge.fromId}<->${edge.toId}',
            kind: PatternKind.navigationLoop,
            description:
                '"${edge.fromId}" and "${edge.toId}" are navigated between repeatedly',
            evidence: [
              PatternEvidence(
                usageGraphNodeOrEdgeId: forwardKey,
                occurrenceCount: edge.coOccurrenceCount,
              ),
              PatternEvidence(
                usageGraphNodeOrEdgeId: reverseKey,
                occurrenceCount: reverse.coOccurrenceCount,
              ),
            ],
            confidence: const PatternConfidence(
              score: 0.7,
              reason: 'Both directions observed at or above threshold.',
            ),
          ),
        );
      }
    }
    return patterns;
  }

  List<Pattern> _sequentialWorkflows(UsageGraph graph, int minOccurrences) {
    final patterns = <Pattern>[];
    for (final first in graph.edges) {
      if (first.coOccurrenceCount < minOccurrences) continue;
      for (final second in graph.edgesFrom(first.toId)) {
        if (second.coOccurrenceCount < minOccurrences) continue;
        if (second.toId == first.fromId) {
          continue; // that's a loop, not a workflow
        }
        patterns.add(
          Pattern(
            id: 'pattern:sequentialWorkflow:${first.fromId}->${first.toId}->${second.toId}',
            kind: PatternKind.sequentialWorkflow,
            description:
                '"${first.fromId}" -> "${first.toId}" -> "${second.toId}" is a recurring workflow',
            evidence: [
              PatternEvidence(
                usageGraphNodeOrEdgeId: '${first.fromId}->${first.toId}',
                occurrenceCount: first.coOccurrenceCount,
              ),
              PatternEvidence(
                usageGraphNodeOrEdgeId: '${first.toId}->${second.toId}',
                occurrenceCount: second.coOccurrenceCount,
              ),
            ],
            confidence: PatternConfidence(
              score:
                  ((first.coOccurrenceCount + second.coOccurrenceCount) /
                          (minOccurrences * 4))
                      .clamp(0.0, 1.0),
              reason:
                  'Both hops observed at or above the $minOccurrences-occurrence threshold.',
            ),
          ),
        );
      }
    }
    return patterns;
  }
}
