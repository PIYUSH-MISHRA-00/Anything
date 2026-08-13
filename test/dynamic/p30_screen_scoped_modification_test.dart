/// IS-P30 — "Change this app" is screen-scoped: by default a change targets the
/// screen the user is currently viewing; it spans the app only when the request
/// says so ("the whole app", "all screens", …).
library;

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/capabilities/builtin/ai_capability.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Always returns one screenId-less addUiNode — so the coordinator's scoping is
/// the ONLY thing that decides which screen the button lands on.
class _AddButtonAi implements AiProvider {
  const _AddButtonAi();
  @override
  Future<String> generate(String prompt, {String? systemPrompt}) async =>
      '[{"type":"addUiNode","params":{"label":"Refresh","nodeType":"button"}}]';
}

int _nodesOn(ExperiencePackage pkg, String screenId) => pkg.interface.screens
    .where((s) => s.id == screenId)
    .fold<int>(0, (n, s) => n + s.children.length);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ExperienceModificationCoordinator, ExperiencePackage)> seed(
    AppComposition composition,
  ) async {
    final created = await composition.intentRouter.route(
      Intent.create(expression: 'houseplant watering log'),
    );
    final pkg = (created.creationResult as CreationCreated).package;
    // Needs ≥2 top-level screens for "which screen did it land on" to matter.
    expect(pkg.interface.screens.length, greaterThan(1));
    final coordinator = ExperienceModificationCoordinator(
      repository: composition.experienceRepository,
      worldModel: WorldModelCoordinator(),
      aiProvider: const _AddButtonAi(),
    );
    return (coordinator, pkg);
  }

  test('default: a change lands on the CURRENT screen, not the first screen', () async {
    final composition = AppComposition.freshForTesting();
    addTearDown(() => composition.experienceRepository.close());
    final (coordinator, pkg) = await seed(composition);

    final firstId = pkg.interface.screens.first.id;
    final currentId = pkg.interface.screens.last.id; // a NON-first screen
    final beforeCurrent = _nodesOn(pkg, currentId);
    final beforeFirst = _nodesOn(pkg, firstId);

    final plan = await coordinator.planEvolution(
      experienceId: pkg.manifest.experienceId,
      modificationExpression: 'add a refresh button',
      activeScreenId: currentId,
    );
    final after = plan!.candidatePackage!;

    expect(_nodesOn(after, currentId), beforeCurrent + 1,
        reason: 'the button must land on the screen the user is viewing');
    expect(_nodesOn(after, firstId), beforeFirst,
        reason: 'the first screen must be left untouched');
  });

  test('"the whole app": scoping is off, engine adds to the first screen', () async {
    final composition = AppComposition.freshForTesting();
    addTearDown(() => composition.experienceRepository.close());
    final (coordinator, pkg) = await seed(composition);

    final firstId = pkg.interface.screens.first.id;
    final currentId = pkg.interface.screens.last.id;
    final beforeFirst = _nodesOn(pkg, firstId);
    final beforeCurrent = _nodesOn(pkg, currentId);

    final plan = await coordinator.planEvolution(
      experienceId: pkg.manifest.experienceId,
      modificationExpression: 'add a refresh button to the whole app',
      activeScreenId: currentId,
    );
    final after = plan!.candidatePackage!;

    // wholeApp → the coordinator does NOT pin the node to currentId, so the
    // engine's default (first screen) applies.
    expect(_nodesOn(after, firstId), beforeFirst + 1);
    expect(_nodesOn(after, currentId), beforeCurrent);
  });
}
