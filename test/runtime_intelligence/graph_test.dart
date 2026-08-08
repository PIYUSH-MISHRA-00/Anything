/// Vision V8 RIL — InteractionGraph (per-session), ExperienceRelationshipGraph
/// (Multi-Experience, inference-only), and CollaborationGraph (a filtered,
/// real view of the relationship graph).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/runtime_intelligence/collaboration_graph.dart';
import 'package:anything/runtime_intelligence/experience_relationship_graph.dart';
import 'package:anything/runtime_intelligence/interaction_graph.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';

void main() {
  group('InteractionGraph.fromRecords', () {
    test(
      'builds the real followed-by chain in observed order, de-duplicating consecutive repeats',
      () {
        DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
        final records = [
          ObservationRecord(
            id: '0',
            category: ObservationCategory.navigation,
            screenId: 'home',
            timestamp: t(0),
          ),
          ObservationRecord(
            id: '1',
            category: ObservationCategory.navigation,
            screenId: 'home',
            timestamp: t(1),
          ), // repeat, no self-loop
          ObservationRecord(
            id: '2',
            category: ObservationCategory.navigation,
            screenId: 'detail',
            timestamp: t(2),
          ),
        ];
        final graph = InteractionGraph.fromRecords(records);

        expect(graph.nodes.map((n) => n.id).toSet(), {'home', 'detail'});
        expect(graph.edges, hasLength(1));
        expect(graph.edges.first.fromId, 'home');
        expect(graph.edges.first.toId, 'detail');
      },
    );
  });

  group('ExperienceRelationshipGraph.infer — inference-only, never hardcoded', () {
    test(
      'two experiences sharing a capability get a real, explained sharesCapability edge',
      () {
        final fingerprints = [
          const ExperienceFingerprint(
            experienceId: 'budget',
            name: 'Budget',
            capabilityIds: ['clock', 'knowledge'],
          ),
          const ExperienceFingerprint(
            experienceId: 'calendar',
            name: 'Calendar',
            capabilityIds: ['clock'],
          ),
          const ExperienceFingerprint(
            experienceId: 'unrelated',
            name: 'Unrelated',
            capabilityIds: ['http'],
          ),
        ];
        final graph = ExperienceRelationshipGraph.infer(fingerprints);

        final edge = graph
            .edgesFrom('budget')
            .where((e) => e.toId == 'calendar')
            .firstOrNull;
        expect(edge, isNotNull);
        expect(edge!.kind, ExperienceRelationshipKind.sharesCapability);
        expect(edge.rationale, contains('clock'));

        expect(
          graph.edgesFrom('budget').any((e) => e.toId == 'unrelated'),
          isFalse,
        );
      },
    );

    test(
      'two experiences sharing 2+ entity field types get a real sharesDataShape edge',
      () {
        final fingerprints = [
          const ExperienceFingerprint(
            experienceId: 'notes',
            name: 'Notes',
            entityFieldTypeNames: ['text', 'dateTime'],
          ),
          const ExperienceFingerprint(
            experienceId: 'reminder',
            name: 'Reminder',
            entityFieldTypeNames: ['text', 'dateTime'],
          ),
        ];
        final graph = ExperienceRelationshipGraph.infer(fingerprints);
        expect(
          graph
              .edgesFrom('notes')
              .any((e) => e.kind == ExperienceRelationshipKind.sharesDataShape),
          isTrue,
        );
      },
    );

    test('experiences with zero structural overlap get zero edges', () {
      final fingerprints = [
        const ExperienceFingerprint(
          experienceId: 'a',
          name: 'A',
          capabilityIds: ['http'],
        ),
        const ExperienceFingerprint(
          experienceId: 'b',
          name: 'B',
          capabilityIds: ['knowledge'],
        ),
      ];
      final graph = ExperienceRelationshipGraph.infer(fingerprints);
      expect(graph.edges, isEmpty);
    });
  });

  group('CollaborationGraph.fromRelationshipGraph — a real, filtered view', () {
    test(
      'only pairs with 2+ independent structural signals qualify as "working together"',
      () {
        final fingerprints = [
          const ExperienceFingerprint(
            experienceId: 'budget',
            name: 'Budget',
            capabilityIds: ['clock'],
            entityFieldTypeNames: ['currency', 'dateTime'],
          ),
          const ExperienceFingerprint(
            experienceId: 'calendar',
            name: 'Calendar',
            capabilityIds: ['clock'],
            entityFieldTypeNames: ['currency', 'dateTime'],
          ),
          const ExperienceFingerprint(
            experienceId: 'notes',
            name: 'Notes',
            capabilityIds: ['clock'],
          ),
        ];
        final relationshipGraph = ExperienceRelationshipGraph.infer(
          fingerprints,
        );
        final collaborationGraph = CollaborationGraph.fromRelationshipGraph(
          relationshipGraph,
        );

        expect(
          collaborationGraph.edges.any(
            (e) => e.fromId == 'budget' && e.toId == 'calendar',
          ),
          isTrue,
        );
        // budget/notes only share ONE signal (capability) — not strong enough.
        expect(
          collaborationGraph.edges.any(
            (e) =>
                (e.fromId == 'budget' || e.toId == 'budget') &&
                (e.fromId == 'notes' || e.toId == 'notes'),
          ),
          isFalse,
        );
      },
    );
  });
}
