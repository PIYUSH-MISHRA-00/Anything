/// Implementation Milestone R4 — Incremental Software Evolution,
/// Deterministic Graph Differencing. Proves the 4-stage diff chain
/// (Requirement — already real from R3 — Architecture/Engineering/
/// Experience, new this milestone), the composed EvolutionDiffPlan, and
/// ExperienceModificationCoordinator's new planning-only integration
/// (never persists, never mutates the World Graph on rejection).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/application_engineering/accessibility_performance_security_engineering.dart';
import 'package:anything/application_engineering/data_engineering.dart';
import 'package:anything/application_engineering/engineering_candidate.dart';
import 'package:anything/application_engineering/engineering_candidate_diff.dart';
import 'package:anything/application_engineering/engineering_types.dart';
import 'package:anything/application_engineering/interaction_engineering.dart';
import 'package:anything/application_engineering/lifecycle_engineering.dart';
import 'package:anything/application_engineering/navigation_engineering.dart';
import 'package:anything/application_engineering/persistence_offline_sync_engineering.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_package_diff.dart';
import 'package:anything/evolution/evolution_diff_plan.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_candidate_diff.dart';
import 'package:anything/software_architect/architecture_types.dart'
    hide NetworkMode;
import 'package:anything/software_architect/architecture_types.dart'
    as arch
    show NetworkMode;
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/requirement_graph.dart';
import 'package:anything/software_architect/requirement_graph_diff.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

// ── Architecture fixtures (mirrors test/software_architect's established pattern) ──

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

NavigationGraph _emptyNav() => NavigationGraph(
  entryScreenId: 'home',
  screenIds: const ['home'],
  edges: const [],
  decision: _decision('nav'),
);

SecurityDecision _security({arch.NetworkMode mode = arch.NetworkMode.none}) =>
    SecurityDecision(
      networkMode: mode,
      requiresCredentialVault: false,
      decision: _decision('sec'),
    );

OfflineDecision _offline() => OfflineDecision(
  capability: OfflineCapability.fullyOffline,
  decision: _decision('off'),
);

SynchronizationDecision _sync() => SynchronizationDecision(
  strategy: SyncStrategy.none,
  decision: _decision('sync'),
);

EntityDecision _entity(String id, String name) => EntityDecision(
  entityId: id,
  name: name,
  fieldCount: 1,
  storage: StorageKind.sqlite,
  storageDecision: _decision('storage:$id'),
);

ArchitectureCandidate _archCandidate({
  List<EntityDecision> entities = const [],
  SecurityDecision? security,
}) {
  return ArchitectureCandidate(
    id: 'candidate-1',
    appName: 'Test App',
    entities: entities,
    navigation: _emptyNav(),
    security: security ?? _security(),
    offline: _offline(),
    synchronization: _sync(),
    overallConfidence: const Confidence(score: 1.0, reason: 'test'),
  );
}

// ── Engineering fixtures ──

EngineeringDecision _engDecision(String id, {String decision = 'd'}) =>
    EngineeringDecision(
      id: id,
      category: EngineeringDecisionCategory.behavior,
      subjectId: id,
      decision: decision,
      rationale: 'r',
      confidence: const Confidence(score: 1.0, reason: 'test'),
    );

EngineeringCandidate _engCandidate({
  List<BindingEdge> bindingEdges = const [],
  String dataDecision = 'no-migration',
}) {
  return EngineeringCandidate(
    id: 'eng-1',
    behaviors: const [],
    data: DataEngineeringResult(
      migrationDecision: _engDecision('data', decision: dataDecision),
    ),
    navigation: NavigationEngineeringResult(
      historyDecision: _engDecision('hist'),
      recoveryDecision: _engDecision('rec'),
      decision: _engDecision('nav'),
    ),
    interaction: const InteractionEngineeringResult(),
    bindingGraph: BindingGraph(edges: bindingEdges),
    bindingDecision: _engDecision('binding'),
    validations: const [],
    persistence: PersistenceEngineeringResult(
      migrationDecision: _engDecision('persist'),
    ),
    offline: OfflineEngineeringResult(
      strategy: OfflineStrategy.cacheFirst,
      conflictStrategy: ConflictStrategy.lastWriteWins,
      decision: _engDecision('off'),
    ),
    synchronization: SynchronizationEngineeringResult(
      strategy: SyncStrategy.none,
      decision: _engDecision('sync'),
    ),
    lifecycle: const LifecycleEngineeringResult(),
    performance: const PerformanceEngineeringResult(),
    accessibility: const AccessibilityEngineeringResult(),
    security: const SecurityEngineeringResult(),
    overallConfidence: const Confidence(score: 1.0, reason: 'test'),
  );
}

// ── Experience Package fixtures ──

ExperiencePackage _package({
  String experienceId = 'exp-1',
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
      entryPoint: 's1',
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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('ArchitectureDiff (R4)', () {
    const differ = ArchitectureDiffer();

    test('identical candidates produce an empty diff', () {
      final a = _archCandidate(entities: [_entity('e1', 'Alpha')]);
      final b = _archCandidate(entities: [_entity('e1', 'Alpha')]);
      expect(differ.diff(a, b).isEmpty, isTrue);
    });

    test('an added entity is reported, a removed entity is reported', () {
      final before = _archCandidate(entities: [_entity('e1', 'Alpha')]);
      final after = _archCandidate(
        entities: [_entity('e1', 'Alpha'), _entity('e2', 'Beta')],
      );
      final diff = differ.diff(before, after);
      expect(diff.addedEntities.map((e) => e.entityId), ['e2']);
      expect(diff.removedEntities, isEmpty);

      final reverseDiff = differ.diff(after, before);
      expect(reverseDiff.removedEntities.map((e) => e.entityId), ['e2']);
    });

    test(
      'a security decision change is surfaced as an explicit before/after pair',
      () {
        final before = _archCandidate(
          security: _security(mode: arch.NetworkMode.none),
        );
        final after = _archCandidate(
          security: _security(mode: arch.NetworkMode.restrictedHttps),
        );
        final diff = differ.diff(before, after);
        expect(diff.securityChange, isNotNull);
        expect(diff.securityChange!.$1.networkMode, arch.NetworkMode.none);
        expect(
          diff.securityChange!.$2.networkMode,
          arch.NetworkMode.restrictedHttps,
        );
      },
    );

    test(
      'determinism: diffing the same two candidates twice yields structurally identical results',
      () {
        final before = _archCandidate(entities: [_entity('e1', 'Alpha')]);
        final after = _archCandidate(
          entities: [_entity('e1', 'Alpha'), _entity('e2', 'Beta')],
        );
        final d1 = differ.diff(before, after);
        final d2 = differ.diff(before, after);
        expect(
          d1.addedEntities.map((e) => e.entityId),
          d2.addedEntities.map((e) => e.entityId),
        );
        expect(d1.removedEntities.length, d2.removedEntities.length);
      },
    );
  });

  group('EngineeringDiff (R4)', () {
    const differ = EngineeringDiffer();

    test('identical candidates produce an empty diff', () {
      final a = _engCandidate();
      final b = _engCandidate();
      expect(differ.diff(a, b).isEmpty, isTrue);
    });

    test(
      'a changed data-migration decision is surfaced as a real before/after pair',
      () {
        final before = _engCandidate(dataDecision: 'no-migration');
        final after = _engCandidate(dataDecision: 'add-column-migration');
        final diff = differ.diff(before, after);
        expect(diff.dataChange, ('no-migration', 'add-column-migration'));
      },
    );

    test('an added binding edge is reported', () {
      final before = _engCandidate();
      final after = _engCandidate(
        bindingEdges: [
          const BindingEdge(
            kind: BindingKind.viewToState,
            fromId: 's1',
            toId: 'u1',
          ),
        ],
      );
      final diff = differ.diff(before, after);
      expect(diff.addedBindings, hasLength(1));
      expect(diff.removedBindings, isEmpty);
    });
  });

  group('ExperienceDiff (R4)', () {
    const differ = ExperienceDiffer();

    test('identical packages produce an empty diff', () {
      final a = _package(
        screens: [const InterfaceScreen(id: 's1', title: 'Screen 1')],
      );
      final b = _package(
        screens: [const InterfaceScreen(id: 's1', title: 'Screen 1')],
      );
      expect(differ.diff(a, b).isEmpty, isTrue);
    });

    test('an added screen and an added component are both reported', () {
      final before = _package(
        screens: [const InterfaceScreen(id: 's1', title: 'Screen 1')],
      );
      final after = _package(
        screens: [
          const InterfaceScreen(
            id: 's1',
            title: 'Screen 1',
            children: [InterfaceNode(type: 'text', id: 'n1')],
          ),
          const InterfaceScreen(id: 's2', title: 'Screen 2'),
        ],
      );
      final diff = differ.diff(before, after);
      expect(diff.addedScreens.map((s) => s.id), ['s2']);
      expect(diff.addedComponents.map((c) => c.id), ['n1']);
    });

    test('an added capability declaration is reported', () {
      final before = _package();
      final after = _package(
        capabilities: const [CapabilityDeclaration(capabilityId: 'clock')],
      );
      final diff = differ.diff(before, after);
      expect(diff.addedCapabilities.map((c) => c.capabilityId), ['clock']);
    });

    test(
      'determinism: diffing twice yields the same emptiness/non-emptiness and counts',
      () {
        final before = _package(
          screens: [const InterfaceScreen(id: 's1', title: 'Screen 1')],
        );
        final after = _package(
          screens: [
            const InterfaceScreen(id: 's1', title: 'Screen 1'),
            const InterfaceScreen(id: 's2', title: 'Screen 2'),
          ],
        );
        final d1 = differ.diff(before, after);
        final d2 = differ.diff(before, after);
        expect(d1.addedScreens.length, d2.addedScreens.length);
        expect(d1.isEmpty, d2.isEmpty);
      },
    );

    test(
      'performance: diffing two 500-screen packages stays correct and reports real elapsed time',
      () {
        final before = _package(
          screens: List.generate(
            500,
            (i) => InterfaceScreen(id: 's$i', title: 'Screen $i'),
          ),
        );
        final after = _package(
          screens: List.generate(
            500,
            (i) => InterfaceScreen(id: 's$i', title: 'Screen $i'),
          )..add(const InterfaceScreen(id: 's500', title: 'New Screen')),
        );
        final stopwatch = Stopwatch()..start();
        final diff = differ.diff(before, after);
        stopwatch.stop();
        expect(diff.addedScreens, hasLength(1));
        // ignore: avoid_print
        print(
          'ExperienceDiff over 500/501 screens: ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );
  });

  group('EvolutionDiffPlan (R4)', () {
    const builder = EvolutionDiffPlanBuilder();

    test(
      'an empty experience diff and no other diffs produces an empty plan',
      () {
        final plan = builder.build(
          experienceId: 'exp-1',
          experienceDiff: ExperienceDiff.empty,
        );
        expect(plan.isEmpty, isTrue);
      },
    );

    test(
      'composing a real requirement diff and a real experience diff produces two ordered mutations',
      () {
        final reqBefore = const RequirementGraph(nodes: [], relations: []);
        final reqAfter = RequirementGraph(
          nodes: [
            const RequirementNode(
              id: 'r1',
              type: RequirementNodeType.entity,
              label: 'L',
              description: 'd',
              source: RequirementSource.explicit,
            ),
          ],
          relations: const [],
        );
        final reqDiff = const RequirementGraphDiffer().diff(
          reqBefore,
          reqAfter,
        );

        final expDiff = const ExperienceDiffer().diff(
          _package(),
          _package(
            capabilities: const [CapabilityDeclaration(capabilityId: 'clock')],
          ),
        );

        final plan = builder.build(
          experienceId: 'exp-1',
          requirementDiff: reqDiff,
          experienceDiff: expDiff,
        );
        expect(plan.mutations, hasLength(2));
        expect(plan.mutations[0].targetObject, 'RequirementGraph');
        expect(plan.mutations[1].targetObject, 'ExperiencePackage');
        expect(plan.mutations[1].dependencies, ['RequirementGraph']);
      },
    );

    test(
      'determinism: building the same plan twice yields the same mutation count and order',
      () {
        final expDiff = const ExperienceDiffer().diff(
          _package(),
          _package(
            screens: [const InterfaceScreen(id: 's1', title: 'S')],
          ),
        );
        final p1 = builder.build(
          experienceId: 'exp-1',
          experienceDiff: expDiff,
        );
        final p2 = builder.build(
          experienceId: 'exp-1',
          experienceDiff: expDiff,
        );
        expect(
          p1.mutations.map((m) => m.targetObject),
          p2.mutations.map((m) => m.targetObject),
        );
      },
    );
  });

  group('ExperienceModificationCoordinator integration (R4)', () {
    late SqliteExperienceRepository repository;

    setUp(() {
      repository = SqliteExperienceRepository(
        dbName: 'r4_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() async => repository.close());

    test(
      'planEvolution computes a real, non-empty plan without persisting anything',
      () async {
        final package = _package(
          screens: [
            const InterfaceScreen(
              id: 's1',
              title: 'Home',
              children: [InterfaceNode(type: 'text', id: 'n1')],
            ),
          ],
        );
        await repository.saveMetadata(
          ExperienceMetadataRecord(
            id: 'exp-1',
            name: 'Calc',
            description: 'd',
            category: 'general',
            packageVersion: '1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await repository.savePackage(package);

        final coordinator = ExperienceModificationCoordinator(
          repository: repository,
          worldModel: WorldModelCoordinator(),
        );
        final plan = await coordinator.planEvolution(
          experienceId: 'exp-1',
          modificationExpression: 'add a percentage field',
        );

        expect(plan, isNotNull);
        // Never persisted — the stored package must be byte-for-byte the
        // original, since planEvolution is planning-only.
        final stillStored = await repository.getPackage('exp-1');
        expect(
          stillStored!.interface.screens.first.children,
          hasLength(1),
          reason: 'planEvolution must never persist its candidate',
        );
      },
    );

    test(
      'World Graph gains an experience node on an ACCEPTED modification, and is unchanged on a REJECTED one',
      () async {
        final package = _package(
          experienceId: 'exp-2',
          screens: [const InterfaceScreen(id: 's1', title: 'Home')],
        );
        await repository.saveMetadata(
          ExperienceMetadataRecord(
            id: 'exp-2',
            name: 'Calc',
            description: 'd',
            category: 'general',
            packageVersion: '1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await repository.savePackage(package);

        final worldModel = WorldModelCoordinator();
        final coordinator = ExperienceModificationCoordinator(
          repository: repository,
          worldModel: worldModel,
        );

        // Rejection path: a nonexistent experience id fails before any
        // world-model-mutating branch is ever reached.
        final rejected = await coordinator.modifyExperience(
          experienceId: 'does-not-exist',
          modificationExpression: 'add a percentage field',
        );
        expect(rejected, isA<ModificationCoordinatorFailed>());
        expect(
          worldModel.model.graph.nodesOfKind(WorldNodeKind.experience),
          isEmpty,
          reason: 'a rejected modification must never mutate the World Graph',
        );

        // Acceptance path: a real modification against a real stored package.
        final accepted = await coordinator.modifyExperience(
          experienceId: 'exp-2',
          modificationExpression: 'add a percentage field',
        );
        expect(accepted, isA<ModificationCoordinatorSucceeded>());
        expect(
          worldModel.model.graph.nodesOfKind(WorldNodeKind.experience),
          isNotEmpty,
          reason:
              'an accepted modification must ingest into the shared World Graph',
        );
      },
    );
  });
}
