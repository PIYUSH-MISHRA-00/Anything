/// Implementation Milestone R6 — Deterministic Runtime Patching, Live
/// Experience Evolution. Proves `ExperienceModificationCoordinator.
/// applyEvolutionPlan()`/`rollback()` — real validate-before-persist,
/// World Model accept-only ingestion, deterministic rollback via the
/// pre-apply package snapshot, and a REAL live proof that the existing,
/// unmodified `AnythingRuntime`/`ExperienceRenderer` reflect an applied
/// change after the same `closeSession()` -> `openExperience()` reload
/// sequence this codebase has used since before Vision Milestone V1.
///
/// `AnythingRuntime`/`ExperienceRenderer`/`BehaviorInterpreter` are NOT
/// modified by this milestone — confirmed by `git diff` before commit —
/// this test file proves the EXISTING reload mechanism composes
/// correctly with the NEW apply/rollback methods, never that the runtime
/// itself changed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_package_diff.dart';
import 'package:anything/evolution/evolution_diff_plan.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_renderer.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

ExperiencePackage _package({
  String experienceId = 'exp-1',
  String version = '1',
  List<InterfaceScreen> screens = const [],
  List<CapabilityDeclaration> capabilities = const [],
}) {
  final now = DateTime(2026);
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: experienceId,
      name: 'Test',
      description: 'd',
      category: 'general',
      entryPoint: screens.isNotEmpty ? screens.first.id : 's1',
      version: version,
      createdAt: now,
      updatedAt: now,
    ),
    interface: InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    capabilityDeclarations: capabilities,
    provenance: const PackageProvenance(
      creationEngineVersion: 'test',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
  );
}

Future<SqliteExperienceRepository> _seededRepo(
  ExperiencePackage package,
) async {
  final repo = SqliteExperienceRepository(
    dbName: 'r6_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  await repo.saveMetadata(
    ExperienceMetadataRecord(
      id: package.manifest.experienceId,
      name: 'Test',
      description: 'd',
      category: 'general',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );
  await repo.savePackage(package);
  return repo;
}

EvolutionDiffPlan _planFor({
  required String experienceId,
  required ExperiencePackage before,
  required ExperiencePackage after,
}) {
  final diff = const ExperienceDiffer().diff(before, after);
  return EvolutionDiffPlanBuilder().build(
    experienceId: experienceId,
    experienceDiff: diff,
    candidatePackage: after,
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('applyEvolutionPlan (R6)', () {
    test(
      'a valid plan persists the candidate, and previousPackage is the real pre-apply state',
      () async {
        final before = _package(
          screens: [
            const InterfaceScreen(
              id: 's1',
              title: 'Home',
              children: [
                InterfaceNode(
                  type: 'text',
                  id: 'n1',
                  properties: {'text': 'Old'},
                ),
              ],
            ),
          ],
        );
        final after = _package(
          version: '2',
          screens: [
            const InterfaceScreen(
              id: 's1',
              title: 'Home',
              children: [
                InterfaceNode(
                  type: 'text',
                  id: 'n1',
                  properties: {'text': 'New'},
                ),
              ],
            ),
          ],
        );
        final repo = await _seededRepo(before);
        final coordinator = ExperienceModificationCoordinator(
          repository: repo,
          worldModel: WorldModelCoordinator(),
          activity: ActivityRepository(),
        );

        final plan = _planFor(
          experienceId: 'exp-1',
          before: before,
          after: after,
        );
        final result = await coordinator.applyEvolutionPlan(plan);

        expect(result, isA<ModificationCoordinatorSucceeded>());
        final succeeded = result as ModificationCoordinatorSucceeded;
        expect(succeeded.newVersion, '2');
        expect(succeeded.previousPackage?.manifest.version, '1');

        final persisted = await repo.getPackage('exp-1');
        expect(persisted?.manifest.version, '2');
        await repo.close();
      },
    );

    test(
      'an invalid candidate is rejected — old package untouched, World Graph untouched',
      () async {
        final before = _package();
        // Exceeds the real screen-count budget RuntimeSecurityLimits enforces
        // (ExperiencePackageValidator) — a real, deterministic rejection, not
        // a fabricated one.
        final tooManyScreens = List.generate(
          500,
          (i) => InterfaceScreen(id: 's$i', title: 'S$i'),
        );
        final invalidCandidate = _package(
          version: '2',
          screens: tooManyScreens,
        );
        final repo = await _seededRepo(before);
        final worldModel = WorldModelCoordinator();
        final coordinator = ExperienceModificationCoordinator(
          repository: repo,
          worldModel: worldModel,
          activity: ActivityRepository(),
        );

        final plan = _planFor(
          experienceId: 'exp-1',
          before: before,
          after: invalidCandidate,
        );
        final result = await coordinator.applyEvolutionPlan(plan);

        expect(result, isA<ModificationCoordinatorFailed>());
        final persisted = await repo.getPackage('exp-1');
        expect(
          persisted?.manifest.version,
          '1',
          reason: 'a rejected apply must never touch the persisted package',
        );
        expect(
          worldModel.model.graph.nodesOfKind(WorldNodeKind.experience),
          isEmpty,
          reason: 'a rejected apply must never mutate the World Graph',
        );
        await repo.close();
      },
    );

    test(
      'a plan with no candidatePackage (e.g. built directly, pre-R6-style) is honestly rejected, never crashes',
      () async {
        final before = _package();
        final repo = await _seededRepo(before);
        final coordinator = ExperienceModificationCoordinator(
          repository: repo,
          worldModel: WorldModelCoordinator(),
          activity: ActivityRepository(),
        );

        final bareplan = EvolutionDiffPlanBuilder().build(
          experienceId: 'exp-1',
          experienceDiff: ExperienceDiff.empty,
        );
        final result = await coordinator.applyEvolutionPlan(bareplan);

        expect(result, isA<ModificationCoordinatorFailed>());
        await repo.close();
      },
    );

    test(
      'World Graph gains an experience node on a successful apply',
      () async {
        final before = _package();
        final after = _package(
          version: '2',
          screens: [const InterfaceScreen(id: 's1', title: 'Home')],
        );
        final repo = await _seededRepo(before);
        final worldModel = WorldModelCoordinator();
        final coordinator = ExperienceModificationCoordinator(
          repository: repo,
          worldModel: worldModel,
          activity: ActivityRepository(),
        );

        final plan = _planFor(
          experienceId: 'exp-1',
          before: before,
          after: after,
        );
        final result = await coordinator.applyEvolutionPlan(plan);

        expect(result, isA<ModificationCoordinatorSucceeded>());
        expect(
          worldModel.model.graph.nodesOfKind(WorldNodeKind.experience),
          isNotEmpty,
        );
        await repo.close();
      },
    );
  });

  group('rollback (R6)', () {
    test('rollback restores the exact pre-apply package', () async {
      final before = _package(
        screens: [
          const InterfaceScreen(
            id: 's1',
            title: 'Home',
            children: [
              InterfaceNode(
                type: 'text',
                id: 'n1',
                properties: {'text': 'Old'},
              ),
            ],
          ),
        ],
      );
      final after = _package(
        version: '2',
        screens: [
          const InterfaceScreen(
            id: 's1',
            title: 'Home',
            children: [
              InterfaceNode(
                type: 'text',
                id: 'n1',
                properties: {'text': 'New'},
              ),
            ],
          ),
        ],
      );
      final repo = await _seededRepo(before);
      final coordinator = ExperienceModificationCoordinator(
        repository: repo,
        worldModel: WorldModelCoordinator(),
        activity: ActivityRepository(),
      );

      final plan = _planFor(
        experienceId: 'exp-1',
        before: before,
        after: after,
      );
      final applied =
          await coordinator.applyEvolutionPlan(plan)
              as ModificationCoordinatorSucceeded;
      expect((await repo.getPackage('exp-1'))?.manifest.version, '2');

      final rolledBack = await coordinator.rollback(
        experienceId: 'exp-1',
        previousPackage: applied.previousPackage!,
      );

      expect(rolledBack, isA<ModificationCoordinatorSucceeded>());
      final restored = await repo.getPackage('exp-1');
      expect(restored?.manifest.version, '1');
      expect(
        restored?.interface.screens.first.children.first.properties['text'],
        'Old',
      );
      await repo.close();
    });

    test(
      'rollback itself returns a previousPackage, so a rollback can itself be undone',
      () async {
        final before = _package();
        final after = _package(version: '2');
        final repo = await _seededRepo(before);
        final coordinator = ExperienceModificationCoordinator(
          repository: repo,
          worldModel: WorldModelCoordinator(),
          activity: ActivityRepository(),
        );

        final plan = _planFor(
          experienceId: 'exp-1',
          before: before,
          after: after,
        );
        final applied =
            await coordinator.applyEvolutionPlan(plan)
                as ModificationCoordinatorSucceeded;
        final rolledBack =
            await coordinator.rollback(
                  experienceId: 'exp-1',
                  previousPackage: applied.previousPackage!,
                )
                as ModificationCoordinatorSucceeded;

        expect(
          rolledBack.previousPackage?.manifest.version,
          '2',
          reason: 'undo-the-undo must be possible',
        );
        await repo.close();
      },
    );
  });

  group(
    'Live runtime reload (R6) — real proof, not a package-level assertion only',
    () {
      testWidgets(
        'after applying a plan and reloading via the EXISTING AnythingRuntime.closeSession/openExperience, the new content is genuinely rendered',
        (tester) async {
          // Every real-SQLite/AnythingRuntime async call is wrapped in
          // tester.runAsync() — this codebase's own established, documented
          // requirement for real (databaseFactoryFfiNoIsolate) SQLite calls
          // triggered inside a testWidgets body, to avoid the FakeAsync
          // deadlock this project's own history (Stage 11 certification)
          // already root-caused and fixed the same way.
          final before = _package(
            screens: [
              const InterfaceScreen(
                id: 's1',
                title: 'Home',
                children: [
                  InterfaceNode(
                    type: 'text',
                    id: 'n1',
                    properties: {'content': 'Before Patch'},
                  ),
                ],
              ),
            ],
          );
          final after = _package(
            version: '2',
            screens: [
              const InterfaceScreen(
                id: 's1',
                title: 'Home',
                children: [
                  InterfaceNode(
                    type: 'text',
                    id: 'n1',
                    properties: {'content': 'After Patch'},
                  ),
                ],
              ),
            ],
          );

          late SqliteExperienceRepository repo;
          late ExperienceModificationCoordinator coordinator;
          final runtime = AnythingRuntime();

          await tester.runAsync(() async {
            repo = await _seededRepo(before);
            coordinator = ExperienceModificationCoordinator(
              repository: repo,
              worldModel: WorldModelCoordinator(),
              activity: ActivityRepository(),
            );
            await runtime.openExperience(before);
          });

          final renderer = ExperienceRenderer();
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => renderer.renderScreen(
                  context,
                  's1',
                  runtime.currentSession!.package.interface,
                  runtime.stateEngine,
                ),
              ),
            ),
          );
          expect(find.text('Before Patch'), findsOneWidget);
          expect(find.text('After Patch'), findsNothing);

          ModificationCoordinatorResult result =
              const ModificationCoordinatorFailed(message: 'unset');
          await tester.runAsync(() async {
            final plan = _planFor(
              experienceId: 'exp-1',
              before: before,
              after: after,
            );
            result = await coordinator.applyEvolutionPlan(plan);

            // The EXISTING reload sequence (ExperienceHostScreen._submitModification
            // has used exactly this since before V1) — never a new runtime method.
            await runtime.closeSession();
            await runtime.openExperience(
              (result as ModificationCoordinatorSucceeded).newPackage,
            );
          });
          expect(result, isA<ModificationCoordinatorSucceeded>());

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => renderer.renderScreen(
                  context,
                  's1',
                  runtime.currentSession!.package.interface,
                  runtime.stateEngine,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.text('After Patch'),
            findsOneWidget,
            reason: 'the live runtime must genuinely reflect the applied patch',
          );
          expect(find.text('Before Patch'), findsNothing);

          await tester.runAsync(() async {
            await runtime.closeSession();
            await repo.close();
          });
        },
      );
    },
  );

  group('Determinism (R6)', () {
    test(
      'applying the same plan to two independent, identically-seeded repositories produces identical persisted packages',
      () async {
        final before = _package();
        final after = _package(
          version: '2',
          screens: [const InterfaceScreen(id: 's1', title: 'Home')],
        );
        final repoA = await _seededRepo(before);
        final repoB = await _seededRepo(before);
        final coordA = ExperienceModificationCoordinator(
          repository: repoA,
          worldModel: WorldModelCoordinator(),
          activity: ActivityRepository(),
        );
        final coordB = ExperienceModificationCoordinator(
          repository: repoB,
          worldModel: WorldModelCoordinator(),
          activity: ActivityRepository(),
        );

        final planA = _planFor(
          experienceId: 'exp-1',
          before: before,
          after: after,
        );
        final planB = _planFor(
          experienceId: 'exp-1',
          before: before,
          after: after,
        );
        await coordA.applyEvolutionPlan(planA);
        await coordB.applyEvolutionPlan(planB);

        final pA = await repoA.getPackage('exp-1');
        final pB = await repoB.getPackage('exp-1');
        expect(pA?.toJson(), pB?.toJson());
        await repoA.close();
        await repoB.close();
      },
    );
  });

  group('Performance (R6)', () {
    test(
      'apply + rollback over 50 sequential modifications stays correct and reports real elapsed time',
      () async {
        final before = _package();
        final repo = await _seededRepo(before);
        final coordinator = ExperienceModificationCoordinator(
          repository: repo,
          worldModel: WorldModelCoordinator(),
          activity: ActivityRepository(),
        );

        final stopwatch = Stopwatch()..start();
        var current = before;
        for (var i = 0; i < 50; i++) {
          final next = _package(
            version: '${i + 2}',
            screens: [InterfaceScreen(id: 's1', title: 'Home $i')],
          );
          final plan = _planFor(
            experienceId: 'exp-1',
            before: current,
            after: next,
          );
          final applied =
              await coordinator.applyEvolutionPlan(plan)
                  as ModificationCoordinatorSucceeded;
          await coordinator.rollback(
            experienceId: 'exp-1',
            previousPackage: applied.previousPackage!,
          );
          current = before; // rolled back each time — package should stay at v1
        }
        stopwatch.stop();

        final finalPackage = await repo.getPackage('exp-1');
        expect(
          finalPackage?.manifest.version,
          '1',
          reason:
              '50 apply+rollback cycles must leave the package exactly where it started',
        );
        // ignore: avoid_print
        print(
          '50x (applyEvolutionPlan + rollback): ${stopwatch.elapsedMilliseconds}ms',
        );
        await repo.close();
      },
    );
  });
}
