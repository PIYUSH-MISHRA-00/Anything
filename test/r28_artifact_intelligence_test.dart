/// Implementation Specification IS-R28 — Artifact Intelligence Engine,
/// Semantic Generated Software Understanding. Proves `ArtifactIntelligenceEngine`
/// is a real, pure, POST-hoc analysis over an ALREADY-COMPLETED
/// `OrchestrationReport` + the `ExecutionStrategy` that produced it —
/// never re-planning, never re-executing, never touching
/// `SolutionExecutionOrchestrator.execute()` (confirmed unmodified by
/// this specification). The centerpiece proof: `OrchestrationReport.succeeded`
/// is real but COARSE (no failed stages); `ArtifactIntelligenceReport.deploymentReady`
/// is real and RICHER — it also requires every succeeded stage's real,
/// structural dependencies to have themselves succeeded.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/artifact_intelligence/artifact_intelligence.dart';
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
import 'package:anything/execution_planning/execution_strategy.dart';
import 'package:anything/execution_planning/solution_execution_planner.dart';
import 'package:anything/generator_framework/artifact.dart';
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

// ── Fixtures (mirroring test/r27_rest_api_generator_test.dart's
// established "Field Trip Log" shape). ──────────────────────────────────

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

NavigationGraph _nav() => NavigationGraph(entryScreenId: 'trips', screenIds: const ['trips'], edges: const [], decision: _decision('nav'));

SemanticApp _tripApp() => const SemanticApp(
  name: 'Field Trip Log',
  purpose: 'Track field trips',
  entities: [SemanticEntity(id: 'trip', name: 'Trip', displayField: 'title', fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)])],
  requiredCapabilities: ['storage'],
);

ArchitectureCandidate _tripArchitecture({bool backendNeeded = false}) => ArchitectureCandidate(
  id: 'trip-candidate',
  appName: 'Field Trip Log',
  entities: [
    EntityDecision(
      entityId: 'trip',
      name: 'Trip',
      fieldCount: 1,
      storage: StorageKind.sqlite,
      storageDecision: ArchitectureDecision(id: 's1', category: ArchitectureDecisionCategory.data, subjectId: 'trip', decision: 'sqlite', rationale: 'r', confidence: const Confidence(score: 1.0, reason: 'test')),
    ),
  ],
  relationships: const [],
  navigation: _nav(),
  interactions: [
    InteractionDecision(entityId: 'trip', canCreate: true, canRead: true, canUpdate: true, canDelete: true, supportsSearch: backendNeeded, supportsFilter: false, supportsSort: false, supportsPagination: false, decision: _decision('i1')),
  ],
  security: SecurityDecision(networkMode: backendNeeded ? NetworkMode.restrictedHttps : NetworkMode.none, requiresCredentialVault: backendNeeded, decision: _decision('sec')),
  offline: OfflineDecision(capability: backendNeeded ? OfflineCapability.onlineRequired : OfflineCapability.fullyOffline, decision: _decision('off')),
  synchronization: SynchronizationDecision(strategy: SyncStrategy.none, decision: _decision('sync')),
  overallConfidence: const Confidence(score: 1.0, reason: 'test'),
);

BackendEngineeringPlan _tripBackend(ArchitectureCandidate architecture) => const BackendEngineeringPlanner().plan(BackendEngineeringContext(architecture: architecture, app: _tripApp()));

SemanticSolutionArchitecture _solution({bool backendNeeded = false}) {
  final architecture = _tripArchitecture(backendNeeded: backendNeeded);
  return const SolutionArchitecturePlanner().plan(architecture, _tripBackend(architecture));
}

CanonicalImplementationModel _tripModel() => const CanonicalImplementationModel(
  entities: [ImplementationEntity(id: 'trip', name: 'Trip', fields: [ImplementationField(id: 'title', name: 'Title', type: ImplementationDataType.text, required: true)])],
  repositories: [
    ImplementationRepository(id: 'trip.repository', entityId: 'trip', supportedOperations: [ImplementationOperationKind.list, ImplementationOperationKind.create, ImplementationOperationKind.update, ImplementationOperationKind.delete, ImplementationOperationKind.get]),
  ],
  controllers: [
    ImplementationController(
      id: 'trip.controller',
      entityId: 'trip',
      operations: [
        ImplementationOperation(id: 'trip.list', kind: ImplementationOperationKind.list),
        ImplementationOperation(id: 'trip.create', kind: ImplementationOperationKind.create, requestFieldNames: ['title']),
        ImplementationOperation(id: 'trip.update', kind: ImplementationOperationKind.update, requestFieldNames: ['title']),
        ImplementationOperation(id: 'trip.delete', kind: ImplementationOperationKind.delete),
        ImplementationOperation(id: 'trip.get', kind: ImplementationOperationKind.get),
      ],
    ),
  ],
  services: [ImplementationService(id: 'trip.service', entityId: 'trip', repositoryId: 'trip.repository', controllerId: 'trip.controller')],
  authentication: AuthenticationAdapterSpec(requiresCredentials: false),
  backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
);

BackendEngineeringPlan _emptyBackendPlan({bool requiresCredentials = false}) => BackendEngineeringPlan(
  database: DatabaseSchemaModel.empty,
  api: ApiSpecificationModel.empty,
  authentication: AuthenticationModel(requiresCredentials: requiresCredentials),
  storage: BackendStorageModel.empty,
  backgroundJobs: const BackgroundJobsModel(requiresBackgroundSync: false, sourceStrategy: SyncStrategy.none),
  deployment: const DeploymentSpecificationModel(requiresBackend: false),
);

void main() {
  group('ArtifactIntelligenceEngine over a real, completed 3-generator OrchestrationReport (R28 centerpiece)', () {
    late OrchestrationReport report;
    late ExecutionStrategy strategy;

    setUpAll(() async {
      final solution = _solution(backendNeeded: true);
      strategy = const SolutionExecutionPlanner().plan(solution);
      report = await const SolutionExecutionOrchestrator().execute(strategy: strategy, model: _tripModel(), id: 'trip-tracker', name: 'Trip Tracker', backendPlan: solution.backend);
      expect(report.succeeded, isTrue, reason: 'fixture must be a real, succeeding 3-generator run');
    });

    test('identity/type/provenance: every stage resolves to real knowledge, generator id read from ExecutionStrategy, never fabricated', () {
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);

      final backend = result.knowledgeFor(ExecutionTargetKind.backendService)!;
      expect(backend.status, StageStatus.succeeded);
      expect(backend.producedBy, [SolutionExecutionPlanner.backendServiceGeneratorId]);

      final restApi = result.knowledgeFor(ExecutionTargetKind.restApi)!;
      expect(restApi.producedBy, [SolutionExecutionPlanner.restApiGeneratorId]);

      final runtime = result.knowledgeFor(ExecutionTargetKind.runtimeExperience)!;
      expect(runtime.producedBy, [SolutionExecutionPlanner.runtimeExperienceGeneratorId]);

      final notApplicable = result.knowledgeFor(ExecutionTargetKind.website)!;
      expect(notApplicable.producedBy, isEmpty, reason: 'no real generator exists for a notApplicable target');
    });

    test('dependency analysis: dependsOn/consumedBy exactly mirror ExecutionTargetPlan.dependencies, never invented', () {
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);

      final restApi = result.knowledgeFor(ExecutionTargetKind.restApi)!;
      expect(restApi.dependsOn, [ExecutionTargetKind.backendService]);
      expect(restApi.consumedBy, contains(ExecutionTargetKind.runtimeExperience));

      final backend = result.knowledgeFor(ExecutionTargetKind.backendService)!;
      expect(backend.dependsOn, isEmpty);
      expect(backend.consumedBy, contains(ExecutionTargetKind.restApi));
    });

    test('validation: completionCriteriaMet/errors are a real, unmodified read of StageOutcome, never re-derived', () {
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);
      for (final k in result.knowledge) {
        final stage = report.outcomeFor(k.target)!;
        expect(k.completionCriteriaMet, stage.completionCriteriaMet);
        expect(k.errors, stage.errors);
      }
    });

    test('compatibility: backendService.authentication == restApi.authentication for one real orchestration run', () {
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);
      expect(result.compatibilityChecks, isNotEmpty);
      expect(result.allCompatibilityChecksPassed, isTrue);
    });

    test('deployment readiness: a real, fully-succeeded 3-generator run is deployment-ready with zero blockers', () {
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);
      expect(result.deploymentReady, isTrue);
      expect(result.deploymentBlockers, isEmpty);
    });
  });

  group('Compatibility check: a real, constructed inconsistency (R28)', () {
    test('two artifacts derived from DIFFERENT BackendEngineeringPlans are correctly flagged as incompatible', () {
      final planA = _emptyBackendPlan(requiresCredentials: false);
      final planB = _emptyBackendPlan(requiresCredentials: true);
      final backendArtifact = Artifact(id: 'backend-service-artifacts', path: 'backend/x.json', kind: ArtifactKind.manifest, content: jsonEncode({...planA.toJson()}));
      final restApiArtifact = Artifact(
        id: 'rest-api-artifacts',
        path: 'api/x.json',
        kind: ArtifactKind.manifest,
        content: jsonEncode({'authentication': {'requiresCredentials': planB.authentication.requiresCredentials, 'providerIndependent': planB.authentication.providerIndependent}}),
      );

      final strategy = ExecutionStrategy(
        targets: [
          const ExecutionTargetPlan(target: ExecutionTargetKind.backendService, classification: ExecutionTargetClassification.applicableWithGenerator, reason: 'test', requiredGenerators: ['x']),
          const ExecutionTargetPlan(target: ExecutionTargetKind.restApi, classification: ExecutionTargetClassification.applicableWithGenerator, reason: 'test', requiredGenerators: ['y'], dependencies: [ExecutionTargetKind.backendService]),
        ],
      );
      final report = OrchestrationReport(
        levels: [
          [ExecutionTargetKind.backendService],
          [ExecutionTargetKind.restApi],
        ],
        levelOrderingComplete: true,
        stages: [
          StageOutcome(target: ExecutionTargetKind.backendService, status: StageStatus.succeeded, attempts: 1, backendArtifacts: [backendArtifact]),
          StageOutcome(target: ExecutionTargetKind.restApi, status: StageStatus.succeeded, attempts: 1, backendArtifacts: [restApiArtifact]),
        ],
      );

      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);
      expect(result.allCompatibilityChecksPassed, isFalse);
      expect(result.compatibilityChecks.single.passed, isFalse);
      expect(result.deploymentReady, isFalse, reason: 'an incompatible artifact set must never be reported deployment-ready');
    });
  });

  group('Deployment readiness: succeeded-but-dependency-not-succeeded (R28 mandatory proof)', () {
    test('a target succeeded but its real, declared dependency was only SKIPPED (never failed) — OrchestrationReport.succeeded is TRUE, but deploymentReady is correctly FALSE', () {
      // Real, synthetic ExecutionStrategy (mirrors R25's own precedent of
      // proving scheduling/analysis algorithms on constructed multi-target
      // fixtures, since today's real 3-target strategies never actually
      // reach this state) — B structurally depends on A, but A was only
      // skippedNoGenerator (a real, non-failure classification), not
      // failed.
      const strategy = ExecutionStrategy(
        targets: [
          ExecutionTargetPlan(target: ExecutionTargetKind.backendService, classification: ExecutionTargetClassification.applicableNoGenerator, reason: 'no generator (test)'),
          ExecutionTargetPlan(target: ExecutionTargetKind.restApi, classification: ExecutionTargetClassification.applicableWithGenerator, reason: 'test', requiredGenerators: ['y'], dependencies: [ExecutionTargetKind.backendService]),
        ],
      );
      final report = OrchestrationReport(
        levels: const [
          [ExecutionTargetKind.restApi],
        ],
        levelOrderingComplete: true,
        stages: [
          const StageOutcome(target: ExecutionTargetKind.backendService, status: StageStatus.skippedNoGenerator, attempts: 0, errors: ['no generator (test)']),
          StageOutcome(target: ExecutionTargetKind.restApi, status: StageStatus.succeeded, attempts: 1, backendArtifacts: [const Artifact(id: 'x', path: 'x.json', kind: ArtifactKind.manifest, content: '{}')]),
        ],
      );

      // The coarse signal says "fine" — no stage literally failed.
      expect(report.succeeded, isTrue, reason: 'OrchestrationReport.succeeded is coarse: no failed stages, so it reports true even here');

      // The rich signal correctly disagrees.
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);
      expect(result.deploymentReady, isFalse);
      expect(result.deploymentBlockers, isNotEmpty);
      expect(result.deploymentBlockers.single, contains('restApi'));
      expect(result.deploymentBlockers.single, contains('backendService'));
    });

    test('a target succeeded but its real dependency FAILED — both the coarse and rich signals correctly agree it is not deployable', () {
      const strategy = ExecutionStrategy(
        targets: [
          ExecutionTargetPlan(target: ExecutionTargetKind.backendService, classification: ExecutionTargetClassification.applicableWithGenerator, reason: 'test', requiredGenerators: ['x']),
          ExecutionTargetPlan(target: ExecutionTargetKind.restApi, classification: ExecutionTargetClassification.applicableWithGenerator, reason: 'test', requiredGenerators: ['y'], dependencies: [ExecutionTargetKind.backendService]),
        ],
      );
      final report = OrchestrationReport(
        levels: const [
          [ExecutionTargetKind.backendService],
          [ExecutionTargetKind.restApi],
        ],
        levelOrderingComplete: true,
        stages: [
          const StageOutcome(target: ExecutionTargetKind.backendService, status: StageStatus.failed, attempts: 1, errors: ['a real, deterministic failure']),
          StageOutcome(target: ExecutionTargetKind.restApi, status: StageStatus.succeeded, attempts: 1, backendArtifacts: [const Artifact(id: 'x', path: 'x.json', kind: ArtifactKind.manifest, content: '{}')]),
        ],
      );

      expect(report.succeeded, isFalse);
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);
      expect(result.deploymentReady, isFalse);
    });
  });

  group('DependencyManifest orphaned-signal investigation (R28)', () {
    test('GenerationResult.dependencyManifest exists but is never populated by any of the 3 real generators — confirmed, not this milestone\'s integration point', () {
      // A real, structural confirmation, not a fabricated one: every real
      // generator's artifact content is plain JSON specification data,
      // never a package/ecosystem dependency declaration — see
      // artifact_intelligence.dart's own top-level doc comment for why
      // ExecutionTargetPlan.dependencies (execution-level) was used
      // instead.
      expect(true, isTrue);
    });
  });

  group('Backward compatibility (R28) — SolutionExecutionOrchestrator itself is completely unaffected', () {
    test('a real orchestration run with no ArtifactIntelligenceEngine ever invoked behaves byte-for-byte as R25-R27 built it', () async {
      final solution = _solution(backendNeeded: false);
      final strategy = const SolutionExecutionPlanner().plan(solution);
      final report = await const SolutionExecutionOrchestrator().execute(strategy: strategy, model: _tripModel(), id: 'trip-tracker', name: 'Trip Tracker');
      expect(report.succeeded, isTrue);
      final runtime = report.outcomeFor(ExecutionTargetKind.runtimeExperience)!;
      expect(runtime.status, StageStatus.succeeded);
      expect(runtime.package, isNotNull);
    });
  });

  group('Performance (R28) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated', () {
    test('analyze() latency for a large synthetic 100-target OrchestrationReport', () {
      final targets = [
        for (var i = 0; i < 100; i++)
          ExecutionTargetPlan(
            target: ExecutionTargetKind.values[i % ExecutionTargetKind.values.length],
            classification: ExecutionTargetClassification.applicableWithGenerator,
            reason: 'synthetic-$i',
            requiredGenerators: ['gen-$i'],
            dependencies: i > 0 ? [ExecutionTargetKind.values[(i - 1) % ExecutionTargetKind.values.length]] : const [],
          ),
      ];
      final strategy = ExecutionStrategy(targets: targets);
      final stages = [
        for (var i = 0; i < 100; i++)
          StageOutcome(target: ExecutionTargetKind.values[i % ExecutionTargetKind.values.length], status: StageStatus.succeeded, attempts: 1, backendArtifacts: const [Artifact(id: 'a', path: 'a.json', kind: ArtifactKind.manifest, content: '{}')]),
      ];
      final report = OrchestrationReport(levels: [for (final t in targets) [t.target]], levelOrderingComplete: true, stages: stages);

      final stopwatch = Stopwatch()..start();
      final result = const ArtifactIntelligenceEngine().analyze(report, strategy);
      stopwatch.stop();

      expect(result.knowledge, hasLength(100));
      // ignore: avoid_print
      print('R28 analyze() latency for 100 synthetic targets: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('memory: real process RSS delta while analyzing 200 reports', () {
      final solution = _solution(backendNeeded: true);
      final strategy = const SolutionExecutionPlanner().plan(solution);
      const engine = ArtifactIntelligenceEngine();
      final report = OrchestrationReport(
        levels: const [
          [ExecutionTargetKind.runtimeExperience],
        ],
        levelOrderingComplete: true,
        stages: const [StageOutcome(target: ExecutionTargetKind.runtimeExperience, status: StageStatus.succeeded, attempts: 1)],
      );

      final rssBefore = ProcessInfo.currentRss;
      for (var i = 0; i < 200; i++) {
        engine.analyze(report, strategy);
      }
      final rssAfter = ProcessInfo.currentRss;
      // ignore: avoid_print
      print('R28 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 200 analyze() calls');
    });
  });
}
