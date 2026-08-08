/// Vision V11 — SoftwareSimilarity + SoftwareReasoner (multi-source
/// reasoning: acquire multiple -> compare -> extract best -> reject
/// poor). All three acquired "repositories" are novel/fictional and
/// deterministic — no network.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/software_cognition/software_reasoner.dart';
import 'package:anything/software_cognition/software_similarity.dart';

RepositoryMetadata _metadata(String name) => RepositoryMetadata(
  name: name,
  description: 'novel fixture repository $name',
  primaryLanguage: 'dart',
  provenance: SoftwareProvenance(
    sourceUrl: 'https://example.com/$name',
    retrievedAt: DateTime(2026, 8, 2),
    provider: 'test-fixture',
    license: const LicenseMetadata(
      policy: LicensePolicy.permissiveKnown,
      licenseId: 'MIT',
      confidence: 1.0,
    ),
  ),
);

RepositoryModel _analyze(String name, String source) => RepositoryAnalyzer()
    .analyze(RepositoryContext(source: source, metadata: _metadata(name)));

void main() {
  group('SoftwareSimilarity', () {
    test('identical repositories are fully similar', () {
      const source = 'flutter\nsqflite\n';
      final a = _analyze('a', source);
      final b = _analyze('b', source);
      final report = const SoftwareSimilarity().compareRepositories(a, b);
      expect(report.dependencySimilarity, 1.0);
    });

    test('disjoint repositories have low overall similarity', () {
      final a = _analyze('a', 'flutter\nsqflite\n');
      final b = _analyze('b', 'django\npsycopg2\n');
      final report = const SoftwareSimilarity().compareRepositories(a, b);
      expect(report.dependencySimilarity, 0.0);
    });

    test('workflow similarity compares entrypoint sets deterministically', () {
      final sim = const SoftwareSimilarity();
      expect(
        sim.workflowSimilarity(['main', 'run_sync'], ['main', 'run_sync']),
        1.0,
      );
      expect(sim.workflowSimilarity(['main'], ['handle_upload']), 0.0);
    });
  });

  group('SoftwareReasoner — multi-source reasoning', () {
    test(
      'a framework repeated across 2+ acquired repositories is accepted',
      () {
        final candidates = [
          _analyze('orchid-tracker', 'flutter\nsqflite\n'),
          _analyze('fuel-log', 'flutter\nhttp\n'),
          _analyze('bird-watch', 'django\n'),
        ];
        final recommendations = const SoftwareReasoner()
            .reasonAboutRepositories(candidates);
        final flutterRec = recommendations.firstWhere(
          (r) => r.description.contains('flutter'),
        );
        expect(flutterRec.accepted, isTrue);
        expect(flutterRec.tracedTo, hasLength(2));
      },
    );

    test(
      'a framework seen in only one candidate is reported but rejected — never silently dropped',
      () {
        final candidates = [
          _analyze('orchid-tracker', 'flutter\n'),
          _analyze('fuel-log', 'django\n'),
        ];
        final recommendations = const SoftwareReasoner()
            .reasonAboutRepositories(candidates);
        final djangoRec = recommendations.firstWhere(
          (r) => r.description.contains('django'),
        );
        expect(djangoRec.accepted, isFalse);
        expect(djangoRec.tracedTo, hasLength(1));
      },
    );

    test(
      'detectPatterns produces a SoftwarePattern only for accepted recommendations',
      () {
        final candidates = [
          _analyze('a', 'flutter\n'),
          _analyze('b', 'flutter\n'),
          _analyze('c', 'django\n'),
        ];
        final patternGraph = const SoftwareReasoner().detectPatterns(
          candidates,
        );
        expect(patternGraph.patterns, hasLength(1));
        expect(patternGraph.patterns.single.name, 'flutter');
      },
    );

    test(
      'pairwiseSimilarity covers every unique candidate pair exactly once',
      () {
        final candidates = [
          _analyze('a', 'flutter\n'),
          _analyze('b', 'flutter\n'),
          _analyze('c', 'django\n'),
        ];
        final result = const SoftwareReasoner().pairwiseSimilarity(candidates);
        expect(result.keys, hasLength(3)); // 3 choose 2
      },
    );

    test(
      'an empty candidate list produces no recommendations, never an error',
      () {
        expect(const SoftwareReasoner().reasonAboutRepositories([]), isEmpty);
      },
    );
  });
}
