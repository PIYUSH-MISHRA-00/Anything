/// RepositoryAnalyzer — translates WebWeaveX's own already-computed,
/// deterministic repository IR (`compileRepository`/`queryRepository`,
/// `package:webweavex`) into a strongly-typed RepositoryModel. Performs
/// no parsing, crawling, or extraction of its own — WebWeaveX remains the
/// only acquisition/parsing engine (Vision Milestone V11's mandatory
/// constraint). Acquisition (fetching a URL into source text) is a thin,
/// separate, injectable step reusing the exact `wwx.renderPage` /
/// `wwx.extractSemanticContent` primitives `WebWeaveXAdapter` already
/// uses — never a second HTTP client.
library;

import 'package:webweavex/webweavex.dart' as wwx;

import 'repository_model.dart';
import 'semantic_software_graph.dart';
import 'software_identity.dart';
import 'software_node.dart';
import 'software_provenance.dart';
import 'software_types.dart';

/// A short, honest, non-exhaustive list of well-known framework
/// dependency names — WebWeaveX's own internal framework-resolution
/// heuristic is not part of its public API surface, so this derives
/// frameworks from WebWeaveX's own already-computed dependency list
/// rather than re-parsing source (never a second parser).
const Set<String> _knownFrameworks = {
  'flutter',
  'react',
  'next',
  'express',
  'nestjs',
  '@angular/core',
  'django',
  'flask',
  'fastapi',
  'spring-boot',
  'spring',
  'tokio',
  'actix-web',
  'gin',
  'echo',
};

Map<String, dynamic> _asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<String> _asStringList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

/// Fetches a page and returns WebWeaveX's `renderPage` shape, matching
/// `WebWeaveXAdapter.PageFetcher` exactly so both share one real HTTP
/// path in production and one fake in tests.
typedef PageFetcher = Future<Map<String, dynamic>> Function(String url);

class RepositoryAnalyzer {
  final PageFetcher _fetchPage;

  RepositoryAnalyzer({PageFetcher? fetchPage}) : _fetchPage = fetchPage ?? wwx.renderPage;

  /// Core, network-free translation: real acquired source text (and
  /// optionally a file-path listing, for infra/CI/test detection) in,
  /// typed RepositoryModel out.
  RepositoryModel analyze(RepositoryContext context) {
    final ir = wwx.compileRepository(context.source, path: context.path, files: context.files);
    final raw = _asMap(ir['raw'] ?? ir['_raw']);
    final language = (raw['language'] as String?) ?? 'text';
    final dependencies = _asStringList(ir['dependencies']);
    final infra = _asStringList(ir['infra']);
    final symbols = _asMap(raw['symbols']);
    final classNames = _asStringList(symbols['classes']);
    final functionNames = _asStringList(symbols['functions']);
    final decorators = _asStringList(symbols['decorators']);

    final execution = _asMap(raw['execution']);
    final executionFlow = _asMap(execution['execution_flow']);
    final entrypoints = _asStringList(executionFlow['entrypoints']);

    final services = _asMap(raw['services']);
    final serviceNodes = _asStringList(services['nodes']);
    final serviceEdgesRaw = services['edges'] is List ? services['edges'] as List : const [];

    final confidenceMap = _asMap(ir['confidence']);
    final confidenceScore = (confidenceMap['score'] as num?)?.toDouble() ?? 0.0;
    final confidenceBasis = _asStringList(confidenceMap['basis']);

    final frameworks = dependencies.map((d) => d.toLowerCase()).where(_knownFrameworks.contains).toList()..sort();

    final structure = RepositoryStructure(
      entries: context.files.map((f) => RepositoryNode(path: f, isDirectory: f.endsWith('/'))).toList(),
    );

    final summary = RepositorySummary(
      purpose: context.metadata.description.isNotEmpty ? context.metadata.description : context.metadata.name,
      primaryLanguage: language,
      dependencyCount: dependencies.length,
      entrypointCount: entrypoints.length,
      hasTests: structure.hasTests,
      hasCi: structure.hasCi || infra.any((f) => f.contains('.github/workflows')),
      hasDocker: structure.hasDocker || infra.any((f) => f.toLowerCase().contains('docker')),
    );

    final repoIdentity = SoftwareIdentity.stable(SoftwareNodeKind.repository, context.metadata.name);
    final nodes = <SoftwareNode>[SoftwareNode(identity: repoIdentity, kind: SoftwareNodeKind.repository, label: context.metadata.name)];
    final edges = <SoftwareEdge>[];
    final evidence = SoftwareEvidence(sourceUrl: context.metadata.provenance.sourceUrl, sourceArtifact: context.path);

    for (final dep in dependencies) {
      final depIdentity = SoftwareIdentity.stable(SoftwareNodeKind.package, dep);
      nodes.add(SoftwareNode(identity: depIdentity, kind: SoftwareNodeKind.package, label: dep));
      edges.add(SoftwareEdge(fromId: repoIdentity, toId: depIdentity, kind: SoftwareRelationshipKind.dependsOn, evidence: evidence));
    }

    for (final serviceNode in serviceNodes) {
      final nodeIdentity = SoftwareIdentity.stable(SoftwareNodeKind.component, serviceNode);
      nodes.add(SoftwareNode(identity: nodeIdentity, kind: SoftwareNodeKind.component, label: serviceNode));
      edges.add(SoftwareEdge(fromId: repoIdentity, toId: nodeIdentity, kind: SoftwareRelationshipKind.contains, evidence: evidence));
    }
    for (final edgeRaw in serviceEdgesRaw) {
      final e = _asMap(edgeRaw);
      final from = e['from']?.toString();
      final to = e['to']?.toString();
      if (from == null || to == null || from.isEmpty || to.isEmpty) continue;
      edges.add(
        SoftwareEdge(
          fromId: SoftwareIdentity.stable(SoftwareNodeKind.component, from),
          toId: SoftwareIdentity.stable(SoftwareNodeKind.component, to),
          kind: SoftwareRelationshipKind.calls,
          evidence: evidence,
        ),
      );
    }

    return RepositoryModel(
      metadata: context.metadata,
      structure: structure,
      dependencies: dependencies,
      entrypoints: entrypoints,
      frameworks: frameworks,
      infraSignals: infra,
      classNames: classNames,
      functionNames: functionNames,
      decorators: decorators,
      summary: summary,
      graph: RepositoryGraph(SemanticSoftwareGraph(nodes: nodes, edges: edges)),
      confidence: SoftwareConfidence(
        score: confidenceScore,
        reason: confidenceBasis.isNotEmpty ? confidenceBasis.join(', ') : 'no parser evidence available',
      ),
    );
  }

  /// Acquisition convenience: fetches [url] via WebWeaveX's real, bounded
  /// HTTP fetch and real HTML extraction, then analyzes the extracted
  /// text. Returns null (never throws) when the page is unreachable or
  /// empty — matching WebWeaveXAdapter's own failure contract.
  Future<RepositoryModel?> acquireFromUrl(String url, {required String name, String description = ''}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.scheme.startsWith('http')) return null;

    Map<String, dynamic> rendered;
    try {
      rendered = await _fetchPage(url);
    } catch (_) {
      return null;
    }
    if (rendered['available'] != true) return null;
    final html = rendered['html'] as String? ?? '';
    if (html.isEmpty) return null;

    final semanticContent = wwx.extractSemanticContent(html);
    final paragraphs = (semanticContent['paragraphs'] as List? ?? []).cast<String>();
    final text = paragraphs.isNotEmpty ? paragraphs.join('\n\n') : (wwx.extractSemanticHtml(html)['text'] as String? ?? '');
    if (text.isEmpty) return null;

    final metadata = RepositoryMetadata(
      name: name,
      description: description,
      primaryLanguage: 'text',
      provenance: SoftwareProvenance(
        sourceUrl: url,
        repositoryUrl: url,
        retrievedAt: DateTime.now(),
        provider: 'webweavex',
        license: const LicenseMetadata(policy: LicensePolicy.unknownReviewRequired, source: 'webweavex', confidence: 0.5),
      ),
    );

    return analyze(RepositoryContext(source: text, metadata: metadata, path: uri.path));
  }
}
