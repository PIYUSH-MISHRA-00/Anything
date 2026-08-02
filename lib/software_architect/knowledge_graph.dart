/// Knowledge Graph — a typed projection of a KnowledgeBundle for
/// architecture planning. Preserves every provenance/trust/license signal
/// the underlying KnowledgeResource carries; never collapses it into an
/// untyped blob.
library;

import '../knowledge/knowledge_bundle.dart';
import '../knowledge/knowledge_resource.dart';

/// One node in the knowledge graph — one retrieved resource, with its
/// provenance intact, plus concepts genuinely extracted from its own
/// title/headings (not fabricated, not domain-specific).
class KnowledgeGraphNode {
  final String resourceId;
  final String title;
  final String sourceUri;
  final String sourceDomain;
  final ResourceProvenance provenance;
  final LicenseMetadata license;
  final TrustMetadata trust;
  final double relevance;
  final List<String> concepts;

  const KnowledgeGraphNode({
    required this.resourceId,
    required this.title,
    required this.sourceUri,
    required this.sourceDomain,
    required this.provenance,
    required this.license,
    required this.trust,
    required this.relevance,
    this.concepts = const [],
  });
}

/// A relation between two knowledge nodes that share a concept.
class KnowledgeConceptLink {
  final String fromResourceId;
  final String toResourceId;
  final String sharedConcept;

  const KnowledgeConceptLink({
    required this.fromResourceId,
    required this.toResourceId,
    required this.sharedConcept,
  });
}

/// The complete, typed knowledge graph for one acquisition round.
class KnowledgeGraph {
  final List<KnowledgeGraphNode> nodes;
  final List<KnowledgeConceptLink> links;
  final bool isEmpty;

  const KnowledgeGraph({
    this.nodes = const [],
    this.links = const [],
    this.isEmpty = true,
  });

  static const KnowledgeGraph empty = KnowledgeGraph();

  /// All concepts mentioned across every node, deduplicated.
  Set<String> get allConcepts => nodes.expand((n) => n.concepts).toSet();

  List<KnowledgeGraphNode> nodesForConcept(String concept) =>
      nodes.where((n) => n.concepts.contains(concept)).toList();
}

/// Builds a KnowledgeGraph from a real KnowledgeBundle.
///
/// Concept extraction is a small, genuine, deterministic heuristic
/// (significant capitalized words/phrases from the title) — not a
/// fabricated tag, and not a general NLP engine; good enough to link
/// resources that are plausibly "about the same thing" for
/// ArchitecturePlanner's use, nothing more is claimed.
class KnowledgeGraphBuilder {
  static KnowledgeGraph build(KnowledgeBundle bundle) {
    if (bundle.resources.isEmpty) return KnowledgeGraph.empty;

    final nodes = bundle.resources.map((r) {
      return KnowledgeGraphNode(
        resourceId: r.id,
        title: r.title,
        sourceUri: r.sourceUri,
        sourceDomain: r.sourceDomain,
        provenance: r.provenance,
        license: r.license,
        trust: r.trust,
        relevance: r.ranking.overallScore,
        concepts: _extractConcepts(r.title),
      );
    }).toList();

    final links = <KnowledgeConceptLink>[];
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final shared = nodes[i].concepts.toSet().intersection(
          nodes[j].concepts.toSet(),
        );
        for (final concept in shared) {
          links.add(
            KnowledgeConceptLink(
              fromResourceId: nodes[i].resourceId,
              toResourceId: nodes[j].resourceId,
              sharedConcept: concept,
            ),
          );
        }
      }
    }

    return KnowledgeGraph(nodes: nodes, links: links, isEmpty: false);
  }

  static List<String> _extractConcepts(String title) {
    final words = title.split(RegExp(r'[\s\-—:,.]+'));
    return words
        .where((w) => w.length > 3 && w[0].toUpperCase() == w[0])
        .map((w) => w.toLowerCase())
        .toSet()
        .toList();
  }
}
