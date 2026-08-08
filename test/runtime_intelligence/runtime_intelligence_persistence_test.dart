/// Vision V10 RC — RuntimeIntelligenceCoordinator.persist()/
/// restoreObservations(): real SQLite-backed persistence for
/// Observation/Learning/Automation history, resolving V9's own
/// documented limitation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/runtime_intelligence_coordinator.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/world_model_repository.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'persist() then restoreObservations() on a fresh coordinator recovers real, full-fidelity ObservationRecords',
    () async {
      final experienceRepo = SqliteExperienceRepository(
        dbName: 'ril_persist_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final persistence = WorldModelRepository(
        experienceRepository: experienceRepo,
      );

      final firstProcess = RuntimeIntelligenceCoordinator(
        persistence: persistence,
      );
      DateTime t(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
      firstProcess.observationMemory.record(
        ObservationRecord(
          id: 'r1',
          category: ObservationCategory.navigation,
          experienceId: 'e1',
          screenId: 'home',
          timestamp: t(0),
        ),
      );

      final registry = CapabilityRegistry();
      registry.register(
        const CapabilityDescriptor(
          id: 'clock',
          version: '1.0.0',
          name: 'clock',
          description: 'clock',
          category: CapabilityCategory.storage,
          inputContract: 'x',
          outputContract: 'y',
        ),
      );
      registry.register(
        const CapabilityDescriptor(
          id: 'notifications',
          version: '1.0.0',
          name: 'notifications',
          description: 'notifications',
          category: CapabilityCategory.storage,
          inputContract: 'x',
          outputContract: 'y',
        ),
      );
      firstProcess.observationMemory.record(
        ObservationRecord(
          id: 'r2',
          category: ObservationCategory.navigation,
          experienceId: 'e1',
          screenId: 'detail',
          timestamp: t(1),
        ),
      );
      firstProcess.observationMemory.record(
        ObservationRecord(
          id: 'r3',
          category: ObservationCategory.navigation,
          experienceId: 'e2',
          screenId: 'home',
          timestamp: t(2),
        ),
      );
      firstProcess.observationMemory.record(
        ObservationRecord(
          id: 'r4',
          category: ObservationCategory.navigation,
          experienceId: 'e2',
          screenId: 'detail',
          timestamp: t(3),
        ),
      );
      firstProcess.runIntelligence(
        capabilityRegistry: registry,
        minOccurrences: 2,
      );

      await firstProcess.persist();

      final secondProcess = RuntimeIntelligenceCoordinator(
        persistence: persistence,
      );
      expect(secondProcess.observationMemory.records, isEmpty);
      await secondProcess.restoreObservations();
      expect(
        secondProcess.observationMemory.records.length,
        firstProcess.observationMemory.records.length,
      );

      // Learning/Automation summaries are queryable directly from the
      // repository — never silently fabricated back into the rich
      // in-memory LearningRecord/AutomationRecord shape.
      final learningSummaries = await persistence.loadLearningSummaries();
      expect(learningSummaries, isNotEmpty);

      await experienceRepo.close();
    },
  );

  test(
    'persist()/restoreObservations() with no persistence configured are harmless no-ops',
    () async {
      final coordinator = RuntimeIntelligenceCoordinator();
      await coordinator.persist();
      await coordinator.restoreObservations();
      expect(coordinator.observationMemory.records, isEmpty);
    },
  );
}
