/// Implementation Specification IS-R27 — Interface Generator Framework,
/// First API Generator Target. Proves the real gap this specification
/// closes: `SolutionExecutionPlanner` (R18) has always been able to
/// classify a `restApi` target as needed, but ALWAYS reported
/// `applicableNoGenerator` — no real `Generator` existed to fulfill it.
/// `RestApiGenerator` is the third real `Generator` implementation,
/// dispatched through the SAME, unmodified `Generator`/`GenerationPipeline`
/// framework (R10) and the SAME, unmodified `SolutionExecutionOrchestrator`
/// (R25) — never a second Compiler/Generator Framework/Runtime/Backend
/// Generator/AI Boundary.
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
import 'package:anything/execution_planning/execution_strategy.dart';
import 'package:anything/execution_planning/solution_execution_planner.dart';
import 'package:anything/generator_framework/generation_result.dart';
import 'package:anything/generator_framework/generator.dart';
import 'package:anything/generator_framework/reference/backend_service_generator.dart';
import 'package:anything/generator_framework/reference/rest_api_generator.dart';
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

// ── Fixtures (mirroring test/r26_backend_service_generator_test.dart's
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
  group('RestApiGenerator (R27 centerpiece)', () {
    test(
      'a real BackendEngineeringPlan + CanonicalImplementationModel produces real, typed, non-fabricated request/response models',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));

        expect(result.hasErrors, isFalse);
        final artifact = result.allArtifacts.single;
        final json = jsonDecode(artifact.content!) as Map<String, dynamic>;
        final endpoints = json['endpoints'] as List;
        expect(endpoints, hasLength(plan.api.endpoints.length));

        final createEndpoint =
            endpoints.firstWhere((e) => (e as Map)['operation'] == 'create')
                as Map<String, dynamic>;
        final requestModel = createEndpoint['requestModel'] as List;
        expect(requestModel.single, containsPair('name', 'Title'));
        expect(requestModel.single, containsPair('required', true));
        expect(
          requestModel.single,
          containsPair('type', 'text'),
          reason:
              'real type joined from CanonicalImplementationModel, never fabricated',
        );

        final getEndpoint =
            endpoints.firstWhere((e) => (e as Map)['operation'] == 'get')
                as Map<String, dynamic>;
        final responseModel =
            getEndpoint['responseModel'] as Map<String, dynamic>;
        expect(responseModel['body'], 'object');
        expect(
          (responseModel['fields'] as List).single,
          containsPair('name', 'Title'),
        );
      },
    );

    test(
      'list/search operations respond with body:array, real per-field types',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));
        final json =
            jsonDecode(result.allArtifacts.single.content!)
                as Map<String, dynamic>;
        final listEndpoint =
            (json['endpoints'] as List).firstWhere(
                  (e) => (e as Map)['operation'] == 'list',
                )
                as Map<String, dynamic>;
        expect((listEndpoint['responseModel'] as Map)['body'], 'array');
      },
    );

    test(
      'create/update/delete carry no responseModel body — matches CreationEngine\'s own precedent of naming request/response scope only where real',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));
        final json =
            jsonDecode(result.allArtifacts.single.content!)
                as Map<String, dynamic>;
        final deleteEndpoint =
            (json['endpoints'] as List).firstWhere(
                  (e) => (e as Map)['operation'] == 'delete',
                )
                as Map<String, dynamic>;
        expect((deleteEndpoint['responseModel'] as Map)['body'], isNull);
      },
    );

    test(
      'OpenAPI-shaped output: a real paths object with one entry per real ApiEndpoint path, methods matching one-to-one',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));
        final json =
            jsonDecode(result.allArtifacts.single.content!)
                as Map<String, dynamic>;
        final openapi = json['openapi'] as Map<String, dynamic>;
        expect(openapi['openapi'], '3.0.0');
        final paths = openapi['paths'] as Map<String, dynamic>;

        final realPaths = plan.api.endpoints.map((e) => e.path).toSet();
        expect(paths.keys.toSet(), realPaths);

        for (final endpoint in plan.api.endpoints) {
          final pathItem = paths[endpoint.path] as Map<String, dynamic>;
          final operation =
              pathItem[endpoint.method.name] as Map<String, dynamic>;
          expect(operation['operationId'], endpoint.id);
          expect(operation['responses'], isNotNull);
        }
      },
    );

    test(
      'authentication requirements reflect the real, unmodified AuthenticationModel',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));
        final json =
            jsonDecode(result.allArtifacts.single.content!)
                as Map<String, dynamic>;
        expect(json['authentication'], {
          'requiresCredentials': plan.authentication.requiresCredentials,
          'providerIndependent': plan.authentication.providerIndependent,
        });
      },
    );

    test(
      'authorization rules are honestly reported as unrepresented — never fabricated',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));
        expect(
          result.diagnostics.any(
            (d) =>
                d.category == DiagnosticCategory.skippedFeature &&
                d.message.contains('Authorization'),
          ),
          isTrue,
        );
      },
    );

    test(
      'error models are honestly reported as unrepresented — never fabricated',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));
        expect(
          result.diagnostics.any(
            (d) =>
                d.category == DiagnosticCategory.skippedFeature &&
                d.message.contains('Error Models'),
          ),
          isTrue,
        );
      },
    );

    test(
      'no BackendEngineeringPlan supplied: honest empty result, never a crash or fabricated artifact',
      () {
        final context = GeneratorContext(
          buildGraph: const BuildGraphBuilder().build(_tripModel()),
          target: const GeneratorTarget(id: 'x', name: 'X'),
        );
        final result = const RestApiGenerator().generate(context);
        expect(result.allArtifacts, isEmpty);
        expect(result.diagnostics, isNotEmpty);
        expect(result.diagnostics.first.severity, DiagnosticSeverity.info);
      },
    );

    test(
      'an ApiSpecificationModel with no endpoints produces an honest empty result',
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
        final result = const RestApiGenerator().generate(_contextFor(plan));
        expect(result.allArtifacts, isEmpty);
        expect(result.diagnostics, isNotEmpty);
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
        final result = const RestApiGenerator().generate(context);
        expect(result.hasErrors, isTrue);
      },
    );

    test(
      'never emits SQL DDL, server source code, or routing implementation code — Implementation Milestone R8\'s standing constraint, still in force',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final result = const RestApiGenerator().generate(_contextFor(plan));
        final content = result.allArtifacts.single.content!;
        for (final forbidden in [
          'CREATE TABLE',
          'INSERT INTO',
          'SELECT * FROM',
          'import express',
          'from flask',
          '@app.route',
          '@RestController',
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
      'the real GeneratorMetadata.id is distinct from the other two real generators\'',
      () {
        expect(const RestApiGenerator().metadata.id, 'reference.rest-api');
        expect(
          const RestApiGenerator().metadata.id,
          isNot(SolutionExecutionPlanner.runtimeExperienceGeneratorId),
        );
        expect(
          const RestApiGenerator().metadata.id,
          isNot(SolutionExecutionPlanner.backendServiceGeneratorId),
        );
        expect(
          const RestApiGenerator().metadata.id,
          SolutionExecutionPlanner.restApiGeneratorId,
        );
      },
    );

    test(
      'determinism: the same plan generated twice produces byte-for-byte identical output',
      () {
        final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
        final r1 = const RestApiGenerator().generate(_contextFor(plan));
        final r2 = const RestApiGenerator().generate(_contextFor(plan));
        expect(r1.allArtifacts.single.content, r2.allArtifacts.single.content);
      },
    );
  });

  group('SolutionExecutionPlanner integration (R27)', () {
    test(
      'a real backend-required, API-bearing SemanticSolutionArchitecture now classifies restApi as applicableWithGenerator',
      () {
        final strategy = const SolutionExecutionPlanner().plan(
          _solution(backendNeeded: true),
        );
        final restApi = strategy.forTarget(ExecutionTargetKind.restApi);
        expect(
          restApi.classification,
          ExecutionTargetClassification.applicableWithGenerator,
        );
        expect(restApi.requiredGenerators, [
          SolutionExecutionPlanner.restApiGeneratorId,
        ]);
        expect(
          restApi.dependencies,
          contains(ExecutionTargetKind.backendService),
        );
      },
    );

    test(
      'no backend need: restApi remains notApplicable even though real endpoints exist, unaffected by R27',
      () {
        // backendNeeded:false -> fully-offline architecture -> requiresBackend
        // is false, but ApiSpecificationModel.endpoints is still non-empty
        // (derived unconditionally from CRUD interactions, R8) — the real
        // "endpoints exist but nothing to deploy behind" notApplicable
        // branch _restApi() already handled correctly before R27.
        final strategy = const SolutionExecutionPlanner().plan(
          _solution(backendNeeded: false),
        );
        expect(
          strategy.forTarget(ExecutionTargetKind.restApi).classification,
          ExecutionTargetClassification.notApplicable,
        );
      },
    );
  });

  group(
    'SolutionExecutionOrchestrator three-generator integration (R27 mandatory vision validation)',
    () {
      test(
        'ONE ExecutionStrategy with Backend Service, REST API, AND Runtime Experience all applicableWithGenerator: the orchestrator runs ALL THREE real generators, in real dependency order',
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
            strategy.forTarget(ExecutionTargetKind.restApi).classification,
            ExecutionTargetClassification.applicableWithGenerator,
          );
          expect(
            strategy
                .forTarget(ExecutionTargetKind.runtimeExperience)
                .classification,
            ExecutionTargetClassification.applicableWithGenerator,
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
          final restApiOutcome = report.outcomeFor(
            ExecutionTargetKind.restApi,
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
            restApiOutcome.status,
            StageStatus.succeeded,
            reason: restApiOutcome.errors.join('; '),
          );
          expect(
            runtimeOutcome.status,
            StageStatus.succeeded,
            reason: runtimeOutcome.errors.join('; '),
          );

          expect(restApiOutcome.backendArtifacts, isNotEmpty);
          expect(
            restApiOutcome.package,
            isNull,
            reason: 'REST API output is never an ExperiencePackage',
          );
          expect(backendOutcome.backendArtifacts, isNotEmpty);
          expect(runtimeOutcome.package, isNotNull);

          // Real dependency-safe ordering: exactly three distinct levels, in
          // the order Backend Service -> REST API -> Runtime Experience.
          int levelOf(ExecutionTargetKind target) =>
              report.levels.indexWhere((level) => level.contains(target));
          final backendLevel = levelOf(ExecutionTargetKind.backendService);
          final restApiLevel = levelOf(ExecutionTargetKind.restApi);
          final runtimeLevel = levelOf(ExecutionTargetKind.runtimeExperience);
          expect(backendLevel, lessThan(restApiLevel));
          expect(restApiLevel, lessThan(runtimeLevel));
          expect(report.succeeded, isTrue);
        },
      );

      test(
        'backendPlan omitted for an applicableWithGenerator restApi target: a real, honest failure, never a crash, never a silent skip',
        () async {
          final solution = _solution(backendNeeded: true);
          final strategy = const SolutionExecutionPlanner().plan(solution);

          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );

          final restApiOutcome = report.outcomeFor(
            ExecutionTargetKind.restApi,
          )!;
          expect(restApiOutcome.status, StageStatus.failed);
          expect(
            restApiOutcome.attempts,
            1,
            reason:
                'a missing precondition is not a transient failure — it must never spin through retries',
          );
          expect(
            restApiOutcome.errors.single,
            contains('No BackendEngineeringPlan supplied'),
          );
        },
      );

      test(
        'a Runtime-Experience-only strategy (no backend need) still runs exactly as R25/R26 built it, unaffected by R27',
        () async {
          final solution = _solution(backendNeeded: false);
          final strategy = const SolutionExecutionPlanner().plan(solution);
          final report = await const SolutionExecutionOrchestrator().execute(
            strategy: strategy,
            model: _tripModel(),
            id: 'trip-tracker',
            name: 'Trip Tracker',
          );

          expect(
            report.outcomeFor(ExecutionTargetKind.backendService)!.status,
            StageStatus.skippedNotApplicable,
          );
          expect(
            report.outcomeFor(ExecutionTargetKind.restApi)!.status,
            StageStatus.skippedNotApplicable,
          );
          final runtimeOutcome = report.outcomeFor(
            ExecutionTargetKind.runtimeExperience,
          )!;
          expect(runtimeOutcome.status, StageStatus.succeeded);
          expect(runtimeOutcome.backendArtifacts, isNull);
        },
      );
    },
  );

  group(
    'Regression (R27): BackendServiceGenerator/RuntimeExperienceGenerator behavior unaffected',
    () {
      test(
        'BackendServiceGenerator still produces its own real, unaffected artifact for the same plan',
        () {
          final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
          final result = const BackendServiceGenerator().generate(
            _contextFor(plan),
          );
          expect(result.hasErrors, isFalse);
          expect(
            const BackendServiceGenerator().metadata.id,
            'reference.backend-service',
          );
        },
      );
    },
  );

  group(
    'Performance (R27) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test(
        'REST API generation latency for a large endpoint set (200 entities)',
        () {
          final entities = [
            for (var i = 0; i < 200; i++)
              ImplementationEntity(
                id: 'entity_$i',
                name: 'Entity $i',
                fields: [
                  ImplementationField(
                    id: 'name',
                    name: 'Name',
                    type: ImplementationDataType.text,
                    required: true,
                  ),
                ],
              ),
          ];
          final model = CanonicalImplementationModel(
            entities: entities,
            authentication: const AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: const BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );
          final endpoints = [
            for (var i = 0; i < 200; i++) ...[
              ApiEndpoint(
                id: 'entity_$i.list',
                path: '/entity_$i',
                method: HttpMethod.get,
                operation: ApiOperation.list,
                entityId: 'entity_$i',
              ),
              ApiEndpoint(
                id: 'entity_$i.create',
                path: '/entity_$i',
                method: HttpMethod.post,
                operation: ApiOperation.create,
                entityId: 'entity_$i',
                requestFields: const [
                  ApiRequestField(name: 'Name', required: true),
                ],
              ),
            ],
          ];
          const plan = BackendEngineeringPlan(
            database: DatabaseSchemaModel.empty,
            api: ApiSpecificationModel(endpoints: []),
            authentication: AuthenticationModel(requiresCredentials: false),
            storage: BackendStorageModel.empty,
            backgroundJobs: BackgroundJobsModel(
              requiresBackgroundSync: false,
              sourceStrategy: SyncStrategy.none,
            ),
            deployment: DeploymentSpecificationModel(requiresBackend: true),
          );
          final largePlan = BackendEngineeringPlan(
            database: plan.database,
            api: ApiSpecificationModel(endpoints: endpoints),
            authentication: plan.authentication,
            storage: plan.storage,
            backgroundJobs: plan.backgroundJobs,
            deployment: plan.deployment,
          );

          final stopwatch = Stopwatch()..start();
          final result = const RestApiGenerator().generate(
            _contextFor(largePlan, model: model),
          );
          stopwatch.stop();

          expect(result.hasErrors, isFalse);
          // ignore: avoid_print
          print(
            'R27 REST API generation (400 endpoints across 200 entities): ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test(
        'serialization: JSON round-trip latency for a large generated artifact',
        () {
          final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
          final result = const RestApiGenerator().generate(_contextFor(plan));
          final content = result.allArtifacts.single.content!;

          final stopwatch = Stopwatch()..start();
          for (var i = 0; i < 1000; i++) {
            jsonDecode(content);
          }
          stopwatch.stop();
          // ignore: avoid_print
          print(
            'R27 JSON round-trip (1000 decodes): ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test(
        'memory: real process RSS delta while generating 50 REST API artifact sets',
        () {
          final plan = _tripBackend(_tripArchitecture(backendNeeded: true));
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 50; i++) {
            const RestApiGenerator().generate(_contextFor(plan));
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R27 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 50 generations',
          );
        },
      );
    },
  );
}
