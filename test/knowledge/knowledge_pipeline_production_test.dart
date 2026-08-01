/// V1 — Production-path proof: KnowledgeAcquisitionEngine -> package:webweavex
/// actually executes over real network.
///
/// Every other knowledge test in this repo fakes the network layer for
/// determinism (the right call for CI). This file is the deliberate
/// exception, proving package:webweavex's real HTTP fetch
/// (`renderPage`) and real HTML extraction (`extractSemanticHtml`/
/// `extractSemanticContent`) genuinely execute end-to-end through
/// KnowledgeAcquisitionEngine — "no fake acquisition path" has to be
/// demonstrated against something real at least once.
///
/// Uses https://example.com/ (IANA-reserved for documentation/testing,
/// stable, tiny) as the target so this doesn't depend on a third-party
/// search engine's HTML structure remaining stable — SearchProvider is a
/// separately swappable concern already covered deterministically in
/// search_provider_test.dart. If this environment has no outbound network
/// access, the test skips itself with a clear message rather than
/// failing the suite.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';

class _FixedUrlSearchProvider implements SearchProvider {
  final String url;
  const _FixedUrlSearchProvider(this.url);

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    return [SearchResult(url: url)];
  }
}

Future<bool> _hasNetwork() async {
  try {
    final response = await http
        .get(Uri.parse('https://example.com/'))
        .timeout(const Duration(seconds: 8));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  test('Intent-shaped requirement -> KnowledgeAcquisitionEngine -> real '
      'package:webweavex extraction -> real KnowledgeBundle', () async {
    if (!await _hasNetwork()) {
      markTestSkipped('No outbound network access in this environment.');
      return;
    }

    final engine = KnowledgeAcquisitionEngine(
      searchProvider: const _FixedUrlSearchProvider('https://example.com/'),
      webweavexAdapter: WebWeaveXAdapter(), // real wwx.renderPage, real network
    );

    final bundle = await engine.acquire(
      requirements: [
        const KnowledgeRequirement(
          objective: 'example domain reference page',
          resourceType: 'domainKnowledge',
        ),
      ],
      queryHints: const [],
    );

    expect(
      bundle.status,
      anyOf(BundleStatus.ready, BundleStatus.offlineCached),
    );
    expect(bundle.resources, isNotEmpty);

    final resource = bundle.resources.first;
    expect(resource.sourceUri, 'https://example.com/');
    expect(resource.sourceDomain, 'example.com');
    expect(resource.provenance.provider, 'webweavex');
    // example.com's real, live page content — proves this came from an
    // actual HTTP fetch + real WebWeaveX HTML parse, not a canned fixture.
    expect(resource.content, isNotNull);
    expect(resource.content!.toLowerCase(), contains('example'));
    expect(resource.contentHash, isNotNull);
    expect(
      resource.retrievedAt.difference(DateTime.now()).inMinutes.abs(),
      lessThan(5),
    );
  });

  test(
    'the real default production wiring (DuckDuckGoSearchProvider + real '
    'WebWeaveXAdapter) resolves a query to real content end-to-end',
    () async {
      if (!await _hasNetwork()) {
        markTestSkipped('No outbound network access in this environment.');
        return;
      }

      final engine = KnowledgeAcquisitionEngine(
        searchProvider: DuckDuckGoSearchProvider(),
        webweavexAdapter: WebWeaveXAdapter(),
      );

      final bundle = await engine.acquire(
        requirements: [
          const KnowledgeRequirement(
            objective: 'dart programming language',
            resourceType: 'domainKnowledge',
          ),
        ],
        queryHints: const [],
      );

      // Search engines/pages are not under this repo's control — assert
      // the pipeline behaved gracefully either way, not a specific result.
      if (bundle.resources.isEmpty) {
        markTestSkipped(
          'DuckDuckGo returned no usable results in this run — pipeline '
          'degraded gracefully (warnings: ${bundle.warnings}).',
        );
        return;
      }
      expect(bundle.resources.first.provenance.provider, 'webweavex');
      expect(bundle.resources.first.content, isNotNull);
    },
  );
}
