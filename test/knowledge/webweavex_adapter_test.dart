/// V1 — WebWeaveXAdapter tests.
///
/// Exercises the REAL WebWeaveX parsing/extraction functions
/// (extractSemanticHtml/extractSemanticContent, its bs4-parity Soup
/// engine) against canned HTML via an injected PageFetcher, so these
/// tests are deterministic and network-free while still proving the real
/// WebWeaveX extraction code runs (only the HTTP fetch step is faked).
/// The genuinely live-network proof is in
/// knowledge_pipeline_production_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/security/runtime_security_limits.dart';

const _samplePage = '''
<html>
  <head><title>Amortization Formulas — Example Finance Wiki</title></head>
  <body>
    <h1>Amortization</h1>
    <p>The standard formula computes a fixed monthly payment.</p>
    <p>M = P [ i(1+i)^n ] / [ (1+i)^n - 1 ]</p>
    <a href="/related">Related</a>
  </body>
</html>
''';

void main() {
  group('WebWeaveXAdapter.extract', () {
    test(
      'extracts real title/content from real WebWeaveX HTML parsing',
      () async {
        final adapter = WebWeaveXAdapter(
          fetchPage: (url) async => {
            'url': url,
            'status': 200,
            'html': _samplePage,
            'available': true,
          },
        );

        final resource = await adapter.extract(
          'https://finance.example.com/amortization',
        );

        expect(resource, isNotNull);
        expect(resource!.title, 'Amortization Formulas — Example Finance Wiki');
        expect(resource.content, contains('fixed monthly payment'));
        expect(resource.content, contains('M = P'));
        expect(resource.sourceUri, 'https://finance.example.com/amortization');
        expect(resource.sourceDomain, 'finance.example.com');
        expect(resource.provenance.provider, 'webweavex');
        expect(resource.contentHash, isNotNull);
        expect(resource.type, KnowledgeResourceType.webDocument);
      },
    );

    test(
      'unreachable page (available: false) yields null, not a crash',
      () async {
        final adapter = WebWeaveXAdapter(
          fetchPage: (url) async => {
            'url': url,
            'available': false,
            'html': '',
          },
        );

        final resource = await adapter.extract('https://down.example.com/');
        expect(resource, isNull);
      },
    );

    test(
      'fetcher throwing (network failure) yields null, not a thrown exception',
      () async {
        final adapter = WebWeaveXAdapter(
          fetchPage: (url) async =>
              throw Exception('simulated network failure'),
        );

        final resource = await adapter.extract('https://example.com/');
        expect(resource, isNull);
      },
    );

    test('non-http URL is rejected before any fetch attempt', () async {
      var fetchCalled = false;
      final adapter = WebWeaveXAdapter(
        fetchPage: (url) async {
          fetchCalled = true;
          return {'available': true, 'html': '<html></html>'};
        },
      );

      final resource = await adapter.extract('file:///etc/passwd');
      expect(resource, isNull);
      expect(fetchCalled, isFalse);
    });

    test('empty HTML body yields null', () async {
      final adapter = WebWeaveXAdapter(
        fetchPage: (url) async => {'available': true, 'html': ''},
      );

      final resource = await adapter.extract('https://example.com/');
      expect(resource, isNull);
    });

    test('page with no <p> tags falls back to full page text', () async {
      final adapter = WebWeaveXAdapter(
        fetchPage: (url) async => {
          'available': true,
          'html':
              '<html><head><title>No Paragraphs</title></head>'
              '<body><div>Just a div with text, no p tags.</div></body></html>',
        },
      );

      final resource = await adapter.extract('https://example.com/nop');
      expect(resource, isNotNull);
      expect(resource!.content, contains('Just a div with text'));
    });

    test(
      'oversized content is truncated to the trusted knowledge-size ceiling',
      () async {
        // WebWeaveX's own extractSemanticContent caps each <p> at 10,000
        // chars, so a single giant paragraph can't demonstrate the
        // adapter-level ceiling; use many paragraphs whose combined length
        // exceeds RuntimeSecurityLimits.maxKnowledgeBytes instead.
        final paragraphCount =
            (RuntimeSecurityLimits.maxKnowledgeBytes / 9000).ceil() + 5;
        final paragraphs = List.generate(
          paragraphCount,
          (i) => '<p>${'x' * 9000}</p>',
        ).join();
        final adapter = WebWeaveXAdapter(
          fetchPage: (url) async => {
            'available': true,
            'html':
                '<html><head><title>Huge</title></head>'
                '<body>$paragraphs</body></html>',
          },
        );

        final resource = await adapter.extract('https://example.com/huge');
        expect(resource, isNotNull);
        expect(
          resource!.content!.length,
          RuntimeSecurityLimits.maxKnowledgeBytes,
        );
      },
    );

    test('extractAll drops failing URLs but keeps successful ones', () async {
      final adapter = WebWeaveXAdapter(
        fetchPage: (url) async {
          if (url.contains('good')) {
            return {
              'available': true,
              'html':
                  '<html><head><title>Good</title></head>'
                  '<body><p>Real content here.</p></body></html>',
            };
          }
          throw Exception('simulated failure for $url');
        },
      );

      final resources = await adapter.extractAll([
        'https://good.example.com/1',
        'https://bad.example.com/2',
        'https://good.example.com/3',
      ]);

      expect(resources, hasLength(2));
      expect(resources.every((r) => r.sourceUri.contains('good')), isTrue);
    });
  });
}
