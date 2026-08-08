/// Vision V11 — PackageAnalyzer. Proves the real pubspec.yaml dependency
/// block parser (filling a documented, real gap WebWeaveX's own
/// dependency resolver doesn't cover) and evidence-backed capability
/// inference.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/software_cognition/package_analyzer.dart';
import 'package:anything/software_cognition/package_model.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/software_cognition/software_types.dart';

const _pubspecSource = '''
name: novel_orchid_tracker
description: A tracker for orchid cultivation.
version: 1.0.0

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  sqflite: ^2.3.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^4.0.0
''';

PackageMetadata _metadata() => PackageMetadata(
  name: 'novel_orchid_tracker',
  version: '1.0.0',
  description: 'A tracker for orchid cultivation.',
  provenance: SoftwareProvenance(
    sourceUrl: 'https://pub.dev/packages/novel_orchid_tracker',
    retrievedAt: DateTime(2026, 8, 2),
    provider: 'test-fixture',
    license: const LicenseMetadata(
      policy: LicensePolicy.permissiveKnown,
      licenseId: 'MIT',
      confidence: 1.0,
    ),
  ),
);

void main() {
  group('PackageAnalyzer.parsePubspecDependencies', () {
    test('parses only the dependencies: block, never dev_dependencies', () {
      final deps = const PackageAnalyzer().parsePubspecDependencies(
        _pubspecSource,
      );
      final names = deps.map((d) => d.name).toList();
      expect(
        names,
        containsAll(['flutter', 'http', 'sqflite', 'shared_preferences']),
      );
      expect(names, isNot(contains('flutter_test')));
      expect(names, isNot(contains('lints')));
    });

    test('captures version constraints where present', () {
      final deps = const PackageAnalyzer().parsePubspecDependencies(
        _pubspecSource,
      );
      final http = deps.firstWhere((d) => d.name == 'http');
      expect(http.versionConstraint, '^1.2.0');
    });

    test('a nested sdk: map does not itself become a dependency entry', () {
      final deps = const PackageAnalyzer().parsePubspecDependencies(
        _pubspecSource,
      );
      expect(deps.where((d) => d.name == 'sdk'), isEmpty);
    });
  });

  group('PackageAnalyzer.analyzePubspec', () {
    test(
      'infers real, evidence-backed capabilities from known dependencies',
      () {
        final model = const PackageAnalyzer().analyzePubspec(
          pubspecSource: _pubspecSource,
          metadata: _metadata(),
        );
        final capabilityNames = model.capabilities.map((c) => c.name);
        expect(
          capabilityNames,
          containsAll(['network access', 'local storage', 'key-value storage']),
        );
      },
    );

    test('every capability traces to a real dependency name', () {
      final model = const PackageAnalyzer().analyzePubspec(
        pubspecSource: _pubspecSource,
        metadata: _metadata(),
      );
      final networkCapability = model.capabilities.firstWhere(
        (c) => c.name == 'network access',
      );
      expect(networkCapability.evidence.sourceArtifact, 'http');
    });

    test('builds a real dependency graph', () {
      final model = const PackageAnalyzer().analyzePubspec(
        pubspecSource: _pubspecSource,
        metadata: _metadata(),
      );
      final graph = model.graph.graph;
      expect(
        graph.nodesOfKind(SoftwareNodeKind.package).length,
        greaterThan(1),
      );
    });

    test('confidence is high when real dependencies were parsed', () {
      final model = const PackageAnalyzer().analyzePubspec(
        pubspecSource: _pubspecSource,
        metadata: _metadata(),
      );
      expect(model.confidence.score, greaterThanOrEqualTo(0.8));
    });
  });

  group('PackageAnalyzer.analyzeFromDescription', () {
    test('never fabricates a dependency list from prose', () {
      final model = const PackageAnalyzer().analyzeFromDescription(
        text: 'A package for making HTTP requests.',
        metadata: _metadata(),
      );
      expect(model.dependencies, isEmpty);
    });

    test('still infers a capability from keyword evidence in the text', () {
      final model = const PackageAnalyzer().analyzeFromDescription(
        text: 'A package for making http requests.',
        metadata: _metadata(),
      );
      expect(model.capabilities.map((c) => c.name), contains('network access'));
    });
  });
}
