/// Implementation Specification IS-R25 — Universal Solution Orchestrator,
/// Full-Stack Execution Orchestration. Proves the real gap this
/// specification closes: `SolutionExecutionPlanner` (R18) already
/// produces a real `ExecutionStrategy` — target/dependencies/
/// executionOrder/requiredGenerators/validationRequirements — but
/// deliberately never executes it. `SolutionExecutionOrchestrator` is the
/// missing caller: it walks the strategy in real topological levels and
/// dispatches through the EXISTING, UNMODIFIED `runCompilerPipeline`
/// (R19) / `IncrementalCompilerSynthesizer` (R24), validated through the
/// EXISTING, UNMODIFIED `ExperiencePackageValidator` — never a second
/// Compiler/Planner/Runtime/Generator Framework/Build Graph/AI Boundary.
/// Of R18's 12 execution targets, only Runtime Experience ever reaches
/// `applicableWithGenerator` today, so real production strategies only
/// ever produce ONE actionable stage; the level/parallel-partitioning
/// algorithm is proven correct on synthetic multi-target fixtures instead
/// (mirroring `BuildGraphOrderer`'s own R11 precedent).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/engineering_intelligence/affected_entities.dart';
import 'package:anything/execution_planning/execution_strategy.dart';
import 'package:anything/execution_planning/solution_execution_planner.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/solution_architecture/solution_architecture.dart';
import 'package:anything/solution_architecture/solution_architecture_planner.dart';
import 'package:anything/solution_orchestration/execution_ordering.dart';
import 'package:anything/solution_orchestration/orchestration_result.dart';
import 'package:anything/solution_orchestration/solution_execution_orchestrator.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures (mirroring test/r18_solution_execution_planner_test.dart's
// established "Field Trip Log" shape, and R19/R24's real-Kernel helper
// shape). ───────────────────────────────────────────────────────────────

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

NavigationGraph _nav() => NavigationGraph(
  entryScreenId: 'trips',
  screenIds: const ['trips'],
  edges: const [],
  decision: _decision('nav'),
);

SemanticApp _tripApp() => const SemanticApp(
  name: 'Field Trip Log',
  purpose: 'Track field trips',
  entities: [
    SemanticEntity(
      id: 'trip',
      name: 'Trip',
      displayField: 'title',
      fields: [
        SemanticField(
          id: 'title',
          name: 'Title',
          type: BlueprintFieldType.text,
          required: true,
        ),
      ],
    ),
  ],
  requiredCapabilities: ['storage'],
);

ArchitectureCandidate _tripArchitecture({bool backendNeeded = false}) =>
    ArchitectureCandidate(
      id: 'trip-candidate',
      appName: 'Field Trip Log',
      entities: [
        EntityDecision(
          entityId: 'trip',
          name: 'Trip',
          fieldCount: 1,
          storage: StorageKind.sqlite,
          storageDecision: ArchitectureDecision(
            id: 's1',
            category: ArchitectureDecisionCategory.data,
            subjectId: 'trip',
            decision: 'sqlite',
            rationale: 'r',
            confidence: const Confidence(score: 1.0, reason: 'test'),
          ),
        ),
      ],
      relationships: const [],
      navigation: _nav(),
      interactions: [
        InteractionDecision(
          entityId: 'trip',
          canCreate: true,
          canRead: true,
          canUpdate: true,
          canDelete: true,
          supportsSearch: backendNeeded,
          supportsFilter: false,
          supportsSort: false,
          supportsPagination: false,
          decision: _decision('i1'),
        ),
      ],
      security: SecurityDecision(
        networkMode: backendNeeded
            ? NetworkMode.restrictedHttps
            : NetworkMode.none,
        requiresCredentialVault: backendNeeded,
        decision: _decision('sec'),
      ),
      offline: OfflineDecision(
        capability: backendNeeded
            ? OfflineCapability.onlineRequired
            : OfflineCapability.fullyOffline,
        decision: _decision('off'),
      ),
      synchronization: SynchronizationDecision(
        strategy: SyncStrategy.none,
        decision: _decision('sync'),
      ),
      overallConfidence: const Confidence(score: 1.0, reason: 'test'),
    );

BackendEngineeringPlan _tripBackend(ArchitectureCandidate architecture) =>
    const BackendEngineeringPlanner().plan(
      BackendEngineeringContext(architecture: architecture, app: _tripApp()),
    );

SemanticSolutionArchitecture _solution({bool backendNeeded = false}) {
  final architecture = _tripArchitecture(backendNeeded: backendNeeded);
  return const SolutionArchitecturePlanner().plan(
    architecture,
    _tripBackend(architecture),
  );
}

/// A real, valid, hand-built `CanonicalImplementationModel` for the SAME
/// 'trip' entity domain — mirrors R13's own `_noteModel()` centerpiece
/// fixture shape exactly (full CRUD operations, one text field).
CanonicalImplementationModel _tripModel() => const CanonicalImplementationModel(
  entities: [
    ImplementationEntity(
      id: 'trip',
      name: 'Trip',
      fields: [
        ImplementationField(
          id: 'title',
          name: 'Title',
          type: ImplementationDataType.text,
          required: true,
        ),
      ],
    ),
  ],
  repositories: [
    ImplementationRepository(
      id: 'trip.repository',
      entityId: 'trip',
      supportedOperations: [
        ImplementationOperationKind.list,
        ImplementationOperationKind.create,
        ImplementationOperationKind.update,
        ImplementationOperationKind.delete,
        ImplementationOperationKind.get,
      ],
    ),
  ],
  controllers: [
    ImplementationController(
      id: 'trip.controller',
      entityId: 'trip',
      operations: [
        ImplementationOperation(
          id: 'trip.list',
          kind: ImplementationOperationKind.list,
        ),
        ImplementationOperation(
          id: 'trip.create',
          kind: ImplementationOperationKind.create,
          requestFieldNames: ['title'],
        ),
        ImplementationOperation(
          id: 'trip.update',
          kind: ImplementationOperationKind.update,
          requestFieldNames: ['title'],
        ),
        ImplementationOperation(
          id: 'trip.delete',
          kind: ImplementationOperationKind.delete,
        ),
        ImplementationOperation(
          id: 'trip.get',
          kind: ImplementationOperationKind.get,
        ),
      ],
    ),
  ],
  authentication: AuthenticationAdapterSpec(requiresCredentials: false),
  backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
);

/// Synthetic multi-target `ExecutionStrategy` — hand-built dependency
/// edges among R18's 12 real `ExecutionTargetKind` values, independent of
/// what `SolutionExecutionPlanner` would ever really produce (matching
/// `BuildGraphOrderer`'s own R11 precedent: an arbitrary-but-valid graph
/// proves the ALGORITHM, not real production data).
ExecutionStrategy _syntheticStrategy({
  required List<ExecutionTargetPlan> targets,
}) => ExecutionStrategy(targets: targets);

ExecutionTargetPlan _applicable(
  ExecutionTargetKind target, {
  List<ExecutionTargetKind> deps = const [],
  bool hasGenerator = false,
}) => ExecutionTargetPlan(
  target: target,
  classification: hasGenerator
      ? ExecutionTargetClassification.applicableWithGenerator
      : ExecutionTargetClassification.applicableNoGenerator,
  reason: 'synthetic',
  dependencies: deps,
  requiredGenerators: hasGenerator
      ? const ['reference.runtime-experience']
      : const [],
);

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 'Local storage',
      category: CapabilityCategory.storage,
      inputContract: 'data',
      outputContract: 'stored data',
    ),
  );
  return registry;
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  @override
  ModelProvider? get activeProvider => null;
  @override
  List<ModelProvider> get providers => const [];
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String providerId) async {}
  @override
  ModelProvider? getProvider(String providerId) => null;
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

class _FixedReasoner implements ApplicationReasoner {
  final SemanticApp app;
  const _FixedReasoner(this.app);
  @override
  Future<AppReasoningResult> reason(
    ApplicationReasoningContext context,
  ) async => ReasoningReady(semanticApp: app);
}

Future<ExecutionPlanReady> _runKernel() async {
  final kernel = AnythingKernel(
    providerRegistry: _FakeProviderRegistry(),
    capabilityRegistry: _registryWithStorage(),
    reasoner: _FixedReasoner(_tripApp()),
  );
  final outcome = await kernel.processIntent(
    Intent.create(expression: 'track my field trips'),
  );
  expect(outcome, isA<ExecutionPlanReady>());
  return outcome as ExecutionPlanReady;
}

void main() {
  group(
    'ExecutionTargetOrderer (R25) — real level-partitioning, synthetic multi-target fixtures',
    () {
      test(
        'two independent targets with no dependency between them land in the SAME level',
        () {
          final strategy = _syntheticStrategy(
            targets: [
              _applicable(ExecutionTargetKind.backendService),
              _applicable(ExecutionTargetKind.restApi),
            ],
          );
          final levels = const ExecutionTargetOrderer().order(strategy);
          expect(levels.isComplete, isTrue);
          expect(levels.levels, hasLength(1));
          expect(
            levels.levels.single,
            unorderedEquals([
              ExecutionTargetKind.backendService,
              ExecutionTargetKind.restApi,
            ]),
          );
        },
      );

      test(
        'a real dependency chain (A -> B -> C) produces 3 real, ordered levels',
        () {
          final strategy = _syntheticStrategy(
            targets: [
              _applicable(ExecutionTargetKind.backendService),
              _applicable(
                ExecutionTargetKind.restApi,
                deps: [ExecutionTargetKind.backendService],
              ),
              _applicable(
                ExecutionTargetKind.runtimeExperience,
                deps: [ExecutionTargetKind.restApi],
                hasGenerator: true,
              ),
            ],
          );
          final levels = const ExecutionTargetOrderer().order(strategy);
          expect(levels.isComplete, isTrue);
          expect(levels.levels, [
            [ExecutionTargetKind.backendService],
            [ExecutionTargetKind.restApi],
            [ExecutionTargetKind.runtimeExperience],
          ]);
        },
      );

      test(
        'a real dependency cycle is honestly reported as an incomplete order, never silently papered over',
        () {
          final strategy = _syntheticStrategy(
            targets: [
              _applicable(
                ExecutionTargetKind.backendService,
                deps: [ExecutionTargetKind.restApi],
              ),
              _applicable(
                ExecutionTargetKind.restApi,
                deps: [ExecutionTargetKind.backendService],
              ),
            ],
          );
          final levels = const ExecutionTargetOrderer().order(strategy);
          expect(levels.isComplete, isFalse);
          expect(levels.orderedTargets, isEmpty);
        },
      );

      test(
        'a dependency on a target the strategy never marked applicable is ignored, never an unsatisfiable edge',
        () {
          final strategy = _syntheticStrategy(
            targets: [
              _applicable(
                ExecutionTargetKind.runtimeExperience,
                deps: [ExecutionTargetKind.backendService],
                hasGenerator: true,
              ),
            ],
          );
          final levels = const ExecutionTargetOrderer().order(strategy);
          expect(levels.isComplete, isTrue);
          expect(levels.levels, [
            [ExecutionTargetKind.runtimeExperience],
          ]);
        },
      );

      test('notApplicable targets never participate in ordering', () {
        final strategy = _syntheticStrategy(
          targets: [
            const ExecutionTargetPlan(
              target: ExecutionTargetKind.website,
              classification: ExecutionTargetClassification.notApplicable,
              reason: 'no signal',
            ),
            _applicable(
              ExecutionTargetKind.runtimeExperience,
              hasGenerator: true,
            ),
          ],
        );
        final levels = const ExecutionTargetOrderer().order(strategy);
        expect(levels.orderedTargets, [ExecutionTargetKind.runtimeExperience]);
      });
    },
  );

  group(
    'SolutionExecutionOrchestrator (R25 centerpiece) — real dispatch through the unmodified compiler pipeline',
    () {
      test(
        'a real ExecutionStrategy + real CanonicalImplementationModel: Runtime Experience succeeds, meets real completion criteria',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );

          expect(report.levelOrderingComplete, isTrue);
          final runtimeOutcome = report.outcomeFor(
            ExecutionTargetKind.runtimeExperience,
          )!;
          expect(runtimeOutcome.status, StageStatus.succeeded);
          expect(runtimeOutcome.completionCriteriaMet, isTrue);
          expect(runtimeOutcome.attempts, 1);
          expect(runtimeOutcome.package, isNotNull);
          expect(
            ExperiencePackageValidator.validate(
              runtimeOutcome.package!,
            ).isValid,
            isTrue,
          );
        },
      );

      test(
        'notApplicable targets are recorded with a real, specific reason, never silently dropped — and no real target is applicableNoGenerator anymore (Implementation Specification IS-R27)',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(
            _solution(backendNeeded: true),
          );
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
            backendPlan: _solution(backendNeeded: true).backend,
          );

          expect(
            report.stages,
            hasLength(12),
            reason:
                'every one of the 12 R18 execution targets must appear exactly once',
          );
          final website = report.outcomeFor(ExecutionTargetKind.website)!;
          expect(website.status, StageStatus.skippedNotApplicable);
          expect(website.errors, isNotEmpty);

          // REALITY (Implementation Specification IS-R27): BackendServiceGenerator
          // (R26) and RestApiGenerator (R27) together mean every one of the 3
          // backend-shaped targets `SolutionExecutionPlanner` (R18) can ever
          // mark applicable now has a real generator — `skippedNoGenerator`
          // is no longer reachable anywhere in this fixture. This is a real,
          // structural fact worth asserting explicitly, not silently losing
          // as prior milestones' own dedicated examples (this test's own R18/
          // R26 history) get superseded.
          expect(
            report.stages.where(
              (s) => s.status == StageStatus.skippedNoGenerator,
            ),
            isEmpty,
          );
        },
      );

      test(
        'supplying real, matching AffectedEntities dispatches through IncrementalCompilerSynthesizer, still producing a valid package',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
            affected: const AffectedEntities({'trip'}),
          );
          final outcome = report.outcomeFor(
            ExecutionTargetKind.runtimeExperience,
          )!;
          expect(outcome.status, StageStatus.succeeded);
          expect(outcome.package!.data!.entities.single.id, 'trip');
        },
      );

      test(
        'AffectedEntities matching NO real entity produces an honest, deterministic no-package failure, retried the documented number of times, never an infinite loop',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
            affected: const AffectedEntities({'nonexistent-entity'}),
            maxAttempts: 3,
          );
          final outcome = report.outcomeFor(
            ExecutionTargetKind.runtimeExperience,
          )!;
          expect(outcome.status, StageStatus.failed);
          expect(
            outcome.attempts,
            3,
            reason:
                'a deterministic failure is retried exactly maxAttempts times, then reported — never fewer, never infinite',
          );
          expect(outcome.errors, isNotEmpty);
          expect(report.succeeded, isFalse);
          expect(
            report.failedStages.single.target,
            ExecutionTargetKind.runtimeExperience,
          );
        },
      );

      test(
        'maxAttempts defaults to 1 (no retry) when a caller does not specify one',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
            affected: const AffectedEntities({'nonexistent-entity'}),
          );
          expect(
            report.outcomeFor(ExecutionTargetKind.runtimeExperience)!.attempts,
            1,
          );
        },
      );

      test(
        'a real Kernel run\'s own ExecutionStrategy and CanonicalImplementationModel — the SAME real request\'s two coexisting outputs (R18/R9) — compose end-to-end through the orchestrator',
        () async {
          TestWidgetsFlutterBinding.ensureInitialized();
          final ready = await _runKernel();
          final strategy = ready.executionStrategy!;
          final model = ready.canonicalImplementationModel!;

          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: model,
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );
          expect(
            report.outcomeFor(ExecutionTargetKind.runtimeExperience)!.status,
            StageStatus.succeeded,
          );
        },
      );
    },
  );

  group(
    'Rollback (R25) — reuses the real, existing ExperienceModificationCoordinator.rollback() unmodified, never reimplemented',
    () {
      setUp(() async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
      });

      test(
        'an orchestration failure on a modification request, applied by a real caller, correctly triggers rollback() and restores the prior package',
        () async {
          final dbName =
              'r25_rollback_${DateTime.now().microsecondsSinceEpoch}.db';
          final repository = SqliteExperienceRepository(dbName: dbName);
          final coordinator = ExperienceModificationCoordinator(
            repository: repository,
          );

          // Seed a real, prior experience package directly (mirrors R6's own
          // established rollback test seeding pattern).
          final priorPackage = const SolutionExecutionOrchestrator();
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final seedReport = await priorPackage.execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-experience',
            name: 'Trip Tracker',
          );
          final seededPackage = seedReport
              .outcomeFor(ExecutionTargetKind.runtimeExperience)!
              .package!;
          await repository.savePackage(seededPackage);
          await repository.saveMetadata(
            ExperienceMetadataRecord(
              id: 'trip-experience',
              name: seededPackage.manifest.name,
              description: seededPackage.manifest.description,
              category: seededPackage.manifest.category,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          // A real, deterministic orchestration failure (matching this file's
          // own "AffectedEntities matching nothing" case above) simulates a
          // failed modification attempt — the caller (never the orchestrator
          // itself, see solution_execution_orchestrator.dart's own layering
          // doc comment) decides to roll back using the ALREADY-SAVED prior
          // package.
          final failedReport = await priorPackage.execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-experience',
            name: 'Trip Tracker',
            affected: const AffectedEntities({'nonexistent-entity'}),
          );
          expect(failedReport.succeeded, isFalse);

          final rollbackResult = await coordinator.rollback(
            experienceId: 'trip-experience',
            previousPackage: seededPackage,
          );
          expect(rollbackResult, isA<ModificationCoordinatorSucceeded>());
          final restored = await repository.getPackage('trip-experience');
          expect(
            restored!.manifest.experienceId,
            seededPackage.manifest.experienceId,
          );

          await repository.close();
        },
      );
    },
  );

  group(
    'Performance (R25) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('level-ordering latency for a large synthetic 12-target chain', () {
        final targets = ExecutionTargetKind.values;
        final chain = [
          for (var i = 0; i < targets.length; i++)
            _applicable(
              targets[i],
              deps: i == 0 ? const [] : [targets[i - 1]],
              hasGenerator: targets[i] == ExecutionTargetKind.runtimeExperience,
            ),
        ];
        final strategy = _syntheticStrategy(targets: chain);

        final stopwatch = Stopwatch()..start();
        for (var i = 0; i < 500; i++) {
          const ExecutionTargetOrderer().order(strategy);
        }
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'R25 level-ordering: 500 runs over a ${targets.length}-target chain in ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test(
        'real orchestration execution latency for the one real generator path',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final model = _tripModel();

          final stopwatch = Stopwatch()..start();
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: model,
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );
          stopwatch.stop();

          expect(
            report.outcomeFor(ExecutionTargetKind.runtimeExperience)!.status,
            StageStatus.succeeded,
          );
          // ignore: avoid_print
          print(
            'R25 orchestration execution: ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test(
        'memory: real process RSS delta while orchestrating 100 real executions',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final model = _tripModel();
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 100; i++) {
            await const SolutionExecutionOrchestrator().execute(
              strategy: strategy,
              model: model,
              id: 'trip-tracker-$i',
              name: 'Trip Tracker',
            );
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R25 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 100 orchestration runs',
          );
        },
      );
    },
  );
}
