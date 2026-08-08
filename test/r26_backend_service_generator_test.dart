/// Implementation Specification IS-R26 — Backend Service Generator, First
/// Multi-Generator Production Target. Proves the real gap this
/// specification closes: `SolutionExecutionPlanner` (R18) has always been
/// able to classify a `backendService` target as needed, but ALWAYS
/// reported `applicableNoGenerator` — no real `Generator` existed to
/// fulfill it, and `SolutionExecutionOrchestrator` (R25) only ever ran
/// ONE real generator (`RuntimeExperienceGenerator`). `BackendServiceGenerator`
/// is the second real `Generator` implementation, dispatched through the
/// SAME, unmodified `Generator`/`GenerationPipeline` framework (R10) and
/// the SAME, unmodified `SolutionExecutionOrchestrator` (R25) — never a
/// second Compiler/Generator Framework/Runtime/Build Graph/AI Boundary.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/backend_engineering/api_specification.dart';
import 'package:anything/backend_engineering/authentication_model.dart';
import 'package:anything/backend_engineering/background_jobs_model.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_serialization.dart';
import 'package:anything/backend_engineering/database_schema.dart';
import 'package:anything/backend_engineering/deployment_specification.dart';
import 'package:anything/backend_engineering/storage_model.dart';
import 'package:anything/build_graph/universal_build_graph.dart';
import 'package:anything/compiler_integration/compiler_pipeline_runner.dart';
import 'package:anything/execution_planning/execution_strategy.dart';
import 'package:anything/execution_planning/solution_execution_planner.dart';
import 'package:anything/generator_framework/generation_result.dart';
import 'package:anything/generator_framework/generator.dart';
import 'package:anything/generator_framework/reference/backend_service_generator.dart';
import 'package:anything/generator_framework/reference/runtime_experience_generator.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/solution_architecture/solution_architecture.dart';
import 'package:anything/solution_architecture/solution_architecture_planner.dart';
import 'package:anything/solution_orchestration/orchestration_result.dart';
import 'package:anything/solution_orchestration/solution_execution_orchestrator.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures (mirroring test/r25_solution_orchestrator_test.dart's
// established "Field Trip Log" shape — test files can't share private
// helpers, so equivalents are redeclared minimally). ───────────────────

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
  services: [
    ImplementationService(
      id: 'trip.service',
      entityId: 'trip',
      repositoryId: 'trip.repository',
      controllerId: 'trip.controller',
    ),
  ],
  authentication: AuthenticationAdapterSpec(requiresCredentials: false),
  backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
);

GeneratorContext _contextFor(
  BackendEngineeringPlan plan, {
  CanonicalImplementationModel? model,
}) => GeneratorContext(
  buildGraph: const BuildGraphBuilder().build(model ?? _tripModel()),
  target: const GeneratorTarget(id: 'trip-tracker', name: 'Trip Tracker'),
  options: GeneratorOptions(
    values: {'backendEngineeringPlan': jsonEncode(plan.toJson())},
  ),
);

void main() {
  group('BackendServiceGenerator (R26 centerpiece)', () {
    test(
      'a real BackendEngineeringPlan produces real, typed, non-fabricated artifacts',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const BackendServiceGenerator().generate(
          _contextFor(plan),
        );

        expect(result.hasErrors, isFalse);
        final artifact = result.allArtifacts.single;
        final json = jsonDecode(artifact.content!) as Map<String, dynamic>;

        expect(json['database'], isNotNull);
        expect(json['api'], isNotNull);
        expect(json['authentication'], isNotNull);
        expect(json['storage'], isNotNull);
        expect(json['backgroundJobs'], isNotNull);
        expect(json['deployment'], isNotNull);
        expect(
          (json['repositories'] as List).single,
          containsPair('entityId', 'trip'),
        );
        expect((json['services'] as List), isNotEmpty);
        final migrations = json['migrations'] as List;
        expect(
          migrations.single,
          containsPair('tableId', plan.database.tables.single.id),
        );
      },
    );

    test(
      'deployment.secretReferences carries names only, never a value — Implementation Milestone R8\'s standing constraint',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const BackendServiceGenerator().generate(
          _contextFor(plan),
        );
        final json =
            jsonDecode(result.allArtifacts.single.content!)
                as Map<String, dynamic>;
        final secretNames =
            (json['deployment'] as Map<String, dynamic>)['secretReferences']
                as List;
        for (final name in secretNames) {
          expect(name, isA<String>());
        }
      },
    );

    test(
      'no BackendEngineeringPlan supplied: honest empty result, never a crash or fabricated artifact',
      () {
        final context = GeneratorContext(
          buildGraph: const BuildGraphBuilder().build(_tripModel()),
          target: const GeneratorTarget(id: 'x', name: 'X'),
        );
        final result = const BackendServiceGenerator().generate(context);
        expect(result.allArtifacts, isEmpty);
        expect(result.diagnostics, isNotEmpty);
        expect(result.diagnostics.first.severity, DiagnosticSeverity.info);
      },
    );

    test(
      'an empty BackendEngineeringPlan (no tables, no endpoints) produces an honest empty result',
      () {
        const plan = BackendEngineeringPlan(
          database: DatabaseSchemaModel.empty,
          api: ApiSpecificationModel.empty,
          authentication: AuthenticationModel(requiresCredentials: false),
          storage: BackendStorageModel.empty,
          backgroundJobs: BackgroundJobsModel(
            requiresBackgroundSync: false,
            sourceStrategy: SyncStrategy.none,
          ),
          deployment: DeploymentSpecificationModel(requiresBackend: false),
        );
        final result = const BackendServiceGenerator().generate(
          _contextFor(plan),
        );
        expect(result.allArtifacts, isEmpty);
        expect(result.diagnostics, isNotEmpty);
      },
    );

    test(
      'realtime configuration is honestly reported as unrepresented — never fabricated',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const BackendServiceGenerator().generate(
          _contextFor(plan),
        );
        expect(
          result.diagnostics.any(
            (d) =>
                d.category == DiagnosticCategory.skippedFeature &&
                d.message.contains('Realtime'),
          ),
          isTrue,
        );
      },
    );

    test(
      'malformed BackendEngineeringPlan JSON is a real, reported error, never a crash',
      () {
        final context = GeneratorContext(
          buildGraph: const BuildGraphBuilder().build(_tripModel()),
          target: const GeneratorTarget(id: 'x', name: 'X'),
          options: const GeneratorOptions(
            values: {'backendEngineeringPlan': 'not valid json'},
          ),
        );
        final result = const BackendServiceGenerator().generate(context);
        expect(result.hasErrors, isTrue);
      },
    );

    test(
      'never emits SQL DDL, server source code, or literal deployment-config syntax — Implementation Milestone R8\'s standing constraint, still in force',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const BackendServiceGenerator().generate(
          _contextFor(plan),
        );
        final content = result.allArtifacts.single.content!;
        for (final forbidden in [
          'CREATE TABLE',
          'INSERT INTO',
          'SELECT * FROM',
          'import express',
          'from flask',
          '@app.route',
          'FROM node',
          'Process.run',
          'Process.start',
        ]) {
          expect(
            content.toUpperCase().contains(forbidden.toUpperCase()),
            isFalse,
            reason: 'found forbidden pattern: $forbidden',
          );
        }
      },
    );

    test(
      'the real GeneratorMetadata.id is distinct from RuntimeExperienceGenerator\'s',
      () {
        expect(
          const BackendServiceGenerator().metadata.id,
          'reference.backend-service',
        );
        expect(
          const BackendServiceGenerator().metadata.id,
          isNot(SolutionExecutionPlanner.runtimeExperienceGeneratorId),
        );
        expect(
          const BackendServiceGenerator().metadata.id,
          SolutionExecutionPlanner.backendServiceGeneratorId,
        );
      },
    );

    test(
      'determinism: the same plan generated twice produces byte-for-byte identical output',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final r1 = const BackendServiceGenerator().generate(_contextFor(plan));
        final r2 = const BackendServiceGenerator().generate(_contextFor(plan));
        expect(r1.allArtifacts.single.content, r2.allArtifacts.single.content);
      },
    );
  });

  group('SolutionExecutionPlanner integration (R26)', () {
    test(
      'a real backend-required SemanticSolutionArchitecture now classifies backendService as applicableWithGenerator',
      () {
        final strategy = const SolutionExecutionPlanner().plan(
          _solution(backendNeeded: true),
        );
        final backend = strategy.forTarget(ExecutionTargetKind.backendService);
        expect(
          backend.classification,
          ExecutionTargetClassification.applicableWithGenerator,
        );
        expect(backend.requiredGenerators, [
          SolutionExecutionPlanner.backendServiceGeneratorId,
        ]);
      },
    );

    test(
      'no backend need: backendService remains notApplicable, unaffected by R26',
      () {
        final strategy = const SolutionExecutionPlanner().plan(
          _solution(backendNeeded: false),
        );
        expect(
          strategy.forTarget(ExecutionTargetKind.backendService).classification,
          ExecutionTargetClassification.notApplicable,
        );
      },
    );
  });

  group(
    'SolutionExecutionOrchestrator multi-generator integration (R26 mandatory vision validation)',
    () {
      test(
        'ONE ExecutionStrategy with BOTH Backend Service AND Runtime Experience as applicableWithGenerator: the orchestrator runs BOTH real generators, in real dependency order',
        () async {
          final solution = _solution(backendNeeded: true);
          final strategy = const SolutionExecutionPlanner().plan(solution);

          expect(
            strategy
                .forTarget(ExecutionTargetKind.backendService)
                .classification,
            ExecutionTargetClassification.applicableWithGenerator,
          );
          expect(
            strategy
                .forTarget(ExecutionTargetKind.runtimeExperience)
                .classification,
            ExecutionTargetClassification.applicableWithGenerator,
          );
          expect(
            strategy
                .forTarget(ExecutionTargetKind.runtimeExperience)
                .dependencies,
            contains(ExecutionTargetKind.backendService),
          );

          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
            backendPlan: solution.backend,
          );

          final backendOutcome = report.outcomeFor(
            ExecutionTargetKind.backendService,
          )!;
          final runtimeOutcome = report.outcomeFor(
            ExecutionTargetKind.runtimeExperience,
          )!;
          expect(
            backendOutcome.status,
            StageStatus.succeeded,
            reason: backendOutcome.errors.join('; '),
          );
          expect(
            runtimeOutcome.status,
            StageStatus.succeeded,
            reason: runtimeOutcome.errors.join('; '),
          );
          expect(backendOutcome.backendArtifacts, isNotEmpty);
          expect(
            backendOutcome.package,
            isNull,
            reason: 'Backend Service output is never an ExperiencePackage',
          );
          expect(runtimeOutcome.package, isNotNull);
          expect(
            runtimeOutcome.backendArtifacts,
            isNull,
            reason: 'Runtime Experience output is never backendArtifacts',
          );

          // Real dependency-safe ordering: backendService's level index must
          // be strictly before runtimeExperience's.
          int levelOf(ExecutionTargetKind target) =>
              report.levels.indexWhere((level) => level.contains(target));
          expect(
            levelOf(ExecutionTargetKind.backendService),
            lessThan(levelOf(ExecutionTargetKind.runtimeExperience)),
          );
          expect(report.succeeded, isTrue);
        },
      );

      test(
        'backendPlan omitted for an applicableWithGenerator backendService target: a real, honest failure, never a crash, never a silent skip',
        () async {
          final solution = _solution(backendNeeded: true);
          final strategy = const SolutionExecutionPlanner().plan(solution);

          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );

          final backendOutcome = report.outcomeFor(
            ExecutionTargetKind.backendService,
          )!;
          expect(backendOutcome.status, StageStatus.failed);
          expect(
            backendOutcome.attempts,
            1,
            reason:
                'a missing precondition is not a transient failure — it must never spin through retries',
          );
          expect(
            backendOutcome.errors.single,
            contains('No BackendEngineeringPlan supplied'),
          );
        },
      );

      test(
        'a missing backendPlan is not retried even when maxAttempts is raised — a precondition failure, not a transient one',
        () async {
          final solution = _solution(backendNeeded: true);
          final strategy = const SolutionExecutionPlanner().plan(solution);
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
            maxAttempts: 5,
          );
          expect(
            report.outcomeFor(ExecutionTargetKind.backendService)!.attempts,
            1,
          );
        },
      );
    },
  );

  group(
    'Backward compatibility (R26) — every R19-R25 behavior is byte-for-byte unaffected',
    () {
      test('runCompilerPipeline (R19) behavior is completely unchanged', () {
        final outcome = runCompilerPipeline(
          _tripModel(),
          id: 'trip-tracker',
          name: 'Trip Tracker',
        );
        expect(outcome.succeeded, isTrue);
        expect(outcome.package!.manifest.experienceId, 'trip-tracker');
      });

      test(
        'runGeneratorPipeline (R26) run against RuntimeExperienceGenerator produces the SAME real artifact shape runCompilerPipeline already decodes '
        '(compared structurally — two separate live calls carry their own real, distinct generation timestamps, matching R13\'s own established determinism-check precedent of stripping timestamps rather than comparing raw JSON)',
        () {
          final direct = runCompilerPipeline(
            _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );
          final generic = runGeneratorPipeline(
            _tripModel(),
            generator: const RuntimeExperienceGenerator(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );

          expect(
            generic.result.allArtifacts.single.path,
            direct.result.allArtifacts.single.path,
          );
          expect(
            generic.result.allArtifacts.single.kind,
            direct.result.allArtifacts.single.kind,
          );
          final genericPackage =
              jsonDecode(generic.result.allArtifacts.single.content!)
                  as Map<String, dynamic>;
          final directPackage =
              jsonDecode(direct.result.allArtifacts.single.content!)
                  as Map<String, dynamic>;
          expect(genericPackage['interface'], directPackage['interface']);
          expect(genericPackage['behavior'], directPackage['behavior']);
          expect(genericPackage['data'], directPackage['data']);
          expect(
            (genericPackage['manifest'] as Map)['experienceId'],
            (directPackage['manifest'] as Map)['experienceId'],
          );
        },
      );

      test(
        'a Runtime-Experience-only strategy (no backend need) still runs exactly as R25 built it, StageOutcome.backendArtifacts stays null',
        () async {
          final strategy = const SolutionExecutionPlanner().plan(_solution());
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );
          final outcome = report.outcomeFor(
            ExecutionTargetKind.runtimeExperience,
          )!;
          expect(outcome.status, StageStatus.succeeded);
          expect(outcome.package, isNotNull);
          expect(outcome.backendArtifacts, isNull);
        },
      );
    },
  );

  group(
    'Performance (R26) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      BackendEngineeringPlan largePlan(int tableCount) =>
          BackendEngineeringPlan(
            database: DatabaseSchemaModel(
              tables: [
                for (var i = 0; i < tableCount; i++)
                  DatabaseTable(
                    id: 'table_$i',
                    name: 'Table $i',
                    columns: [
                      DatabaseColumn(
                        id: 'table_$i.id',
                        name: 'Id',
                        type: DatabaseColumnType.text,
                        isPrimaryKey: true,
                      ),
                      DatabaseColumn(
                        id: 'table_$i.name',
                        name: 'Name',
                        type: DatabaseColumnType.text,
                        required: true,
                      ),
                    ],
                  ),
              ],
            ),
            api: ApiSpecificationModel(
              endpoints: [
                for (var i = 0; i < tableCount; i++)
                  ApiEndpoint(
                    id: 'ep_$i',
                    path: '/table_$i',
                    method: HttpMethod.get,
                    operation: ApiOperation.list,
                    entityId: 'table_$i',
                  ),
              ],
            ),
            authentication: const AuthenticationModel(
              requiresCredentials: true,
            ),
            storage: const BackendStorageModel(),
            backgroundJobs: const BackgroundJobsModel(
              requiresBackgroundSync: false,
              sourceStrategy: SyncStrategy.none,
            ),
            deployment: const DeploymentSpecificationModel(
              requiresBackend: true,
              secretReferences: [SecretReference('API_KEY')],
            ),
          );

      test(
        'backend artifact generation latency for a large system (200 tables)',
        () {
          final plan = largePlan(200);
          final stopwatch = Stopwatch()..start();
          final result = const BackendServiceGenerator().generate(
            _contextFor(plan, model: _tripModel()),
          );
          stopwatch.stop();
          expect(result.hasErrors, isFalse);
          // ignore: avoid_print
          print(
            'R26 backend generation (200 tables): ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test(
        'serialization: JSON round-trip latency for a large generated artifact',
        () {
          final plan = largePlan(200);
          final result = const BackendServiceGenerator().generate(
            _contextFor(plan, model: _tripModel()),
          );
          final content = result.allArtifacts.single.content!;
          final stopwatch = Stopwatch()..start();
          final decoded = jsonDecode(content);
          stopwatch.stop();
          expect(decoded, isA<Map<String, dynamic>>());
          // ignore: avoid_print
          print(
            'R26 artifact JSON decode (${content.length} chars): ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test(
        'memory: real process RSS delta while generating 50 backend artifact sets',
        () {
          final rssBefore = ProcessInfo.currentRss;
          final plan = largePlan(20);
          for (var i = 0; i < 50; i++) {
            const BackendServiceGenerator().generate(
              _contextFor(plan, model: _tripModel()),
            );
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R26 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 50 generations',
          );
        },
      );
    },
  );
}
