/// Vision V10 RC — WorldModelCoordinator.persist()/restore(): a real
/// process-restart round-trip, resolving V9's own documented limitation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/world_model_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('persist() then restore() on a FRESH coordinator (simulating a process restart) recovers the real graph', () async {
    final experienceRepo = SqliteExperienceRepository(dbName: 'world_persist_${DateTime.now().microsecondsSinceEpoch}.db');
    final persistence = WorldModelRepository(experienceRepository: experienceRepo);

    final calculator = createCalculatorPackage();
    final metadata = ExperienceMetadataRecord(
      id: calculator.manifest.experienceId,
      name: calculator.manifest.name,
      description: calculator.manifest.description,
      category: 'utility',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final firstProcess = WorldModelCoordinator(persistence: persistence);
    firstProcess.ingestExperience(metadata, calculator);
    await firstProcess.persist();

    // A brand-new coordinator instance — nothing in memory — standing in
    // for a real process restart.
    final secondProcess = WorldModelCoordinator(persistence: persistence);
    expect(secondProcess.model.graph.nodes, isEmpty); // confirms it's genuinely fresh before restore

    await secondProcess.restore();
    expect(secondProcess.model.graph.nodesOfKind(WorldNodeKind.experience), isNotEmpty);
    expect(
      secondProcess.model.graph.nodesOfKind(WorldNodeKind.experience).map((n) => n.id),
      firstProcess.model.graph.nodesOfKind(WorldNodeKind.experience).map((n) => n.id),
    );

    await experienceRepo.close();
  });

  test('restore() on a coordinator with no persistence configured is a harmless no-op', () async {
    final coordinator = WorldModelCoordinator();
    await coordinator.restore(); // must not throw
    expect(coordinator.model.graph.nodes, isEmpty);
  });

  test('persist() on a coordinator with no persistence configured is a harmless no-op', () async {
    final coordinator = WorldModelCoordinator();
    await coordinator.persist(); // must not throw
  });
}
