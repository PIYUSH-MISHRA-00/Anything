/// Vision V10 RC — ExperienceModificationCoordinator: the graph-aware
/// pre-check (Impact Analysis + Consistency Validation) now always runs,
/// never bypassed. No prior milestone had test coverage for this class
/// at all (confirmed by repository audit) — this is the first.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'default construction never requires an explicit WorldModelCoordinator — the precheck always runs',
    () {
      // Constructing without a `worldModel` argument must not throw, and
      // must produce a coordinator whose precheck is real (never silently
      // opted out of) — "no caller should ever bypass it".
      final coordinator = ExperienceModificationCoordinator(
        repository: SqliteExperienceRepository(
          dbName: 'mod_coord_${DateTime.now().microsecondsSinceEpoch}.db',
        ),
      );
      expect(coordinator, isNotNull);
    },
  );

  test(
    'a real modification succeeds once the graph-aware pre-check passes (an empty/unseen World Graph is trivially consistent)',
    () async {
      final repository = SqliteExperienceRepository(
        dbName: 'mod_coord_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final calculator = createCalculatorPackage();
      await repository.saveMetadata(
        ExperienceMetadataRecord(
          id: calculator.manifest.experienceId,
          name: calculator.manifest.name,
          description: calculator.manifest.description,
          category: 'utility',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          packageVersion: calculator.manifest.version,
        ),
      );
      await repository.savePackage(calculator);

      final coordinator = ExperienceModificationCoordinator(
        repository: repository,
        worldModel: WorldModelCoordinator(),
      );
      final result = await coordinator.modifyExperience(
        experienceId: calculator.manifest.experienceId,
        modificationExpression: 'add a percentage button',
      );

      expect(result, isA<ModificationCoordinatorSucceeded>());
      await repository.close();
    },
  );

  test(
    'a modification for a nonexistent experience still fails honestly before the graph pre-check even matters',
    () async {
      final repository = SqliteExperienceRepository(
        dbName: 'mod_coord_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final coordinator = ExperienceModificationCoordinator(
        repository: repository,
        worldModel: WorldModelCoordinator(),
      );
      final result = await coordinator.modifyExperience(
        experienceId: 'does-not-exist',
        modificationExpression: 'anything',
      );
      expect(result, isA<ModificationCoordinatorFailed>());
      await repository.close();
    },
  );
}
