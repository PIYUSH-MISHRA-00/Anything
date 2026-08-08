/// Implementation Milestone R2 — Knowledge -> KnowledgeGraph -> World
/// Graph. Closes MIS-1 Part 2's finding that `ingestKnowledge` had zero
/// real call sites. Reuses the existing, already-tested
/// `KnowledgeGraphBuilder`/`KnowledgeGraphBridge`/`WorldModelCoordinator`
/// machinery — this file proves the WIRING, not a new conversion engine.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/software_architect/knowledge_graph.dart';
import 'package:anything/software_cognition/semantic_software_graph.dart';
import 'package:anything/software_cognition/software_identity.dart';
import 'package:anything/software_cognition/software_node.dart';
import 'package:anything/software_cognition/software_types.dart' as sc;
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/bridges/knowledge_graph_bridge.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

KnowledgeResource _resource({
  required String id,
  required String title,
  required String sourceUri,
}) {
  final now = DateTime.now();
  return KnowledgeResource(
    id: id,
    type: KnowledgeResourceType.webDocument,
    title: title,
    sourceUri: sourceUri,
    sourceDomain: Uri.parse(sourceUri).host,
    retrievedAt: now,
    content: 'content for $title',
    contentHash: 'hash-$id',
    provenance: ResourceProvenance(
      sourceUrl: sourceUri,
      sourceDomain: Uri.parse(sourceUri).host,
      retrievedAt: now,
      provider: 'webweavex',
    ),
    license: const LicenseMetadata(
      policy: LicensePolicy.unknownReviewRequired,
      confidence: 0.5,
    ),
    trust: const TrustMetadata(
      level: TrustLevel.unknown,
      reason: 'web',
      confidence: 0.5,
    ),
    freshness: const FreshnessMetadata(),
    ranking: const RankingMetadata(
      relevanceScore: 0.7,
      authorityScore: 0.6,
      freshnessScore: 0.5,
    ),
  );
}

KnowledgeGraph _graphOf(List<KnowledgeResource> resources) =>
    KnowledgeGraphBuilder.build(
      KnowledgeBundle(
        id: 'b',
        status: BundleStatus.ready,
        resources: resources,
        generatedAt: DateTime.now(),
      ),
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

SemanticApp _fieldSurveyApp() {
  return SemanticApp(
    name: 'Field Survey Log',
    purpose: 'Track field survey entries',
    entities: [
      const SemanticEntity(
        id: 'entry',
        name: 'Entry',
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
    views: const [
      SemanticView(
        id: 'entries_list',
        name: 'Entries',
        purpose: 'list',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_entry',
        name: 'Add Entry',
        targetEntityId: 'entry',
      ),
    ],
  );
}

/// Requests knowledge exactly once (round 0), then produces a real
/// SemanticApp once knowledge has been supplied — exercising the SAME
/// `_reasonWithKnowledgeLoop` round-trip real production traffic uses,
/// never a shortcut.
class _KnowledgeRequestingReasoner implements ApplicationReasoner {
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    if (context.knowledge == null) {
      return const ReasoningKnowledgeRequired(
        requirements: [
          SynthesisKnowledgeRequirement(
            id: 'k1',
            purpose: 'domain grounding',
            query: 'field survey best practices',
            required: true,
          ),
        ],
      );
    }
    return ReasoningReady(semanticApp: _fieldSurveyApp());
  }
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
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    return [
      const SearchResult(
        title: 'Field Survey Guide',
        url: 'https://survey.example.com/guide',
      ),
    ];
  }
}

WebWeaveXAdapter _fakeAdapter() {
  return WebWeaveXAdapter(
    fetchPage: (url) async => {
      'available': true,
      'html':
          '<html><head><title>Field Survey Guide</title></head><body><p>Best practices for field surveys.</p></body></html>',
    },
  );
}

void main() {
  group('KnowledgeGraphBridge identity (R2)', () {
    test(
      'the same URL bridged twice resolves to the same EntityIdentity — never a fresh id per fetch',
      () {
        final r1 = _resource(
          id: 'wwx-1000',
          title: 'Amortization',
          sourceUri: 'https://finance.example.com/amortization',
        );
        final r2 = _resource(
          id: 'wwx-2000',
          title: 'Amortization',
          sourceUri: 'https://finance.example.com/amortization',
        );

        final update1 = const KnowledgeGraphBridge().bridge(_graphOf([r1]));
        final update2 = const KnowledgeGraphBridge().bridge(_graphOf([r2]));

        expect(
          update1.addedNodes.single.identity,
          update2.addedNodes.single.identity,
        );
      },
    );

    test(
      'repeated acquisition of the same URL does not duplicate the World Graph node',
      () {
        final coordinator = WorldModelCoordinator();
        coordinator.ingestKnowledge(
          _graphOf([
            _resource(
              id: 'wwx-1',
              title: 'Amortization',
              sourceUri: 'https://finance.example.com/amortization',
            ),
          ]),
        );
        coordinator.ingestKnowledge(
          _graphOf([
            _resource(
              id: 'wwx-2',
              title: 'Amortization',
              sourceUri: 'https://finance.example.com/amortization',
            ),
          ]),
        );

        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.knowledge),
          hasLength(1),
        );
      },
    );

    test('two different URLs produce two distinct nodes', () {
      final coordinator = WorldModelCoordinator();
      coordinator.ingestKnowledge(
        _graphOf([
          _resource(
            id: 'wwx-1',
            title: 'Amortization',
            sourceUri: 'https://finance.example.com/amortization',
          ),
          _resource(
            id: 'wwx-2',
            title: 'Depreciation',
            sourceUri: 'https://finance.example.com/depreciation',
          ),
        ]),
      );

      expect(
        coordinator.model.graph.nodesOfKind(WorldNodeKind.knowledge),
        hasLength(2),
      );
    });

    test(
      'the same URL re-observed with a different title is an honest, documented conflict, not silent duplication or overwrite',
      () {
        final coordinator = WorldModelCoordinator();
        coordinator.ingestKnowledge(
          _graphOf([
            _resource(
              id: 'wwx-1',
              title: 'Amortization v1',
              sourceUri: 'https://finance.example.com/amortization',
            ),
          ]),
        );
        final versionAfterFirst = coordinator.model.version.number;

        // REALITY (Implementation Milestone R2, not changed here): ingestion
        // routes through the existing, unmodified WorldPlanner all-or-nothing
        // gate. A real GraphConflict (same identity, different label) means
        // the whole update is rejected — the graph is left exactly as it was
        // after the first ingestion. This is pre-existing World Model policy
        // (Vision Milestone V9), re-verified here through real Knowledge
        // usage, not altered by R2.
        coordinator.ingestKnowledge(
          _graphOf([
            _resource(
              id: 'wwx-2',
              title: 'Amortization v2 (retitled)',
              sourceUri: 'https://finance.example.com/amortization',
            ),
          ]),
        );

        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.knowledge),
          hasLength(1),
        );
        expect(
          coordinator.model.graph
              .nodesOfKind(WorldNodeKind.knowledge)
              .single
              .label,
          'Amortization v1',
        );
        expect(
          coordinator.model.version.number,
          versionAfterFirst,
          reason: 'a rejected update must never bump the version',
        );
      },
    );
  });

  group('Kernel -> World Graph wiring (R2)', () {
    test(
      'a real Kernel run with a shared WorldModelCoordinator ingests real, network-free-fetched knowledge into the World Graph',
      () async {
        final worldModel = WorldModelCoordinator();
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registry(),
          reasoner: _KnowledgeRequestingReasoner(),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: _FakeSearchProvider(),
            webweavexAdapter: _fakeAdapter(),
          ),
          worldModel: worldModel,
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final knowledgeNodes = worldModel.model.graph.nodesOfKind(
          WorldNodeKind.knowledge,
        );
        expect(knowledgeNodes, isNotEmpty);
        expect(knowledgeNodes.first.label, 'Field Survey Guide');
      },
    );

    test(
      'omitting worldModel behaves exactly as before R2 — no crash, no change to the outcome',
      () async {
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registry(),
          reasoner: _KnowledgeRequestingReasoner(),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: _FakeSearchProvider(),
            webweavexAdapter: _fakeAdapter(),
          ),
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
        );

        expect(outcome, isA<ExecutionPlanReady>());
      },
    );

    test(
      'a Kernel run still succeeds even when the injected WorldModelCoordinator throws on ingestKnowledge',
      () async {
        final throwingModel = _ThrowingWorldModelCoordinator();
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registry(),
          reasoner: _KnowledgeRequestingReasoner(),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: _FakeSearchProvider(),
            webweavexAdapter: _fakeAdapter(),
          ),
          worldModel: throwingModel,
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
        );

        expect(
          outcome,
          isA<ExecutionPlanReady>(),
          reason:
              'a World Graph ingestion failure must never surface as a generation failure',
        );
        expect(throwingModel.ingestKnowledgeCalls, greaterThan(0));
      },
    );
  });

  group('Software Cognition and Knowledge share one World Graph (R2)', () {
    test(
      'ingesting Knowledge then a Software graph on ONE shared coordinator makes both visible together',
      () {
        final coordinator = WorldModelCoordinator();
        coordinator.ingestKnowledge(
          _graphOf([
            _resource(
              id: 'wwx-1',
              title: 'Amortization',
              sourceUri: 'https://finance.example.com/amortization',
            ),
          ]),
        );

        final repoIdentity = SoftwareIdentity.stable(
          sc.SoftwareNodeKind.repository,
          'example/repo',
        );
        final softwareGraph = SemanticSoftwareGraph(
          nodes: [
            SoftwareNode(
              identity: repoIdentity,
              kind: sc.SoftwareNodeKind.repository,
              label: 'example/repo',
            ),
          ],
          edges: const [],
        );
        coordinator.ingestSoftwareGraph(softwareGraph);

        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.knowledge),
          isNotEmpty,
        );
        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.repository),
          isNotEmpty,
        );
      },
    );
  });

  group('Performance (R2)', () {
    test(
      'ingesting a large, single-round KnowledgeGraph (300 distinct resources) stays correct and its real elapsed time is reported',
      () {
        final resources = List.generate(
          300,
          (i) => _resource(
            id: 'wwx-$i',
            title: 'Resource $i',
            sourceUri: 'https://example.com/r$i',
          ),
        );
        final coordinator = WorldModelCoordinator();

        final stopwatch = Stopwatch()..start();
        coordinator.ingestKnowledge(_graphOf(resources));
        stopwatch.stop();

        expect(
          coordinator.model.graph.nodesOfKind(WorldNodeKind.knowledge),
          hasLength(300),
        );
        // Real, measured elapsed time — never a fabricated benchmark or an
        // asserted SLA, matching the established stress-test convention.
        // ignore: avoid_print
        print(
          'ingestKnowledge over 300 distinct resources: ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );
  });
}

class _ThrowingWorldModelCoordinator implements WorldModelCoordinator {
  int ingestKnowledgeCalls = 0;

  @override
  void ingestKnowledge(KnowledgeGraph knowledgeGraph) {
    ingestKnowledgeCalls++;
    throw StateError('simulated World Graph failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
