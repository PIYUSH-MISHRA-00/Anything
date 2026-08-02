/// Vision V11 — RepositoryAnalyzer. Proves real translation of
/// WebWeaveX's own deterministic `compileRepository` IR into a typed
/// RepositoryModel — no network, no fabricated facts. A novel, fictional
/// repository ("Lighthouse Keeper's Fuel Log" backend) is used throughout
/// to prove nothing here is domain-specific.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/software_cognition/software_types.dart';

const _novelRepoSource = '''
requests
flask

class FuelLogWidgetScreen:
    def run_ingest():
        return None

def helper_calc():
    return None
''';

RepositoryMetadata _metadata({String name = 'lighthouse-fuel-log'}) => RepositoryMetadata(
  name: name,
  description: 'Backend for a lighthouse keeper fuel log',
  primaryLanguage: 'python',
  provenance: SoftwareProvenance(
    sourceUrl: 'https://example.com/$name',
    repositoryUrl: 'https://example.com/$name',
    retrievedAt: DateTime(2026, 8, 2),
    provider: 'test-fixture',
    license: const LicenseMetadata(policy: LicensePolicy.permissiveKnown, licenseId: 'MIT', confidence: 1.0),
  ),
);

void main() {
  group('RepositoryAnalyzer.analyze', () {
    test('extracts real dependencies from acquired source text', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: _novelRepoSource, metadata: _metadata(), path: 'app.py'));
      expect(model.dependencies, containsAll(['requests', 'flask']));
    });

    test('extracts real class and function names', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: _novelRepoSource, metadata: _metadata(), path: 'app.py'));
      expect(model.classNames, contains('FuelLogWidgetScreen'));
      expect(model.functionNames, containsAll(['run_ingest', 'helper_calc']));
    });

    test('detects a real entrypoint by naming convention', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: _novelRepoSource, metadata: _metadata(), path: 'app.py'));
      expect(model.entrypoints, contains('run_ingest'));
    });

    test('detects infra signals from a real file listing', () {
      final model = RepositoryAnalyzer().analyze(
        RepositoryContext(source: _novelRepoSource, metadata: _metadata(), path: 'app.py', files: ['app.py', 'Dockerfile', '.github/workflows/ci.yml']),
      );
      expect(model.infraSignals, isNotEmpty);
      expect(model.summary.hasCi, isTrue);
      expect(model.summary.hasDocker, isTrue);
    });

    test('builds a real SemanticSoftwareGraph with a repository node and dependency edges', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: _novelRepoSource, metadata: _metadata(), path: 'app.py'));
      final graph = model.graph.graph;
      expect(graph.nodesOfKind(SoftwareNodeKind.repository), hasLength(1));
      final depNodes = graph.nodesOfKind(SoftwareNodeKind.package).map((n) => n.label);
      expect(depNodes, containsAll(['requests', 'flask']));
    });

    test('reports a real, explainable confidence — never a hardcoded constant', () {
      final withDeps = RepositoryAnalyzer().analyze(RepositoryContext(source: _novelRepoSource, metadata: _metadata(), path: 'app.py'));
      final empty = RepositoryAnalyzer().analyze(RepositoryContext(source: '', metadata: _metadata(name: 'empty-repo')));
      expect(withDeps.confidence.score, greaterThan(empty.confidence.score));
    });

    test('a second, unrelated novel repository produces an independent, non-colliding model', () {
      const otherSource = '''
pytest
numpy

class OrchidCareTrackerScreen:
    def main():
        return None
''';
      final a = RepositoryAnalyzer().analyze(RepositoryContext(source: _novelRepoSource, metadata: _metadata(name: 'lighthouse'), path: 'a.py'));
      final b = RepositoryAnalyzer().analyze(RepositoryContext(source: otherSource, metadata: _metadata(name: 'orchid'), path: 'b.py'));
      expect(a.dependencies, isNot(equals(b.dependencies)));
      expect(a.graph.graph.nodesOfKind(SoftwareNodeKind.repository).single.identity, isNot(equals(b.graph.graph.nodesOfKind(SoftwareNodeKind.repository).single.identity)));
    });
  });

  group('RepositoryAnalyzer.acquireFromUrl', () {
    test('acquires and analyzes via an injected fetcher — no live network', () async {
      final analyzer = RepositoryAnalyzer(
        fetchPage: (url) async => {
          'url': url,
          'status': 200,
          'available': true,
          'html': '<html><body><p>$_novelRepoSource</p></body></html>',
        },
      );
      final model = await analyzer.acquireFromUrl('https://example.com/repo', name: 'lighthouse-fuel-log');
      expect(model, isNotNull);
      expect(model!.dependencies, containsAll(['requests', 'flask']));
    });

    test('returns null (never throws) when the page is unreachable', () async {
      final analyzer = RepositoryAnalyzer(fetchPage: (url) async => {'available': false});
      final model = await analyzer.acquireFromUrl('https://example.com/missing', name: 'missing');
      expect(model, isNull);
    });

    test('returns null for a non-http URL', () async {
      final analyzer = RepositoryAnalyzer(fetchPage: (url) async => {'available': true, 'html': '<p>x</p>'});
      final model = await analyzer.acquireFromUrl('file:///etc/passwd', name: 'bad');
      expect(model, isNull);
    });
  });
}
