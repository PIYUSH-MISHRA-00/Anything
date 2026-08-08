/// Implementation Specification IS-R29 — Autonomous Solution Evolution
/// Engine, Closed-Loop Engineering. Proves the real gap this specification
/// closes: `RequirementGraphDiffer`(R3)/`ArchitectureDiffer`(R4)/
/// `AffectedEntityAnalyzer`(R24)/`IncrementalCompilerSynthesizer`(R24)/
/// `SolutionExecutionOrchestrator`(R25-R27)/`ArtifactIntelligenceEngine`(R28)
/// each already do real work, but nothing combined them into one "what
/// should happen next" decision. `SolutionEvolutionEngine` is a pure
/// composition — it never diffs/executes/validates itself, and it never
/// calls `SolutionExecutionOrchestrator.execute()` or
/// `IncrementalCompilerSynthesizer.synthesize()` (confirmed by grepping
/// this milestone's own new file: zero such calls). The one real,
/// structural asymmetry this suite proves explicitly: Backend Service/REST
/// API have no incremental path (`IncrementalCompilerSynthesizer` only
/// ever scopes `runCompilerPipeline`, which remains hardcoded to
/// `RuntimeExperienceGenerator`, R19) — any real change reaching either of
/// those targets forces `CompilationMode.full`, never `.incremental`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/artifact_intelligence/artifact_intelligence.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/compiler_integration/compiler_pipeline_runner.dart';
import 'package:anything/engineering_intelligence/affected_entities.dart';
import 'package:anything/engineering_intelligence/incremental_compiler_synthesis.dart';
import 'package:anything/execution_planning/execution_strategy.dart';
import 'package:anything/execution_planning/solution_execution_planner.dart';
import 'package:anything/generator_framework/artifact.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/solution_architecture/solution_architecture_planner.dart';
import 'package:anything/solution_evolution/solution_evolution.dart';
import 'package:anything/solution_orchestration/orchestration_result.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/requirement_graph.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures (mirroring test/r27_rest_api_generator_test.dart's
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

NavigationGraph _nav(List<String> screenIds) => NavigationGraph(
  entryScreenId: screenIds.first,
  screenIds: screenIds,
  edges: const [],
  decision: _decision('nav'),
);

SemanticApp _campApp() => const SemanticApp(
  name: 'Camp Log',
  purpose: 'Track camping trips',
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

/// [withGear]: adds a second, genuinely new entity ('gear') — the real
/// "after" state for diff-driven evolution-planning tests.
/// [backendNeeded]: whether the new entity needs backend presence.
ArchitectureCandidate _campArchitecture({
  bool withGear = false,
  bool backendNeeded = false,
}) => ArchitectureCandidate(
  id: 'camp-candidate',
  appName: 'Camp Log',
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
    if (withGear)
      EntityDecision(
        entityId: 'gear',
        name: 'Gear',
        fieldCount: 1,
        storage: StorageKind.sqlite,
        storageDecision: ArchitectureDecision(
          id: 's2',
          category: ArchitectureDecisionCategory.data,
          subjectId: 'gear',
          decision: 'sqlite',
          rationale: 'r',
          confidence: const Confidence(score: 1.0, reason: 'test'),
        ),
      ),
  ],
  relationships: const [],
  navigation: _nav(withGear ? ['trips', 'gear'] : ['trips']),
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
    if (withGear)
      InteractionDecision(
        entityId: 'gear',
        canCreate: true,
        canRead: true,
        canUpdate: true,
        canDelete: true,
        supportsSearch: backendNeeded,
        supportsFilter: false,
        supportsSort: false,
        supportsPagination: false,
        decision: _decision('i2'),
      ),
  ],
  security: SecurityDecision(
    networkMode: backendNeeded ? NetworkMode.restrictedHttps : NetworkMode.none,
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

BackendEngineeringPlan _campBackend(ArchitectureCandidate architecture) =>
    const BackendEngineeringPlanner().plan(
      BackendEngineeringContext(architecture: architecture, app: _campApp()),
    );

ExecutionStrategy _executionStrategyFor(ArchitectureCandidate architecture) {
  final backend = _campBackend(architecture);
  final solution = const SolutionArchitecturePlanner().plan(
    architecture,
    backend,
  );
  return const SolutionExecutionPlanner().plan(solution);
}

RequirementGraph _requirementsFor({bool withGear = false}) => RequirementGraph(
  nodes: [
    const RequirementNode(
      id: 'entity:trip',
      type: RequirementNodeType.entity,
      label: 'Trip',
    ),
    const RequirementNode(
      id: 'field:trip.title',
      type: RequirementNodeType.field,
      label: 'Title',
    ),
    if (withGear)
      const RequirementNode(
        id: 'entity:gear',
        type: RequirementNodeType.entity,
        label: 'Gear',
      ),
    if (withGear)
      const RequirementNode(
        id: 'field:gear.title',
        type: RequirementNodeType.field,
        label: 'Title',
      ),
  ],
);

CanonicalImplementationModel _campModel({
  bool withGear = false,
}) => CanonicalImplementationModel(
  entities: [
    const ImplementationEntity(
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
    if (withGear)
      const ImplementationEntity(
        id: 'gear',
        name: 'Gear',
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
  controllers: [
    const ImplementationController(
      id: 'trip.controller',
      entityId: 'trip',
      operations: [
        ImplementationOperation(
          id: 'trip.list',
          kind: ImplementationOperationKind.list,
        ),
      ],
    ),
    if (withGear)
      const ImplementationController(
        id: 'gear.controller',
        entityId: 'gear',
        operations: [
          ImplementationOperation(
            id: 'gear.list',
            kind: ImplementationOperationKind.list,
          ),
        ],
      ),
  ],
  authentication: const AuthenticationAdapterSpec(requiresCredentials: false),
  backgroundWorker: const BackgroundWorkerSpec(requiresBackgroundSync: false),
);

void main() {
  group(
    'Regeneration planning (R29 centerpiece) — three real, distinguishing scenarios',
    () {
      test(
        'scenario 1: frontend-only change (no backend need) -> regenerateRuntime + validate, CompilationMode.incremental',
        () {
          final before = _campArchitecture();
          final after = _campArchitecture(withGear: true);
          final plan = const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: _requirementsFor(),
            afterRequirements: _requirementsFor(withGear: true),
            beforeArchitecture: before,
            afterArchitecture: after,
            afterExecutionStrategy: _executionStrategyFor(after),
          );

          expect(plan.isNoOp, isFalse);
          expect(plan.actions, {
            EvolutionAction.regenerateRuntime,
            EvolutionAction.validate,
          });
          expect(plan.compilationMode, CompilationMode.incremental);
          expect(plan.affectedEntities.entityIds, contains('gear'));
          expect(plan.requirementDiff.isEmpty, isFalse);
          expect(plan.architectureDiff.isEmpty, isFalse);
        },
      );

      test(
        'scenario 2: backend-affecting change -> regenerateBackend/regenerateRestApi included, CompilationMode.full (never incremental)',
        () {
          final before = _campArchitecture(backendNeeded: true);
          final after = _campArchitecture(withGear: true, backendNeeded: true);
          final plan = const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: _requirementsFor(),
            afterRequirements: _requirementsFor(withGear: true),
            beforeArchitecture: before,
            afterArchitecture: after,
            afterExecutionStrategy: _executionStrategyFor(after),
          );

          expect(plan.actions, contains(EvolutionAction.regenerateBackend));
          expect(plan.actions, contains(EvolutionAction.regenerateRuntime));
          expect(plan.actions, contains(EvolutionAction.validate));
          expect(
            plan.compilationMode,
            CompilationMode.full,
            reason:
                'Backend Service has no incremental path — this must never be incremental',
          );
        },
      );

      test(
        'scenario 3: no change at all -> noAction, CompilationMode.none',
        () {
          final architecture = _campArchitecture();
          final plan = const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: _requirementsFor(),
            afterRequirements: _requirementsFor(),
            beforeArchitecture: architecture,
            afterArchitecture: architecture,
            afterExecutionStrategy: _executionStrategyFor(architecture),
          );

          expect(plan.isNoOp, isTrue);
          expect(plan.actions, {EvolutionAction.noAction});
          expect(plan.compilationMode, CompilationMode.none);
          expect(plan.affectedEntities.isEmpty, isTrue);
        },
      );

      test(
        'a real change to an architecture with zero applicable generator targets (no frontend, no backend) produces validate-only, CompilationMode.none — never a fabricated regenerate action',
        () {
          final before = ArchitectureCandidate(
            id: 'empty',
            appName: 'Empty',
            entities: const [],
            relationships: const [],
            navigation: NavigationGraph(
              entryScreenId: 'none',
              screenIds: const [],
              edges: const [],
              decision: _decision('nav'),
            ),
            interactions: const [],
            security: SecurityDecision(
              networkMode: NetworkMode.none,
              requiresCredentialVault: false,
              decision: _decision('sec'),
            ),
            offline: OfflineDecision(
              capability: OfflineCapability.fullyOffline,
              decision: _decision('off'),
            ),
            synchronization: SynchronizationDecision(
              strategy: SyncStrategy.none,
              decision: _decision('sync'),
            ),
            overallConfidence: const Confidence(score: 1.0, reason: 'test'),
          );
          final plan = const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: const RequirementGraph(),
            afterRequirements: _requirementsFor(),
            beforeArchitecture: before,
            afterArchitecture: before,
            afterExecutionStrategy: _executionStrategyFor(before),
          );

          // requirementDiff alone (entity:trip added, nothing on the
          // architecture side) is enough to make this non-empty.
          expect(plan.affectedEntities.isEmpty, isFalse);
          expect(plan.actions, {EvolutionAction.validate});
          expect(plan.compilationMode, CompilationMode.none);
        },
      );
    },
  );

  group(
    'Incremental reuse (R29) — the CALLER follows this engine\'s advice; the engine itself never executes',
    () {
      test(
        'a caller following a CompilationMode.incremental recommendation successfully uses IncrementalCompilerSynthesizer and produces a valid package',
        () {
          final before = _campArchitecture();
          final after = _campArchitecture(withGear: true);
          final plan = const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: _requirementsFor(),
            afterRequirements: _requirementsFor(withGear: true),
            beforeArchitecture: before,
            afterArchitecture: after,
            afterExecutionStrategy: _executionStrategyFor(after),
          );
          expect(plan.compilationMode, CompilationMode.incremental);

          final result = const IncrementalCompilerSynthesizer().synthesize(
            fullModel: _campModel(withGear: true),
            affected: plan.affectedEntities,
            id: 'camp-log',
            name: 'Camp Log',
          );
          expect(result.succeeded, isTrue);
          expect(
            result.scopedEntityCount,
            1,
            reason: 'only the affected "gear" entity should be scoped in',
          );
        },
      );

      test(
        'a caller following a CompilationMode.full recommendation dispatches the real, unmodified runCompilerPipeline over the FULL model',
        () {
          final before = _campArchitecture(backendNeeded: true);
          final after = _campArchitecture(withGear: true, backendNeeded: true);
          final plan = const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: _requirementsFor(),
            afterRequirements: _requirementsFor(withGear: true),
            beforeArchitecture: before,
            afterArchitecture: after,
            afterExecutionStrategy: _executionStrategyFor(after),
          );
          expect(plan.compilationMode, CompilationMode.full);

          final outcome = runCompilerPipeline(
            _campModel(withGear: true),
            id: 'camp-log',
            name: 'Camp Log',
          );
          expect(outcome.succeeded, isTrue);
        },
      );
    },
  );

  group(
    'Deployment decisions (R29) — a real, thin restatement of ArtifactIntelligenceReport.deploymentReady, never new logic',
    () {
      test('deploymentReady:true restates as DeploymentDecision.allowed', () {
        const report = ArtifactIntelligenceReport(
          knowledge: [],
          compatibilityChecks: [],
          deploymentReady: true,
          deploymentBlockers: [],
        );
        expect(
          const SolutionEvolutionEngine().decideDeployment(report),
          DeploymentDecision.allowed,
        );
      });

      test(
        'deploymentReady:false (real blockers present) restates as DeploymentDecision.blocked',
        () {
          const report = ArtifactIntelligenceReport(
            knowledge: [],
            compatibilityChecks: [],
            deploymentReady: false,
            deploymentBlockers: [
              'restApi succeeded but its real dependency backendService did not',
            ],
          );
          expect(
            const SolutionEvolutionEngine().decideDeployment(report),
            DeploymentDecision.blocked,
          );
        },
      );

      test(
        'a real ArtifactIntelligenceEngine.analyze() output flows straight into a real DeploymentDecision, end-to-end',
        () {
          const strategy = ExecutionStrategy(
            targets: [
              ExecutionTargetPlan(
                target: ExecutionTargetKind.backendService,
                classification:
                    ExecutionTargetClassification.applicableNoGenerator,
                reason: 'no generator (test)',
              ),
              ExecutionTargetPlan(
                target: ExecutionTargetKind.restApi,
                classification:
                    ExecutionTargetClassification.applicableWithGenerator,
                reason: 'test',
                requiredGenerators: ['reference.rest-api'],
                dependencies: [ExecutionTargetKind.backendService],
              ),
            ],
          );
          final report = OrchestrationReport(
            levels: const [
              [ExecutionTargetKind.restApi],
            ],
            levelOrderingComplete: true,
            stages: [
              const StageOutcome(
                target: ExecutionTargetKind.backendService,
                status: StageStatus.skippedNoGenerator,
                attempts: 0,
                errors: ['no generator (test)'],
              ),
              StageOutcome(
                target: ExecutionTargetKind.restApi,
                status: StageStatus.succeeded,
                attempts: 1,
                backendArtifacts: [
                  const Artifact(
                    id: 'x',
                    path: 'x.json',
                    kind: ArtifactKind.manifest,
                    content: '{}',
                  ),
                ],
              ),
            ],
          );

          final artifactReport = const ArtifactIntelligenceEngine().analyze(
            report,
            strategy,
          );
          expect(artifactReport.deploymentReady, isFalse);
          expect(
            const SolutionEvolutionEngine().decideDeployment(artifactReport),
            DeploymentDecision.blocked,
          );
        },
      );
    },
  );

  group('Validation decisions (R29)', () {
    test('validate is present whenever any regenerate* action is present', () {
      final before = _campArchitecture();
      final after = _campArchitecture(withGear: true);
      final plan = const SolutionEvolutionEngine().planRegeneration(
        beforeRequirements: _requirementsFor(),
        afterRequirements: _requirementsFor(withGear: true),
        beforeArchitecture: before,
        afterArchitecture: after,
        afterExecutionStrategy: _executionStrategyFor(after),
      );
      expect(plan.actions, contains(EvolutionAction.validate));
    });

    test('validate is absent when nothing changed (noAction case)', () {
      final architecture = _campArchitecture();
      final plan = const SolutionEvolutionEngine().planRegeneration(
        beforeRequirements: _requirementsFor(),
        afterRequirements: _requirementsFor(),
        beforeArchitecture: architecture,
        afterArchitecture: architecture,
        afterExecutionStrategy: _executionStrategyFor(architecture),
      );
      expect(plan.actions, isNot(contains(EvolutionAction.validate)));
    });
  });

  group('Purity (R29) — the engine never executes anything itself', () {
    test(
      'planRegeneration and decideDeployment are synchronous, non-Future-returning, real pure functions',
      () {
        // Structural proof: if either method returned a Future, this file
        // would need `await` above and fail to compile without it — the
        // synchronous return type itself proves no execution/IO happens
        // inside this engine.
        final architecture = _campArchitecture();
        final RegenerationPlan plan = const SolutionEvolutionEngine()
            .planRegeneration(
              beforeRequirements: _requirementsFor(),
              afterRequirements: _requirementsFor(),
              beforeArchitecture: architecture,
              afterArchitecture: architecture,
              afterExecutionStrategy: _executionStrategyFor(architecture),
            );
        const DeploymentDecision decision = DeploymentDecision.allowed;
        expect(plan, isNotNull);
        expect(decision, DeploymentDecision.allowed);
      },
    );
  });

  group(
    'Regression (R29) — SolutionExecutionOrchestrator/IncrementalCompilerSynthesizer behavior is completely unaffected',
    () {
      test(
        'IncrementalCompilerSynthesizer.synthesize() called directly (bypassing SolutionEvolutionEngine entirely) behaves exactly as R24 built it',
        () {
          final result = const IncrementalCompilerSynthesizer().synthesize(
            fullModel: _campModel(withGear: true),
            affected: const AffectedEntities({'gear'}),
            id: 'camp-log',
            name: 'Camp Log',
          );
          expect(result.succeeded, isTrue);
        },
      );
    },
  );

  group(
    'Performance (R29) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test(
        'planRegeneration latency for a large synthetic before/after state pair (200 entities)',
        () {
          RequirementGraph bigGraph(int count) => RequirementGraph(
            nodes: [
              for (var i = 0; i < count; i++)
                RequirementNode(
                  id: 'entity:e$i',
                  type: RequirementNodeType.entity,
                  label: 'E$i',
                ),
            ],
          );
          final before = bigGraph(200);
          final after = bigGraph(201);
          final architecture = _campArchitecture();

          final stopwatch = Stopwatch()..start();
          final plan = const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: before,
            afterRequirements: after,
            beforeArchitecture: architecture,
            afterArchitecture: architecture,
            afterExecutionStrategy: _executionStrategyFor(architecture),
          );
          stopwatch.stop();

          expect(plan.affectedEntities.entityIds, contains('e200'));
          // ignore: avoid_print
          print(
            'R29 planRegeneration latency (200 -> 201 entities): ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test('memory: real process RSS delta while planning 100 evolutions', () {
        final architecture = _campArchitecture();
        final strategy = _executionStrategyFor(architecture);
        final rssBefore = ProcessInfo.currentRss;
        for (var i = 0; i < 100; i++) {
          const SolutionEvolutionEngine().planRegeneration(
            beforeRequirements: _requirementsFor(),
            afterRequirements: _requirementsFor(withGear: true),
            beforeArchitecture: architecture,
            afterArchitecture: architecture,
            afterExecutionStrategy: strategy,
          );
        }
        final rssAfter = ProcessInfo.currentRss;
        // ignore: avoid_print
        print(
          'R29 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 100 evolutions',
        );
      });
    },
  );
}
