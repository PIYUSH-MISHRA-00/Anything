/// V2 ASAE — KnowledgeGraphBuilder tests: provenance must never be lost.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/software_architect/knowledge_graph.dart';

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

void main() {
  test('empty bundle produces the empty graph', () {
    final bundle = KnowledgeBundle(
      id: 'b',
      status: BundleStatus.ready,
      resources: const [],
      generatedAt: DateTime.now(),
    );
    final graph = KnowledgeGraphBuilder.build(bundle);
    expect(graph.isEmpty, isTrue);
    expect(graph.nodes, isEmpty);
  });

  test(
    'every node preserves provenance/license/trust/relevance from its resource',
    () {
      final resource = _resource(
        id: 'r1',
        title: 'Amortization Formulas',
        sourceUri: 'https://finance.example.com/amortization',
      );
      final bundle = KnowledgeBundle(
        id: 'b',
        status: BundleStatus.ready,
        resources: [resource],
        generatedAt: DateTime.now(),
      );

      final graph = KnowledgeGraphBuilder.build(bundle);

      expect(graph.nodes, hasLength(1));
      final node = graph.nodes.single;
      expect(node.resourceId, 'r1');
      expect(node.sourceUri, resource.sourceUri);
      expect(node.provenance.sourceUrl, resource.provenance.sourceUrl);
      expect(node.provenance.provider, 'webweavex');
      expect(node.license.policy, resource.license.policy);
      expect(node.trust.level, resource.trust.level);
      expect(node.relevance, resource.ranking.overallScore);
    },
  );

  test(
    'resources sharing a capitalized concept in their titles are linked',
    () {
      final bundle = KnowledgeBundle(
        id: 'b',
        status: BundleStatus.ready,
        resources: [
          _resource(
            id: 'r1',
            title: 'Amortization Basics',
            sourceUri: 'https://a.example.com/',
          ),
          _resource(
            id: 'r2',
            title: 'Advanced Amortization',
            sourceUri: 'https://b.example.com/',
          ),
          _resource(
            id: 'r3',
            title: 'Unrelated Topic',
            sourceUri: 'https://c.example.com/',
          ),
        ],
        generatedAt: DateTime.now(),
      );

      final graph = KnowledgeGraphBuilder.build(bundle);

      expect(graph.links.any((l) => l.sharedConcept == 'amortization'), isTrue);
      expect(
        graph.links.where(
          (l) =>
              (l.fromResourceId == 'r1' || l.toResourceId == 'r1') &&
              (l.fromResourceId == 'r3' || l.toResourceId == 'r3'),
        ),
        isEmpty,
      );
    },
  );

  test('allConcepts and nodesForConcept are queryable', () {
    final bundle = KnowledgeBundle(
      id: 'b',
      status: BundleStatus.ready,
      resources: [
        _resource(
          id: 'r1',
          title: 'Garden Planning Guide',
          sourceUri: 'https://a.example.com/',
        ),
      ],
      generatedAt: DateTime.now(),
    );
    final graph = KnowledgeGraphBuilder.build(bundle);

    expect(graph.allConcepts, contains('garden'));
    expect(graph.nodesForConcept('garden'), hasLength(1));
    expect(graph.nodesForConcept('nonexistent'), isEmpty);
  });
}
