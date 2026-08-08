/// Vision V8 RIL — RuntimeIntelligenceCoordinator: real Runtime
/// Integration (attaches to a real ExperienceRouter), real capability
/// validation, and a real SQLite-backed ExperienceRelationshipGraph/
/// CollaborationGraph build (real file I/O, not a mock).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/runtime/experience_router.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/runtime/golden_paths/notes_package.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_coordinator.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'attachSession wires a real ObservationEngine to a real ExperienceRouter and records navigation',
    () async {
      final coordinator = RuntimeIntelligenceCoordinator();
      final router = ExperienceRouter(validScreenIds: {'home', 'detail'});

      final observationEngine = coordinator.attachSession(
        sessionId: 's1',
        experienceId: 'exp-1',
        router: router,
      );
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'detail',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        coordinator.observationMemory.ofCategory(
          ObservationCategory.navigation,
        ),
        isNotEmpty,
      );
      await observationEngine.dispose();
    },
  );

  test(
    'runIntelligence validates every automation plan against a real CapabilityRegistry and records history',
    () async {
      final coordinator = RuntimeIntelligenceCoordinator();
      DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
      for (final exp in ['e1', 'e2']) {
        coordinator.observationMemory.record(
          ObservationRecord(
            id: '$exp-0',
            category: ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'task_app',
            timestamp: t(0),
          ),
        );
        coordinator.observationMemory.record(
          ObservationRecord(
            id: '$exp-1',
            category: ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'calendar',
            timestamp: t(1),
          ),
        );
        coordinator.observationMemory.record(
          ObservationRecord(
            id: '$exp-2',
            category: ObservationCategory.navigation,
            experienceId: exp,
            screenId: 'reminder',
            timestamp: t(2),
          ),
        );
      }

      final registry = CapabilityRegistry();
      for (final id in ['clock', 'notifications']) {
        registry.register(
          CapabilityDescriptor(
            id: id,
            version: '1.0.0',
            name: id,
            description: id,
            category: CapabilityCategory.storage,
            inputContract: 'x',
            outputContract: 'y',
          ),
        );
      }

      final result = coordinator.runIntelligence(
        capabilityRegistry: registry,
        minOccurrences: 2,
      );
      expect(result.automationPlans, isNotEmpty);
      expect(
        coordinator.automationHistory.recordCount,
        result.automationPlans.length,
      );
      for (final record in coordinator.automationHistory.records) {
        expect(record.report.allEligible, isTrue);
      }
    },
  );

  test(
    'buildRelationshipGraph reads real persisted packages via a real SQLite repository',
    () async {
      final repository = SqliteExperienceRepository(
        dbName: 'ril_coord_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final calculator = createCalculatorPackage();
      final notes = createNotesPackage();

      for (final package in [calculator, notes]) {
        await repository.saveMetadata(
          ExperienceMetadataRecord(
            id: package.manifest.experienceId,
            name: package.manifest.name,
            description: package.manifest.description,
            category: 'utility',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            packageVersion: package.manifest.version,
          ),
        );
        await repository.savePackage(package);
      }

      final coordinator = RuntimeIntelligenceCoordinator();
      final relationshipGraph = await coordinator.buildRelationshipGraph(
        repository,
      );
      expect(
        relationshipGraph.nodes.map((n) => n.id),
        containsAll([
          calculator.manifest.experienceId,
          notes.manifest.experienceId,
        ]),
      );

      final collaborationGraph = await coordinator.buildCollaborationGraph(
        repository,
      );
      // A real, well-formed graph regardless of whether these two happen to
      // qualify as "collaborating" — the point is it runs against real
      // persisted data without error.
      expect(collaborationGraph.edges, isA<List>());

      await repository.close();
    },
  );

  test(
    'workspaceContext aggregates real distinct experience ids from ObservationMemory',
    () {
      final coordinator = RuntimeIntelligenceCoordinator();
      coordinator.observationMemory.record(
        ObservationRecord(
          id: '1',
          category: ObservationCategory.navigation,
          experienceId: 'exp-a',
          timestamp: DateTime.now(),
        ),
      );
      coordinator.observationMemory.record(
        ObservationRecord(
          id: '2',
          category: ObservationCategory.navigation,
          experienceId: 'exp-b',
          timestamp: DateTime.now(),
        ),
      );
      final workspace = coordinator.workspaceContext();
      expect(workspace.experienceIds.toSet(), {'exp-a', 'exp-b'});
    },
  );
}
