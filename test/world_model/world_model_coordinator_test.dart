/// Vision V9 WMSG — WorldModelCoordinator end-to-end: real ingestion from
/// multiple sources, Modification Integration (a real pre-check before
/// the EXISTING ModificationEngine would run), and a real SQLite-backed
/// bulk ingestion of every persisted Experience.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/runtime/golden_paths/notes_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'ingestExperience grows the World Graph deterministically and versions it',
    () {
      final coordinator = WorldModelCoordinator();
      final calculator = createCalculatorPackage();
      final metadata = ExperienceMetadataRecord(
        id: calculator.manifest.experienceId,
        name: calculator.manifest.name,
        description: calculator.manifest.description,
        category: 'utility',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(coordinator.model.version.number, 0);
      coordinator.ingestExperience(metadata, calculator);
      expect(coordinator.model.version.number, 1);
      expect(coordinator.model.graph.nodes, isNotEmpty);
      expect(coordinator.history.snapshotCount, 1);
    },
  );

  test(
    'Modification Integration: precheckModification reports a real impact analysis before ModificationEngine would run',
    () {
      final coordinator = WorldModelCoordinator();
      final calculator = createCalculatorPackage();
      final metadata = ExperienceMetadataRecord(
        id: calculator.manifest.experienceId,
        name: calculator.manifest.name,
        description: calculator.manifest.description,
        category: 'utility',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      coordinator.ingestExperience(metadata, calculator);

      final check = coordinator.precheckModification(
        calculator.manifest.experienceId,
      );
      expect(check.approved, isTrue); // graph is structurally sound
      expect(
        check.impact.subject,
        EntityIdentity.stable(
          WorldNodeKind.experience,
          calculator.manifest.experienceId,
        ),
      );
    },
  );

  test(
    'precheckModification for a never-ingested experience honestly reports zero impact, never fabricated',
    () {
      final coordinator = WorldModelCoordinator();
      final check = coordinator.precheckModification('never-seen-experience');
      expect(check.impact.impactedNodes, isEmpty);
    },
  );

  test(
    'ingestAllPersistedExperiences reads every real Experience from a real SQLite repository',
    () async {
      final repository = SqliteExperienceRepository(
        dbName: 'world_model_coord_${DateTime.now().microsecondsSinceEpoch}.db',
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
          ),
        );
        await repository.savePackage(package);
      }

      final coordinator = WorldModelCoordinator();
      await coordinator.ingestAllPersistedExperiences(repository);

      final experienceNodes = coordinator.model.graph.nodesOfKind(
        WorldNodeKind.experience,
      );
      expect(
        experienceNodes.map((n) => n.id),
        containsAll([
          EntityIdentity.stable(
            WorldNodeKind.experience,
            calculator.manifest.experienceId,
          ).value,
          EntityIdentity.stable(
            WorldNodeKind.experience,
            notes.manifest.experienceId,
          ).value,
        ]),
      );

      await repository.close();
    },
  );

  test(
    'two Experiences that both consume the same capability share a single, deduplicated capability node',
    () async {
      final repository = SqliteExperienceRepository(
        dbName: 'world_model_coord_${DateTime.now().microsecondsSinceEpoch}.db',
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
          ),
        );
        await repository.savePackage(package);
      }

      final coordinator = WorldModelCoordinator();
      await coordinator.ingestAllPersistedExperiences(repository);

      final capabilityNodes = coordinator.model.graph.nodesOfKind(
        WorldNodeKind.capability,
      );
      final uniqueIds = capabilityNodes.map((n) => n.id).toSet();
      expect(
        capabilityNodes.length,
        uniqueIds.length,
      ); // never a duplicate identity

      await repository.close();
    },
  );
}
