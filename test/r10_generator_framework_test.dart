/// Implementation Milestone R10 — Universal Generator Framework. Proves
/// the ONE canonical, language-independent `Generator` interface and its
/// reference implementation (`SummaryManifestGenerator`) correctly
/// consume a real `CanonicalImplementationModel` (R9) end-to-end. Zero
/// new AI call. The reference generator is deliberately minimal — never
/// a production Flutter/backend/web/desktop/mobile generator (this
/// milestone's own explicit scope boundary).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/build_graph/universal_build_graph.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/generator_framework/artifact.dart';
import 'package:anything/generator_framework/generation_pipeline.dart';
import 'package:anything/generator_framework/generation_result.dart';
import 'package:anything/generator_framework/generator.dart';
import 'package:anything/generator_framework/reference/summary_manifest_generator.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/implementation_model/canonical_implementation_planner.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── A small, direct CanonicalImplementationModel fixture — sufficient
// for testing the Generator Framework's OWN logic (R9 already exhaustively
// proves CIM's own construction fidelity elsewhere). ──

CanonicalImplementationModel _twoEntityModel() {
  return const CanonicalImplementationModel(
    entities: [
      ImplementationEntity(
        id: 'task',
        name: 'Task',
        fields: [
          ImplementationField(id: 'task.title', name: 'title', type: ImplementationDataType.text, required: true),
          ImplementationField(id: 'task.done', name: 'done', type: ImplementationDataType.boolean),
        ],
      ),
      ImplementationEntity(id: 'tag', name: 'Tag', fields: [ImplementationField(id: 'tag.label', name: 'label', type: ImplementationDataType.text, required: true)]),
    ],
    services: [ImplementationService(id: 'task.service', entityId: 'task', repositoryId: 'task.repository', controllerId: 'task.controller')],
    authentication: AuthenticationAdapterSpec(requiresCredentials: false),
    backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
  );
}

CanonicalImplementationModel _emptyModel() => const CanonicalImplementationModel(
  authentication: AuthenticationAdapterSpec(requiresCredentials: false),
  backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
);

// ── Minimal real fixture chain proving a genuine, real, R9-derived
// CanonicalImplementationModel (not hand-built) also flows through the
// framework correctly — matching R9's own "Vehicle Fleet Maintenance Log"
// novel-domain fixture, reused deliberately per R9's own precedent since
// this milestone is R9's direct successor. ──

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

SemanticApp _fleetApp() => const SemanticApp(
  name: 'Vehicle Fleet Maintenance Log',
  purpose: 'Track vehicles and their maintenance records',
  entities: [
    SemanticEntity(
      id: 'vehicle',
      name: 'Vehicle',
      displayField: 'name',
      fields: [SemanticField(id: 'name', name: 'Name', type: BlueprintFieldType.text, required: true)],
    ),
  ],
);

ArchitectureCandidate _fleetArchitecture() => ArchitectureCandidate(
  id: 'fleet-candidate',
  appName: 'Vehicle Fleet Maintenance Log',
  entities: [
    EntityDecision(
      entityId: 'vehicle',
      name: 'Vehicle',
      fieldCount: 1,
      storage: StorageKind.sqlite,
      storageDecision: ArchitectureDecision(id: 's1', category: ArchitectureDecisionCategory.data, subjectId: 'vehicle', decision: 'sqlite', rationale: 'r', confidence: const Confidence(score: 1.0, reason: 'test')),
    ),
  ],
  relationships: const [],
  navigation: NavigationGraph(entryScreenId: 'vehicles', screenIds: const ['vehicles'], edges: const [], decision: _decision('nav')),
  interactions: [InteractionDecision(entityId: 'vehicle', canCreate: true, canRead: true, canUpdate: true, canDelete: true, supportsSearch: false, supportsFilter: false, supportsSort: false, supportsPagination: false, decision: _decision('int'))],
  security: SecurityDecision(networkMode: NetworkMode.none, requiresCredentialVault: false, decision: _decision('sec')),
  offline: OfflineDecision(capability: OfflineCapability.fullyOffline, decision: _decision('off')),
  synchronization: SynchronizationDecision(strategy: SyncStrategy.none, decision: _decision('sync')),
  overallConfidence: const Confidence(score: 1.0, reason: 'test'),
);

CanonicalImplementationModel _realFleetModel() {
  final architecture = _fleetArchitecture();
  final backend = const BackendEngineeringPlanner().plan(BackendEngineeringContext(architecture: architecture, app: _fleetApp()));
  final engineering = const EngineeringPlanner().plan(EngineeringContext(architecture: architecture, app: _fleetApp()));
  return const CanonicalImplementationPlanner().plan(
    CanonicalImplementationContext(
      engineering: engineering,
      backend: backend,
      resolvedCapabilities: const [
        CapabilityDescriptor(id: 'storage', version: '1.0.0', name: 'Storage', description: 'Local storage', category: CapabilityCategory.storage, inputContract: 'data', outputContract: 'stored data'),
      ],
    ),
  );
}

void main() {
  group('Generator interface conformance (R10)', () {
    test('SummaryManifestGenerator implements the ONE canonical Generator interface with real, non-empty metadata', () {
      const generator = SummaryManifestGenerator();
      expect(generator, isA<Generator>());
      expect(generator.metadata.id, isNotEmpty);
      expect(generator.metadata.capabilities, isNotEmpty);
    });
  });

  group('Real end-to-end pipeline (R10)', () {
    test('a real CanonicalImplementationModel produces real, correct, inspectable artifacts — never a fabricated placeholder', () {
      const pipeline = GenerationPipeline();
      final result = pipeline.run(
        buildGraph: const BuildGraphBuilder().build(_twoEntityModel()),
        generator: const SummaryManifestGenerator(),
        target: const GeneratorTarget(id: 'reference', name: 'Reference'),
      );

      expect(result.hasErrors, isFalse);
      expect(result.allArtifacts, hasLength(3)); // 2 entity summaries + 1 manifest
      final taskSummary = result.allArtifacts.firstWhere((a) => a.id == 'task.summary');
      expect(taskSummary.content, contains('title (text, required)'));
      expect(taskSummary.content, contains('done (boolean)'));
      final manifest = result.allArtifacts.firstWhere((a) => a.id == 'manifest');
      expect(manifest.content, contains('Entities: 2'));
    });

    test('a real, R9-derived CanonicalImplementationModel (not hand-built) also flows through the framework correctly', () {
      const pipeline = GenerationPipeline();
      final model = _realFleetModel();
      expect(model.entities, isNotEmpty, reason: 'sanity: the real fixture chain actually produced entities');

      final result = pipeline.run(buildGraph: const BuildGraphBuilder().build(model), generator: const SummaryManifestGenerator(), target: const GeneratorTarget(id: 'reference', name: 'Reference'));

      expect(result.hasErrors, isFalse);
      expect(result.allArtifacts, isNotEmpty);
      expect(result.allArtifacts.any((a) => a.path == 'summary/vehicle.txt'), isTrue);
    });

    test('an empty model produces an honest diagnostic, never a crash or a fabricated artifact', () {
      const pipeline = GenerationPipeline();
      final result = pipeline.run(buildGraph: const BuildGraphBuilder().build(_emptyModel()), generator: const SummaryManifestGenerator(), target: const GeneratorTarget(id: 'reference', name: 'Reference'));

      expect(result.allArtifacts, isEmpty);
      expect(result.diagnostics, isNotEmpty);
      expect(result.diagnostics.first.severity, DiagnosticSeverity.info);
    });
  });

  group('Determinism (R10)', () {
    test('running the SAME model through the pipeline twice produces byte-for-byte identical artifacts — zero new AI call', () {
      const pipeline = GenerationPipeline();
      const target = GeneratorTarget(id: 'reference', name: 'Reference');
      final model = _twoEntityModel();
      final buildGraph = const BuildGraphBuilder().build(model);

      final r1 = pipeline.run(buildGraph: buildGraph, generator: const SummaryManifestGenerator(), target: target);
      final r2 = pipeline.run(buildGraph: buildGraph, generator: const SummaryManifestGenerator(), target: target);

      expect(r1.allArtifacts.length, r2.allArtifacts.length);
      for (var i = 0; i < r1.allArtifacts.length; i++) {
        expect(r1.allArtifacts[i].content, r2.allArtifacts[i].content);
        expect(r1.allArtifacts[i].path, r2.allArtifacts[i].path);
      }
    });
  });

  group('Artifact/ArtifactGroup/GenerationResult field fidelity (R10)', () {
    test('real construction round-trips every field', () {
      const artifact = Artifact(id: 'a1', path: 'x/y.txt', kind: ArtifactKind.file, content: 'hello');
      expect(artifact.id, 'a1');
      expect(artifact.path, 'x/y.txt');
      expect(artifact.kind, ArtifactKind.file);
      expect(artifact.content, 'hello');

      const group = ArtifactGroup(id: 'g1', artifacts: [artifact]);
      expect(group.artifacts.single, artifact);

      const result = GenerationResult(artifactGroups: [group], diagnostics: [GenerationDiagnostic(severity: DiagnosticSeverity.warning, category: DiagnosticCategory.skippedFeature, message: 'm')]);
      expect(result.allArtifacts.single, artifact);
      expect(result.hasErrors, isFalse);
    });

    test('a real error-severity diagnostic makes hasErrors true', () {
      const result = GenerationResult(diagnostics: [GenerationDiagnostic(severity: DiagnosticSeverity.error, category: DiagnosticCategory.general, message: 'm')]);
      expect(result.hasErrors, isTrue);
    });
  });

  group('Performance (R10)', () {
    test('generating a large (200-entity) model stays correct and reports real elapsed time', () {
      final entities = List.generate(
        200,
        (i) => ImplementationEntity(id: 'e$i', name: 'Entity$i', fields: [ImplementationField(id: 'e$i.f', name: 'field', type: ImplementationDataType.text)]),
      );
      final model = CanonicalImplementationModel(
        entities: entities,
        authentication: const AuthenticationAdapterSpec(requiresCredentials: false),
        backgroundWorker: const BackgroundWorkerSpec(requiresBackgroundSync: false),
      );
      const pipeline = GenerationPipeline();

      final stopwatch = Stopwatch()..start();
      final result = pipeline.run(buildGraph: const BuildGraphBuilder().build(model), generator: const SummaryManifestGenerator(), target: const GeneratorTarget(id: 'reference', name: 'Reference'));
      stopwatch.stop();

      expect(result.allArtifacts, hasLength(201)); // 200 entity summaries + 1 manifest
      // ignore: avoid_print
      print('SummaryManifestGenerator over 200 entities: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
