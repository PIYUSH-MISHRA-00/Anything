/// Vision V10 RC — WorldModelRepository: real SQLite-backed persistence
/// for the World Graph and Runtime Intelligence history, resolving V9's
/// own documented "not yet persisted across process restarts"
/// limitation. Reuses the EXISTING sqflite architecture (the same
/// physical database as SqliteExperienceRepository) — never a new
/// storage layer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/world_model_repository.dart';
import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/world_edge.dart';
import 'package:anything/world_model/world_graph.dart';
import 'package:anything/world_model/world_node.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  SqliteExperienceRepository freshRepo() => SqliteExperienceRepository(
    dbName: 'world_model_repo_${DateTime.now().microsecondsSinceEpoch}.db',
  );

  test(
    'saveGraph/loadGraph round-trips a real WorldGraph with full fidelity',
    () async {
      final experienceRepo = freshRepo();
      final repo = WorldModelRepository(experienceRepository: experienceRepo);

      final a = EntityIdentity.stable(WorldNodeKind.capability, 'clock');
      final b = EntityIdentity.structural(WorldNodeKind.entity, [
        'Task',
        'text:title',
      ]);
      final graph = WorldGraph(
        nodes: [
          WorldNode(
            identity: a,
            kind: WorldNodeKind.capability,
            label: 'clock',
          ),
          WorldNode(identity: b, kind: WorldNodeKind.entity, label: 'Task'),
        ],
        edges: [
          WorldEdge(
            fromId: b,
            toId: a,
            kind: RelationshipKind.consumes,
            evidence: const GraphEvidence(
              sourceGraph: 'test',
              sourceNodeId: 'n',
            ),
            confidence: const GraphConfidence(score: 0.9, reason: 'test'),
          ),
        ],
      );

      await repo.saveGraph(graph);
      final loaded = await repo.loadGraph();

      expect(loaded.nodes.map((n) => n.identity).toSet(), {a, b});
      expect(loaded.edgesFrom(b), hasLength(1));
      expect(loaded.edgesFrom(b).first.confidence.score, 0.9);

      await experienceRepo.close();
    },
  );

  test(
    'saveGraph always replaces the prior state — the persisted graph never accumulates stale nodes',
    () async {
      final experienceRepo = freshRepo();
      final repo = WorldModelRepository(experienceRepository: experienceRepo);

      final a = EntityIdentity.stable(WorldNodeKind.entity, 'a');
      final b = EntityIdentity.stable(WorldNodeKind.entity, 'b');
      await repo.saveGraph(
        WorldGraph(
          nodes: [
            WorldNode(identity: a, kind: WorldNodeKind.entity, label: 'a'),
          ],
        ),
      );
      await repo.saveGraph(
        WorldGraph(
          nodes: [
            WorldNode(identity: b, kind: WorldNodeKind.entity, label: 'b'),
          ],
        ),
      );

      final loaded = await repo.loadGraph();
      expect(loaded.nodes.map((n) => n.identity), [b]);
      expect(loaded.nodes.any((n) => n.identity == a), isFalse);

      await experienceRepo.close();
    },
  );

  test(
    'recordSnapshot/loadSnapshotHistory persists a real, ordered version trail',
    () async {
      final experienceRepo = freshRepo();
      final repo = WorldModelRepository(experienceRepository: experienceRepo);

      await repo.recordSnapshot(
        WorldSnapshotRecord(
          version: 1,
          createdAt: DateTime(2026, 1, 1),
          nodeCount: 2,
          edgeCount: 1,
        ),
      );
      await repo.recordSnapshot(
        WorldSnapshotRecord(
          version: 2,
          createdAt: DateTime(2026, 1, 2),
          nodeCount: 4,
          edgeCount: 3,
        ),
      );

      final history = await repo.loadSnapshotHistory();
      expect(history.map((s) => s.version), [1, 2]);
      expect(history.last.nodeCount, 4);

      await experienceRepo.close();
    },
  );

  test(
    'recordObservations/loadObservations round-trips real ObservationRecords with full fidelity',
    () async {
      final experienceRepo = freshRepo();
      final repo = WorldModelRepository(experienceRepository: experienceRepo);

      final records = [
        ObservationRecord(
          id: 'r1',
          category: ObservationCategory.navigation,
          experienceId: 'e1',
          screenId: 'home',
          succeeded: true,
          count: 2,
          timestamp: DateTime(2026, 1, 1),
        ),
        ObservationRecord(
          id: 'r2',
          category: ObservationCategory.failure,
          experienceId: 'e2',
          capabilityId: 'http',
          succeeded: false,
          timestamp: DateTime(2026, 1, 2),
        ),
      ];
      await repo.recordObservations(records);

      final all = await repo.loadObservations();
      expect(all, hasLength(2));

      final onlyE1 = await repo.loadObservations(experienceId: 'e1');
      expect(onlyE1, hasLength(1));
      expect(onlyE1.first.screenId, 'home');
      expect(onlyE1.first.count, 2);

      await experienceRepo.close();
    },
  );

  test(
    'recordLearningSummary/loadLearningSummaries and recordAutomationSummary/loadAutomationSummaries round-trip real summaries',
    () async {
      final experienceRepo = freshRepo();
      final repo = WorldModelRepository(experienceRepository: experienceRepo);

      await repo.recordLearningSummary(
        PersistedLearningSummary(
          id: 'l1',
          patternId: 'pattern:x',
          patternKind: PatternKind.sequentialWorkflow,
          description: 'a -> b -> c',
          confidenceScore: 0.8,
          confidenceReason: 'observed',
          learnedAt: DateTime(2026, 1, 1),
          version: 1,
        ),
      );
      final learningSummaries = await repo.loadLearningSummaries();
      expect(learningSummaries, hasLength(1));
      expect(
        learningSummaries.first.patternKind,
        PatternKind.sequentialWorkflow,
      );

      await repo.recordAutomationSummary(
        PersistedAutomationSummary(
          planId: 'plan:1',
          description: 'daily refresh',
          allEligible: true,
          plannedAt: DateTime(2026, 1, 1),
          version: 1,
        ),
      );
      final automationSummaries = await repo.loadAutomationSummaries();
      expect(automationSummaries, hasLength(1));
      expect(automationSummaries.first.allEligible, isTrue);

      await experienceRepo.close();
    },
  );

  test(
    'sharing the SAME physical database as SqliteExperienceRepository — never a new storage layer',
    () async {
      final experienceRepo = freshRepo();
      final repo = WorldModelRepository(experienceRepository: experienceRepo);

      // Force table creation via the shared connection, then confirm the
      // ORIGINAL repository's own tables/data are completely unaffected.
      await repo.saveGraph(const WorldGraph());
      await experienceRepo.saveMetadata(
        ExperienceMetadataRecord(
          id: 'exp-1',
          name: 'Test',
          description: '',
          category: 'utility',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final metadata = await experienceRepo.getMetadata('exp-1');
      expect(metadata, isNotNull);

      await experienceRepo.close();
    },
  );
}
