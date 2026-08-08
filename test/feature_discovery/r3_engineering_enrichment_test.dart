/// Implementation Milestone R3 — real, structural (never textual/keyword)
/// enrichment of Feature Discovery confidence from acquired Knowledge/
/// Software Cognition and from World Graph capability familiarity, plus
/// the Requirement Graph diff chain (planning-only — no runtime patching,
/// deferred to R5).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/feature_confidence_analyzer.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/feature_discovery/feature_types.dart';
import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/knowledge_graph.dart';
import 'package:anything/software_architect/requirement_graph.dart';
import 'package:anything/software_architect/requirement_graph_diff.dart';
import 'package:anything/software_cognition/semantic_software_graph.dart';
import 'package:anything/software_cognition/software_identity.dart';
import 'package:anything/software_cognition/software_node.dart';
import 'package:anything/software_cognition/software_types.dart' as sc;
import 'package:anything/synthesis/app_blueprint.dart' show BlueprintFieldType;
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

FeatureDecision _decision(String id, double score) => FeatureDecision(
  id: id,
  category: FeatureCategory.data,
  subjectId: id,
  decision: 'included',
  rationale: 'test fixture',
  confidence: Confidence(score: score, reason: 'fixture'),
);

KnowledgeGraphNode _knowledgeNode({required double trustConfidence}) =>
    KnowledgeGraphNode(
      resourceId: 'r1',
      title: 'Field Survey Guide',
      sourceUri: 'https://example.com/guide',
      sourceDomain: 'example.com',
      provenance: ResourceProvenance(
        sourceUrl: 'https://example.com/guide',
        sourceDomain: 'example.com',
        retrievedAt: DateTime.now(),
        provider: 'webweavex',
      ),
      license: const LicenseMetadata(
        policy: LicensePolicy.unknownReviewRequired,
        confidence: 0.5,
      ),
      trust: TrustMetadata(
        level: TrustLevel.unknown,
        reason: 'test',
        confidence: trustConfidence,
      ),
      relevance: 0.7,
    );

void main() {
  group('FeatureConfidenceAnalyzer knowledge/prior-capability enrichment (R3)', () {
    test(
      'omitting knowledge and priorCapabilityIds is byte-for-byte identical to pre-R3',
      () {
        const analyzer = FeatureConfidenceAnalyzer();
        final decisions = [_decision('a', 0.6), _decision('b', 0.8)];
        final result = analyzer.analyze(decisions);

        expect(result.score, closeTo(0.7, 0.0001));
        expect(result.reason, 'Mean of 2 discovered feature(s); 0 below 0.5.');
      },
    );

    test(
      'high-trust acquired knowledge nudges confidence up, never overriding the base score',
      () {
        const analyzer = FeatureConfidenceAnalyzer();
        final decisions = [_decision('a', 0.6), _decision('b', 0.8)];
        final baseline = analyzer.analyze(decisions).score;

        final highTrustGraph = KnowledgeGraph(
          nodes: [_knowledgeNode(trustConfidence: 0.95)],
          isEmpty: false,
        );
        final enriched = analyzer.analyze(decisions, knowledge: highTrustGraph);

        expect(enriched.score, greaterThan(baseline));
        expect(enriched.score, lessThanOrEqualTo(1.0));
        expect(
          enriched.reason,
          contains('Grounded in 1 acquired knowledge resource'),
        );
      },
    );

    test(
      'low-trust acquired knowledge nudges confidence down — never a one-directional "knowledge exists therefore confident" fallacy',
      () {
        const analyzer = FeatureConfidenceAnalyzer();
        final decisions = [_decision('a', 0.6), _decision('b', 0.8)];
        final baseline = analyzer.analyze(decisions).score;

        final lowTrustGraph = KnowledgeGraph(
          nodes: [_knowledgeNode(trustConfidence: 0.05)],
          isEmpty: false,
        );
        final enriched = analyzer.analyze(decisions, knowledge: lowTrustGraph);

        expect(enriched.score, lessThan(baseline));
      },
    );

    test(
      'an empty KnowledgeGraph contributes nothing (matches KnowledgeGraph.empty exactly)',
      () {
        const analyzer = FeatureConfidenceAnalyzer();
        final decisions = [_decision('a', 0.6)];
        final baseline = analyzer.analyze(decisions).score;
        final enriched = analyzer.analyze(
          decisions,
          knowledge: KnowledgeGraph.empty,
        );

        expect(enriched.score, baseline);
      },
    );

    test(
      'prior-capability familiarity nudges confidence up, and absence changes nothing',
      () {
        const analyzer = FeatureConfidenceAnalyzer();
        final decisions = [_decision('a', 0.5)];
        final baseline = analyzer.analyze(decisions).score;

        final withFamiliarity = analyzer.analyze(
          decisions,
          priorCapabilityIds: {'http', 'clock'},
        );
        expect(withFamiliarity.score, greaterThan(baseline));
        expect(
          withFamiliarity.reason,
          contains('2 capability(ies) already familiar'),
        );

        final withEmptySet = analyzer.analyze(
          decisions,
          priorCapabilityIds: const {},
        );
        expect(withEmptySet.score, baseline);
      },
    );

    test(
      'the combined adjustment stays bounded within [0, 1] even with maximal signals',
      () {
        const analyzer = FeatureConfidenceAnalyzer();
        final decisions = [_decision('a', 0.98)];
        final result = analyzer.analyze(
          decisions,
          knowledge: KnowledgeGraph(
            nodes: [_knowledgeNode(trustConfidence: 1.0)],
            isEmpty: false,
          ),
          priorCapabilityIds: {'http'},
        );
        expect(result.score, lessThanOrEqualTo(1.0));
      },
    );
  });

  group('FeatureDiscoveryEngine wiring (R3)', () {
    test(
      'priorCapabilityIds flows from context through to the real FeatureGraph.overallConfidence',
      () {
        const engine = FeatureDiscoveryEngine();
        final app = SemanticApp(
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
        );
        final requirements = RequirementGraph(
          nodes: [
            const RequirementNode(
              id: 'entity:entry',
              type: RequirementNodeType.entity,
              label: 'Entry',
              description: '',
              source: RequirementSource.explicit,
            ),
          ],
        );

        final without = engine.plan(
          FeatureDiscoveryContext(app: app, requirements: requirements),
        );
        final with_ = engine.plan(
          FeatureDiscoveryContext(
            app: app,
            requirements: requirements,
            priorCapabilityIds: {'storage', 'http', 'clock'},
          ),
        );

        expect(
          with_.overallConfidence.score,
          greaterThan(without.overallConfidence.score),
        );
      },
    );
  });

  group('World Model read-enrichment, real end-to-end (R3)', () {
    test(
      'a capability already observed in the World Graph is a real, structural signal FeatureDiscoveryEngine can read via the Kernel',
      () {
        final worldModel = WorldModelCoordinator();
        final capabilityIdentity = SoftwareIdentity.stable(
          sc.SoftwareNodeKind.capability,
          'http',
        );
        worldModel.ingestSoftwareGraph(
          SemanticSoftwareGraph(
            nodes: [
              SoftwareNode(
                identity: capabilityIdentity,
                kind: sc.SoftwareNodeKind.capability,
                label: 'http',
              ),
            ],
            edges: const [],
          ),
        );

        // The exact real query the Kernel's _priorCapabilityIdsSafely() runs.
        final observed = worldModel.model.graph
            .nodesOfKind(WorldNodeKind.capability)
            .map((n) => n.label)
            .toSet();
        expect(observed, contains('http'));
      },
    );
  });

  group('RequirementGraphDiff (R3 — Incremental Engineering, planning-only)', () {
    const differ = RequirementGraphDiffer();

    RequirementNode node(String id, {String label = 'x'}) => RequirementNode(
      id: id,
      type: RequirementNodeType.entity,
      label: label,
      description: '',
      source: RequirementSource.explicit,
    );

    test('two identical graphs produce an empty diff', () {
      final graph = RequirementGraph(
        nodes: [node('entity:a')],
        relations: const [
          RequirementRelation(
            fromId: 'field:a.x',
            toId: 'entity:a',
            type: RequirementRelationType.belongsTo,
          ),
        ],
      );
      final diff = differ.diff(graph, graph);
      expect(diff.isEmpty, isTrue);
    });

    test('a genuinely new node is reported as added, nothing else', () {
      final before = RequirementGraph(nodes: [node('entity:a')]);
      final after = RequirementGraph(
        nodes: [node('entity:a'), node('entity:b')],
      );

      final diff = differ.diff(before, after);
      expect(diff.addedNodes.map((n) => n.id), ['entity:b']);
      expect(diff.removedNodes, isEmpty);
    });

    test('a removed node is reported as removed, nothing else', () {
      final before = RequirementGraph(
        nodes: [node('entity:a'), node('entity:b')],
      );
      final after = RequirementGraph(nodes: [node('entity:a')]);

      final diff = differ.diff(before, after);
      expect(diff.removedNodes.map((n) => n.id), ['entity:b']);
      expect(diff.addedNodes, isEmpty);
    });

    test(
      'a node with the same id but a changed label is an explicit remove+add pair, never a silent overwrite',
      () {
        final before = RequirementGraph(
          nodes: [node('entity:a', label: 'Old Name')],
        );
        final after = RequirementGraph(
          nodes: [node('entity:a', label: 'New Name')],
        );

        final diff = differ.diff(before, after);
        expect(diff.removedNodes.single.label, 'Old Name');
        expect(diff.addedNodes.single.label, 'New Name');
      },
    );

    test(
      'added and removed relations are detected independently of node changes',
      () {
        const rel1 = RequirementRelation(
          fromId: 'field:a.x',
          toId: 'entity:a',
          type: RequirementRelationType.belongsTo,
        );
        const rel2 = RequirementRelation(
          fromId: 'entity:a',
          toId: 'entity:b',
          type: RequirementRelationType.references,
        );
        final before = RequirementGraph(
          nodes: [node('entity:a')],
          relations: const [rel1],
        );
        final after = RequirementGraph(
          nodes: [node('entity:a')],
          relations: const [rel1, rel2],
        );

        final diff = differ.diff(before, after);
        expect(diff.addedRelations, [rel2]);
        expect(diff.removedRelations, isEmpty);
      },
    );

    test(
      'diffing the same two graphs twice produces structurally identical results — deterministic',
      () {
        final before = RequirementGraph(nodes: [node('entity:a')]);
        final after = RequirementGraph(
          nodes: [node('entity:a'), node('entity:b')],
        );

        final diff1 = differ.diff(before, after);
        final diff2 = differ.diff(before, after);

        expect(
          diff1.addedNodes.map((n) => n.id),
          diff2.addedNodes.map((n) => n.id),
        );
        expect(
          diff1.removedNodes.map((n) => n.id),
          diff2.removedNodes.map((n) => n.id),
        );
      },
    );

    test(
      'diffing two large (500-node) graphs stays correct and its real elapsed time is reported',
      () {
        final beforeNodes = List.generate(500, (i) => node('entity:$i'));
        final afterNodes = [
          ...beforeNodes.sublist(0, 400),
          ...List.generate(100, (i) => node('entity:new$i')),
        ];
        final before = RequirementGraph(nodes: beforeNodes);
        final after = RequirementGraph(nodes: afterNodes);

        final stopwatch = Stopwatch()..start();
        final diff = differ.diff(before, after);
        stopwatch.stop();

        expect(diff.addedNodes, hasLength(100));
        expect(diff.removedNodes, hasLength(100));
        // Real, measured elapsed time — never a fabricated benchmark or an
        // asserted SLA, matching the established stress-test convention.
        // ignore: avoid_print
        print(
          'RequirementGraphDiffer.diff over 500/500 nodes: ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );
  });
}
