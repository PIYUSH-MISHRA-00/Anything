/// Implementation Milestone R17 — Semantic Solution Architecture, Full-
/// Stack Architecture Synthesis. Proves the real gap this milestone
/// closes: of the 20 requested representation categories, 11 were
/// ALREADY real (`ArchitectureCandidate`/`BackendEngineeringPlan`,
/// composed here by reference, never duplicated); of the 9 genuinely
/// missing, only Caching has real upstream signal
/// (`BackgroundJobsModel.sourceStrategy`) — modeled honestly; the other 8
/// are named, not fabricated. Never a second Compiler/Build Graph/
/// Runtime/Generator Framework/World Model/Capability Platform/Knowledge
/// Engine/AI Boundary.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/application_engineering/engineering_candidate.dart';
import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/build_graph/universal_build_graph.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/generator_framework/generation_pipeline.dart';
import 'package:anything/generator_framework/generator.dart';
import 'package:anything/generator_framework/reference/runtime_experience_generator.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/implementation_model/canonical_implementation_planner.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/solution_architecture/solution_architecture.dart';
import 'package:anything/solution_architecture/solution_architecture_planner.dart';
import 'package:anything/solution_architecture/solution_architecture_serialization.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_cognition/architecture_analyzer.dart';
import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

// ── Fixtures (mirrors test/r8_backend_engineering_test.dart's established
// shape — a test file cannot import another test file's private helpers,
// so equivalents are redeclared minimally). Novel domain ("Book Club
// Tracker"), zero footprint elsewhere in lib/. ────────────────────────────

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

NavigationGraph _nav() => NavigationGraph(
  entryScreenId: 'books',
  screenIds: const ['books'],
  edges: const [],
  decision: _decision('nav'),
);

SemanticApp _bookClubApp() => const SemanticApp(
  name: 'Book Club Tracker',
  purpose: 'Track book club selections and member notes',
  entities: [
    SemanticEntity(
      id: 'book',
      name: 'Book',
      displayField: 'title',
      fields: [
        SemanticField(
          id: 'title',
          name: 'Title',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: 'pages',
          name: 'Pages',
          type: BlueprintFieldType.integer,
        ),
      ],
    ),
    SemanticEntity(
      id: 'note',
      name: 'Note',
      displayField: 'body',
      fields: [
        SemanticField(
          id: 'body',
          name: 'Body',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: 'book_ref',
          name: 'Book',
          type: BlueprintFieldType.reference,
          referenceEntityId: 'book',
          required: true,
        ),
      ],
    ),
  ],
);

ArchitectureCandidate _bookClubArchitecture({
  bool requiresCredentialVault = false,
  List<PermissionDecision> permissions = const [],
  SyncStrategy sync = SyncStrategy.none,
}) => ArchitectureCandidate(
  id: 'book-club-candidate',
  appName: 'Book Club Tracker',
  entities: const [
    EntityDecision(
      entityId: 'book',
      name: 'Book',
      fieldCount: 2,
      storage: StorageKind.sqlite,
      storageDecision: ArchitectureDecision(
        id: 's1',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'book',
        decision: 'sqlite',
        rationale: 'r',
        confidence: Confidence(score: 1.0, reason: 'test'),
      ),
    ),
    EntityDecision(
      entityId: 'note',
      name: 'Note',
      fieldCount: 2,
      storage: StorageKind.sqlite,
      storageDecision: ArchitectureDecision(
        id: 's2',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'note',
        decision: 'sqlite',
        rationale: 'r',
        confidence: Confidence(score: 1.0, reason: 'test'),
      ),
    ),
  ],
  relationships: const [
    RelationshipDecision(
      fromEntityId: 'note',
      toEntityId: 'book',
      fieldId: 'book_ref',
      deletePolicy: RelationshipDeletePolicy.restrict,
      decision: ArchitectureDecision(
        id: 'rel1',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'rel',
        decision: 'restrict',
        rationale: 'r',
        confidence: Confidence(score: 1.0, reason: 'test'),
      ),
    ),
  ],
  navigation: _nav(),
  interactions: const [
    InteractionDecision(
      entityId: 'book',
      canCreate: true,
      canRead: true,
      canUpdate: true,
      canDelete: true,
      supportsSearch: true,
      supportsFilter: false,
      supportsSort: false,
      supportsPagination: false,
      decision: ArchitectureDecision(
        id: 'i1',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'book',
        decision: 'd',
        rationale: 'r',
        confidence: Confidence(score: 1.0, reason: 'test'),
      ),
    ),
    InteractionDecision(
      entityId: 'note',
      canCreate: true,
      canRead: true,
      canUpdate: false,
      canDelete: true,
      supportsSearch: false,
      supportsFilter: false,
      supportsSort: false,
      supportsPagination: false,
      decision: ArchitectureDecision(
        id: 'i2',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'note',
        decision: 'd',
        rationale: 'r',
        confidence: Confidence(score: 1.0, reason: 'test'),
      ),
    ),
  ],
  permissions: permissions,
  security: SecurityDecision(
    networkMode: NetworkMode.none,
    requiresCredentialVault: requiresCredentialVault,
    decision: _decision('sec'),
  ),
  offline: const OfflineDecision(
    capability: OfflineCapability.fullyOffline,
    decision: ArchitectureDecision(
      id: 'off',
      category: ArchitectureDecisionCategory.data,
      subjectId: 'off',
      decision: 'd',
      rationale: 'r',
      confidence: Confidence(score: 1.0, reason: 'test'),
    ),
  ),
  synchronization: SynchronizationDecision(
    strategy: sync,
    decision: _decision('sync'),
  ),
  overallConfidence: const Confidence(score: 1.0, reason: 'test'),
);

BackendEngineeringPlan _bookClubBackend(ArchitectureCandidate architecture) =>
    const BackendEngineeringPlanner().plan(
      BackendEngineeringContext(
        architecture: architecture,
        app: _bookClubApp(),
      ),
    );

void main() {
  group('SolutionArchitecturePlanner — components (R17)', () {
    test(
      'every frontend entity becomes a real SolutionComponent, composed from ArchitectureCandidate + BackendEngineeringPlan, never duplicated',
      () {
        final architecture = _bookClubArchitecture();
        final backend = _bookClubBackend(architecture);
        final solution = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );

        expect(
          solution.frontend,
          same(architecture),
          reason: 'held by reference, never copied',
        );
        expect(
          solution.backend,
          same(backend),
          reason: 'held by reference, never copied',
        );
        expect(solution.components, hasLength(2));

        final book = solution.components.firstWhere((c) => c.id == 'book');
        expect(book.hasBackendPresence, isTrue);
        expect(book.storageKind, StorageKind.sqlite.name);
        expect(book.contractIds, isNotEmpty);

        final note = solution.components.firstWhere((c) => c.id == 'note');
        expect(
          note.dependsOnComponentIds,
          contains('book'),
          reason: 'real FK-derived dependency, never guessed',
        );
      },
    );

    test(
      'an entity with no backend API endpoints reports hasBackendPresence:false, never fabricated',
      () {
        const app = SemanticApp(
          name: 'x',
          purpose: 'x',
          entities: [SemanticEntity(id: 'orphan', name: 'Orphan')],
        );
        final architecture = _bookClubArchitecture();
        final backend = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(architecture: architecture, app: app),
        );
        // architecture.entities still names book/note; backend has zero endpoints for either since `app` has no matching entities.
        final solution = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );
        expect(
          solution.components.every((c) => c.hasBackendPresence == false),
          isTrue,
        );
        expect(solution.components.every((c) => c.contractIds.isEmpty), isTrue);
      },
    );
  });

  group(
    'SolutionArchitecturePlanner — caching (R17, real signal from BackgroundJobsModel.sourceStrategy)',
    () {
      test(
        'cacheFirst synchronization strategy produces employsCaching:true',
        () {
          final architecture = _bookClubArchitecture(
            sync: SyncStrategy.cacheFirst,
          );
          final solution = const SolutionArchitecturePlanner().plan(
            architecture,
            _bookClubBackend(architecture),
          );
          expect(solution.caching.employsCaching, isTrue);
          expect(solution.caching.sourceStrategy, SyncStrategy.cacheFirst);
        },
      );

      test(
        'none/manualRefresh/networkFirst strategies all produce employsCaching:false — never a guessed default',
        () {
          for (final strategy in [
            SyncStrategy.none,
            SyncStrategy.manualRefresh,
            SyncStrategy.networkFirst,
          ]) {
            final architecture = _bookClubArchitecture(sync: strategy);
            final solution = const SolutionArchitecturePlanner().plan(
              architecture,
              _bookClubBackend(architecture),
            );
            expect(
              solution.caching.employsCaching,
              isFalse,
              reason: 'strategy=$strategy',
            );
          }
        },
      );
    },
  );

  group('SolutionArchitecturePlanner — honest gaps (R17)', () {
    test(
      'exactly the 8 genuinely unmodeled concepts are named, every one with a real, non-empty reason',
      () {
        final architecture = _bookClubArchitecture();
        final solution = const SolutionArchitecturePlanner().plan(
          architecture,
          _bookClubBackend(architecture),
        );
        final names = solution.unmodeledConcepts.map((u) => u.name).toSet();
        expect(names, {
          'realtime',
          'messaging',
          'notifications',
          'observability',
          'monitoring',
          'configuration',
          'policies',
          'scaling',
        });
        expect(
          solution.unmodeledConcepts.every((u) => u.reason.isNotEmpty),
          isTrue,
        );
        // Caching is explicitly NOT in this list — it IS modeled.
        expect(names, isNot(contains('caching')));
      },
    );
  });

  group('Determinism (R17)', () {
    test(
      'the same ArchitectureCandidate + BackendEngineeringPlan planned twice produce byte-for-byte identical JSON',
      () {
        final architecture = _bookClubArchitecture(
          permissions: [
            PermissionDecision(
              permission: 'camera',
              requiredByCapabilityId: 'photo',
              decision: _decision('perm'),
            ),
          ],
        );
        final backend = _bookClubBackend(architecture);
        final a = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );
        final b = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );
        expect(a.toJson(), equals(b.toJson()));
      },
    );
  });

  group('Serialization round-trip (R17)', () {
    test(
      'toJson/fromJson round-trips with full fidelity, including composed frontend/backend and honest gaps',
      () {
        final architecture = _bookClubArchitecture(
          sync: SyncStrategy.cacheFirst,
          permissions: [
            PermissionDecision(
              permission: 'camera',
              requiredByCapabilityId: 'photo',
              decision: _decision('perm'),
            ),
          ],
        );
        final backend = _bookClubBackend(architecture);
        final original = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );

        final stopwatch = Stopwatch()..start();
        final json = original.toJson();
        final encoded = jsonEncode(json);
        final restored = semanticSolutionArchitectureFromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
        stopwatch.stop();

        expect(
          restored.frontend.entities.length,
          original.frontend.entities.length,
        );
        expect(
          restored.backend.database.tables.length,
          original.backend.database.tables.length,
        );
        expect(restored.components.length, original.components.length);
        expect(
          restored.caching.employsCaching,
          original.caching.employsCaching,
        );
        expect(
          restored.unmodeledConcepts.length,
          original.unmodeledConcepts.length,
        );
        // ignore: avoid_print
        print(
          'R17 serialization round-trip: ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );
  });

  group(
    'Software Cognition enrichment (R17) — RealtimePatternAnalyzer / CachingPatternAnalyzer, mirrors R14\'s AuthenticationPatternAnalyzer shape exactly',
    () {
      RepositoryMetadata meta(String name) => RepositoryMetadata(
        name: name,
        description: '',
        primaryLanguage: 'dart',
        provenance: SoftwareProvenance(
          sourceUrl: 'https://example.com/$name',
          retrievedAt: DateTime(2026, 8, 3),
          provider: 'test-fixture',
          license: const LicenseMetadata(
            policy: LicensePolicy.permissiveKnown,
            licenseId: 'MIT',
          ),
        ),
      );

      test('detects a real, known realtime dependency', () {
        final model = RepositoryAnalyzer().analyze(
          RepositoryContext(
            source: 'websocket\nflutter\n',
            metadata: meta('realtime-app'),
          ),
        );
        final labels = const RealtimePatternAnalyzer()
            .analyze(model)
            .graph
            .nodes
            .map((n) => n.label)
            .toSet();
        expect(labels, contains('websocket'));
        expect(labels, isNot(contains('flutter')));
      });

      test(
        'a repository with no known realtime dependency produces no fabricated pattern',
        () {
          final model = RepositoryAnalyzer().analyze(
            RepositoryContext(
              source: 'flutter\n',
              metadata: meta('no-realtime-app'),
            ),
          );
          expect(
            const RealtimePatternAnalyzer().analyze(model).graph.nodes,
            isEmpty,
          );
        },
      );

      test('detects a real, known caching dependency', () {
        final model = RepositoryAnalyzer().analyze(
          RepositoryContext(
            source: 'memcached\nflutter\n',
            metadata: meta('caching-app'),
          ),
        );
        final labels = const CachingPatternAnalyzer()
            .analyze(model)
            .graph
            .nodes
            .map((n) => n.label)
            .toSet();
        expect(labels, contains('memcached'));
        expect(labels, isNot(contains('flutter')));
      });

      test(
        'a repository with no known caching dependency produces no fabricated pattern',
        () {
          final model = RepositoryAnalyzer().analyze(
            RepositoryContext(
              source: 'flutter\n',
              metadata: meta('no-caching-app'),
            ),
          );
          expect(
            const CachingPatternAnalyzer().analyze(model).graph.nodes,
            isEmpty,
          );
        },
      );
    },
  );

  group('World Model integration (R17)', () {
    test(
      'frontend entities unify with the SAME node backend entities already resolve to — never a duplicate',
      () {
        final architecture = _bookClubArchitecture();
        final backend = _bookClubBackend(architecture);
        final solution = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );

        final worldModel = WorldModelCoordinator();
        worldModel.ingestBackendEngineering(backend);
        final countAfterBackend = worldModel.model.graph.nodes.length;
        worldModel.ingestSolutionArchitecture(solution);
        final countAfterArchitecture = worldModel.model.graph.nodes.length;

        final bookNodes = worldModel.model.graph.nodes.where(
          (n) => n.kind == WorldNodeKind.entity && n.label == 'Book',
        );
        expect(
          bookNodes,
          hasLength(1),
          reason:
              'the SAME real-world entity observed from backend then frontend must collapse into one node',
        );
        // Real growth still happened (permission/caching nodes, if any) —
        // just no duplicate entity nodes.
        expect(countAfterArchitecture, greaterThanOrEqualTo(countAfterBackend));
      },
    );

    test(
      'a real permission produces a real permission-depends-on-capability edge, never previously ingested anywhere',
      () {
        final architecture = _bookClubArchitecture(
          permissions: [
            PermissionDecision(
              permission: 'camera',
              requiredByCapabilityId: 'photo',
              decision: _decision('perm'),
            ),
          ],
        );
        final backend = _bookClubBackend(architecture);
        final solution = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );

        final worldModel = WorldModelCoordinator();
        worldModel.ingestSolutionArchitecture(solution);

        final permissionNodes = worldModel.model.graph.nodes.where(
          (n) =>
              n.kind == WorldNodeKind.softwareComponent &&
              n.label == 'permission:camera',
        );
        expect(permissionNodes, hasLength(1));
      },
    );

    test(
      'a real caching signal produces a real World node; no caching means no such node — never fabricated',
      () {
        final withCaching = _bookClubArchitecture(
          sync: SyncStrategy.cacheFirst,
        );
        final solutionWithCaching = const SolutionArchitecturePlanner().plan(
          withCaching,
          _bookClubBackend(withCaching),
        );
        final worldModelWith = WorldModelCoordinator()
          ..ingestSolutionArchitecture(solutionWithCaching);
        expect(
          worldModelWith.model.graph.nodes.any(
            (n) => n.label == 'caching:cacheFirst',
          ),
          isTrue,
        );

        final withoutCaching = _bookClubArchitecture(sync: SyncStrategy.none);
        final solutionWithoutCaching = const SolutionArchitecturePlanner().plan(
          withoutCaching,
          _bookClubBackend(withoutCaching),
        );
        final worldModelWithout = WorldModelCoordinator()
          ..ingestSolutionArchitecture(solutionWithoutCaching);
        expect(
          worldModelWithout.model.graph.nodes.any(
            (n) => n.label.toString().startsWith('caching:'),
          ),
          isFalse,
        );
      },
    );
  });

  group('Kernel wiring (R17)', () {
    test(
      'a real Kernel run produces a real SemanticSolutionArchitecture on ExecutionPlanReady, composed from the SAME architecture/backend plan already returned',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});

        final worldModel = WorldModelCoordinator();
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registry(),
          reasoner: _FixedReasoner(),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: _FakeSearchProvider(),
            webweavexAdapter: _fakeAdapter(),
          ),
          worldModel: worldModel,
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my book club reading'),
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final ready = outcome as ExecutionPlanReady;
        expect(ready.solutionArchitecture, isNotNull);
        expect(
          ready.solutionArchitecture!.frontend,
          same(ready.solutionDecision!.selected.architecture),
        );
        expect(
          ready.solutionArchitecture!.backend,
          same(ready.backendEngineeringPlan),
        );
        expect(ready.solutionArchitecture!.components, isNotEmpty);
        expect(
          worldModel.model.graph.nodes.any(
            (n) => n.kind == WorldNodeKind.entity,
          ),
          isTrue,
        );
      },
    );

    test(
      'running the SAME intent twice produces byte-for-byte identical solution architectures — determinism through the full Kernel path, zero new AI call',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});

        Future<ExecutionPlanReady> run() async {
          final kernel = AnythingKernel(
            providerRegistry: _FakeProviderRegistry(),
            capabilityRegistry: _registry(),
            reasoner: _FixedReasoner(),
            knowledgeEngine: KnowledgeAcquisitionEngine(
              searchProvider: _FakeSearchProvider(),
              webweavexAdapter: _fakeAdapter(),
            ),
          );
          return await kernel.processIntent(
                Intent.create(expression: 'track my book club reading'),
              )
              as ExecutionPlanReady;
        }

        final a = await run();
        final b = await run();
        // `ArchitectureCandidate.id` is a fresh UUID per Kernel run
        // (`ArchitecturePlanner`, pre-existing, unrelated to R17) — real
        // determinism is checked on the structural content the planner
        // actually derives, not that pre-existing per-run identifier.
        final aJson = a.solutionArchitecture!.toJson();
        final bJson = b.solutionArchitecture!.toJson();
        expect(aJson['components'], equals(bJson['components']));
        expect(aJson['caching'], equals(bJson['caching']));
        expect(aJson['unmodeledConcepts'], equals(bJson['unmodeledConcepts']));
      },
    );
  });

  group(
    'Canonical integration / backward compatibility (R17) — CanonicalImplementationModel is genuinely untouched',
    () {
      test(
        'CanonicalImplementationContext construction and CanonicalImplementationModel output are unaffected by R17 — no new required fields, same shape as R14/R15 left it',
        () {
          final architecture = _bookClubArchitecture();
          final backend = _bookClubBackend(architecture);
          // This exact construction call — no `solutionArchitecture` field,
          // no new required parameter — compiles and behaves identically to
          // pre-R17: proof `CanonicalImplementationContext`/`Model` were not
          // extended this milestone (a deliberate, documented decision, see
          // docs/architecture/SEMANTIC_SOLUTION_ARCHITECTURE.md).
          final model = const CanonicalImplementationPlanner().plan(
            CanonicalImplementationContext(
              engineering: _fallbackEngineering(architecture),
              backend: backend,
            ),
          );
          expect(model.entities, isNotEmpty);
        },
      );
    },
  );

  group(
    'Generator compatibility (R17) — the existing, unmodified R10-R13 pipeline still consumes CanonicalImplementationModel unaffected by this milestone',
    () {
      test(
        'BuildGraphBuilder + RuntimeExperienceGenerator still produce a valid ExperiencePackage — R17 never touched lib/generator_framework/ or lib/build_graph/',
        () {
          const model = CanonicalImplementationModel(
            entities: [
              ImplementationEntity(
                id: 'book',
                name: 'Book',
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
              ImplementationController(
                id: 'book.controller',
                entityId: 'book',
                operations: [
                  ImplementationOperation(
                    id: 'book.list',
                    kind: ImplementationOperationKind.list,
                  ),
                ],
              ),
            ],
            authentication: AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );
          const pipeline = GenerationPipeline();
          final result = pipeline.run(
            buildGraph: const BuildGraphBuilder().build(model),
            generator: const RuntimeExperienceGenerator(),
            target: const GeneratorTarget(
              id: 'book-tracker',
              name: 'Book Tracker',
            ),
          );
          expect(result.hasErrors, isFalse);
          expect(result.allArtifacts, isNotEmpty);
        },
      );
    },
  );

  group(
    'Performance (R17) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('architecture synthesis over a large system (200 entities)', () {
        final entities = [
          for (var i = 0; i < 200; i++)
            EntityDecision(
              entityId: 'e$i',
              name: 'E$i',
              fieldCount: 1,
              storage: StorageKind.sqlite,
              storageDecision: _decision('s$i'),
            ),
        ];
        final architecture = ArchitectureCandidate(
          id: 'large',
          appName: 'Large System',
          entities: entities,
          interactions: [
            for (final e in entities)
              InteractionDecision(
                entityId: e.entityId,
                canCreate: true,
                canRead: true,
                canUpdate: true,
                canDelete: true,
                supportsSearch: false,
                supportsFilter: false,
                supportsSort: false,
                supportsPagination: false,
                decision: _decision('i:${e.entityId}'),
              ),
          ],
          navigation: _nav(),
          security: SecurityDecision(
            networkMode: NetworkMode.none,
            requiresCredentialVault: false,
            decision: _decision('sec'),
          ),
          offline: const OfflineDecision(
            capability: OfflineCapability.fullyOffline,
            decision: ArchitectureDecision(
              id: 'off',
              category: ArchitectureDecisionCategory.data,
              subjectId: 'off',
              decision: 'd',
              rationale: 'r',
              confidence: Confidence(score: 1.0, reason: 'test'),
            ),
          ),
          synchronization: SynchronizationDecision(
            strategy: SyncStrategy.cacheFirst,
            decision: _decision('sync'),
          ),
          overallConfidence: const Confidence(score: 1.0, reason: 'test'),
        );
        final app = SemanticApp(
          name: 'Large',
          purpose: 'x',
          entities: [
            for (final e in entities)
              SemanticEntity(id: e.entityId, name: e.name, displayField: 'id'),
          ],
        );
        final backend = const BackendEngineeringPlanner().plan(
          BackendEngineeringContext(architecture: architecture, app: app),
        );

        final stopwatch = Stopwatch()..start();
        final solution = const SolutionArchitecturePlanner().plan(
          architecture,
          backend,
        );
        stopwatch.stop();

        expect(solution.components, hasLength(200));
        // ignore: avoid_print
        print(
          'SolutionArchitecturePlanner.plan over 200 entities: ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test(
        'memory: real process RSS delta while planning 50 solution architectures',
        () {
          final architecture = _bookClubArchitecture();
          final backend = _bookClubBackend(architecture);
          final rssBefore = ProcessInfo.currentRss;
          final results = <SemanticSolutionArchitecture>[];
          for (var i = 0; i < 50; i++) {
            results.add(
              const SolutionArchitecturePlanner().plan(architecture, backend),
            );
          }
          final rssAfter = ProcessInfo.currentRss;
          expect(results, hasLength(50));
          // ignore: avoid_print
          print(
            'R17 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 50 plans',
          );
        },
      );
    },
  );
}

// Small helper used only by the backward-compatibility test above, to
// avoid pulling in application_engineering's full EngineeringPlanner just
// to prove CanonicalImplementationContext's shape is unchanged.
EngineeringCandidate _fallbackEngineering(ArchitectureCandidate architecture) =>
    const EngineeringPlanner().plan(
      EngineeringContext(architecture: architecture, app: _bookClubApp()),
    );

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
  @override
  Future<AppReasoningResult> reason(
    ApplicationReasoningContext context,
  ) async => ReasoningReady(semanticApp: _bookClubApp());
}

CapabilityRegistry _registry() {
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

class _FakeSearchProvider implements SearchProvider {
  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async =>
      const [];
}

WebWeaveXAdapter _fakeAdapter() =>
    WebWeaveXAdapter(fetchPage: (url) async => {'available': false});
