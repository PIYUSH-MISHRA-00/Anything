/// Vision V7 AEE — EvolutionGraph: Current State -> Opportunities ->
/// Candidates -> Dependencies, all typed.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/evolution/evolution_estimator.dart';
import 'package:anything/evolution/evolution_graph.dart';
import 'package:anything/evolution/evolution_observer.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/software_architect/confidence.dart';

import 'evolution_test_support.dart';

void main() {
  const observer = EvolutionObserver();
  const estimator = EvolutionEstimator();
  const builder = EvolutionGraphBuilder();

  test(
    'every candidate produces a currentState -> opportunity -> candidate chain',
    () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final candidates = observer
          .observe(context)
          .map(estimator.estimate)
          .toList();
      final graph = builder.build(candidates);

      expect(
        graph.nodes.any((n) => n.kind == EvolutionGraphNodeKind.currentState),
        isTrue,
      );
      for (final candidate in candidates) {
        expect(graph.nodes.any((n) => n.id == candidate.id), isTrue);
        expect(graph.edgesTo(candidate.id), isNotEmpty);
      }
    },
  );

  test(
    'a synchronization candidate structurally requires the matching offline candidate',
    () {
      Confidence conf() => Confidence.full;
      final offline = estimator.estimate(
        EvolutionOpportunity(
          id: 'evolution:missingOffline:x',
          category: EvolutionOpportunityCategory.missingOffline,
          description: 'offline',
          reason: EvolutionReason(
            summary: 's',
            evidence: const EvolutionEvidence(
              affectedGraph: 'g',
              affectedNodeId: 'n',
            ),
            confidence: conf(),
          ),
        ),
      );
      final sync = estimator.estimate(
        EvolutionOpportunity(
          id: 'evolution:missingSynchronization:x',
          category: EvolutionOpportunityCategory.missingSynchronization,
          description: 'sync',
          reason: EvolutionReason(
            summary: 's',
            evidence: const EvolutionEvidence(
              affectedGraph: 'g',
              affectedNodeId: 'n',
            ),
            confidence: conf(),
          ),
        ),
      );

      final graph = builder.build([offline, sync]);
      final requiresEdges = graph
          .edgesFrom(sync.id)
          .where((e) => e.kind == EvolutionDependencyKind.requires)
          .toList();
      expect(requiresEdges.any((e) => e.toId == offline.id), isTrue);
    },
  );

  test(
    'every requires-edge genuinely connects a real missingSynchronization candidate to a real missingOffline candidate',
    () {
      final context = buildEvolutionContext(fieldSurveyApp());
      final candidates = observer
          .observe(context)
          .map(estimator.estimate)
          .toList();
      final graph = builder.build(candidates);
      final candidatesById = {for (final c in candidates) c.id: c};

      for (final edge in graph.edges.where(
        (e) => e.kind == EvolutionDependencyKind.requires,
      )) {
        expect(
          candidatesById[edge.fromId]?.opportunity.category,
          EvolutionOpportunityCategory.missingSynchronization,
        );
        expect(
          candidatesById[edge.toId]?.opportunity.category,
          EvolutionOpportunityCategory.missingOffline,
        );
      }
    },
  );
}
