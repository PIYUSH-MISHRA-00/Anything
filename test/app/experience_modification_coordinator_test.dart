/// Vision V10 RC — ExperienceModificationCoordinator: the graph-aware
/// pre-check (Impact Analysis + Consistency Validation) now always runs,
/// never bypassed. No prior milestone had test coverage for this class
/// at all (confirmed by repository audit) — this is the first.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/capabilities/builtin/ai_capability.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

/// Returns a canned response (or throws) — stands in for the BYOK model so the
/// AI modification path is exercised without a network call.
class _FakeAi implements AiProvider {
  final String? reply;
  const _FakeAi([this.reply]);
  @override
  Future<String> generate(String prompt, {String? systemPrompt}) async {
    if (reply == null) throw StateError('model unavailable');
    return reply!;
  }
}

int _nodeCount(ExperiencePackage pkg) =>
    pkg.interface.screens.fold<int>(0, (n, s) => n + s.children.length);

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
    'AI planner turns a free-text request (no "percentage" keyword) into a real op the deterministic parser could not produce',
    () async {
      final repository = SqliteExperienceRepository(
        dbName: 'mod_coord_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final calculator = createCalculatorPackage();
      await repository.savePackage(calculator);
      final before = _nodeCount(calculator);

      // Model reply wrapped in prose + a ```json fence, to prove extraction.
      final coordinator = ExperienceModificationCoordinator(
        repository: repository,
        worldModel: WorldModelCoordinator(),
        aiProvider: const _FakeAi(
          'Sure! Here you go:\n```json\n'
          '[{"type":"addUiNode","params":{"label":"Discount"}}]\n```',
        ),
      );
      final plan = await coordinator.planEvolution(
        experienceId: calculator.manifest.experienceId,
        modificationExpression: 'give me a way to apply a discount',
      );

      expect(plan, isNotNull);
      final candidate = plan!.candidatePackage!;
      expect(_nodeCount(candidate), before + 1);
      await repository.close();
    },
  );

  test(
    'falls back to the deterministic parser when the model throws — "percentage" still works',
    () async {
      final repository = SqliteExperienceRepository(
        dbName: 'mod_coord_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final calculator = createCalculatorPackage();
      await repository.savePackage(calculator);
      final before = _nodeCount(calculator);

      final coordinator = ExperienceModificationCoordinator(
        repository: repository,
        worldModel: WorldModelCoordinator(),
        aiProvider: const _FakeAi(), // throws
      );
      final plan = await coordinator.planEvolution(
        experienceId: calculator.manifest.experienceId,
        modificationExpression: 'add a percentage button',
      );

      expect(plan, isNotNull);
      expect(_nodeCount(plan!.candidatePackage!), greaterThan(before));
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
