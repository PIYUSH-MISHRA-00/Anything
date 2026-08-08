/// Vision V11 — ComponentAnalyzer, WidgetAnalyzer, APIAnalyzer,
/// SchemaAnalyzer, ArchitectureAnalyzer, StorageAnalyzer, and the
/// Dependency/Import/CodeRelationship projections.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/software_cognition/api_analyzer.dart';
import 'package:anything/software_cognition/architecture_analyzer.dart';
import 'package:anything/software_cognition/component_analyzer.dart';
import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/software_cognition/software_types.dart';

RepositoryMetadata _metadata(String name) => RepositoryMetadata(
  name: name,
  description: '',
  primaryLanguage: 'dart',
  provenance: SoftwareProvenance(
    sourceUrl: 'https://example.com/$name',
    retrievedAt: DateTime(2026, 8, 2),
    provider: 'test-fixture',
    license: const LicenseMetadata(
      policy: LicensePolicy.permissiveKnown,
      licenseId: 'MIT',
    ),
  ),
);

void main() {
  group('ComponentAnalyzer', () {
    test(
      'counts real semantic HTML5 elements via WebWeaveX\'s own Soup parser',
      () {
        const html =
            '<html><body><nav>menu</nav><form></form><form></form><table></table></body></html>';
        final graph = const ComponentAnalyzer().analyzeHtml(html).graph;
        final labels = graph.nodes.map((n) => n.label).toList();
        expect(labels, contains('nav (1)'));
        expect(labels, contains('form (2)'));
        expect(labels, contains('table (1)'));
      },
    );

    test('a tag never present produces no node for it', () {
      const html = '<html><body><p>plain text only</p></body></html>';
      final graph = const ComponentAnalyzer().analyzeHtml(html).graph;
      expect(graph.nodes, isEmpty);
    });
  });

  group('WidgetAnalyzer', () {
    test('classifies real Flutter-shaped class names', () {
      final graph = const WidgetAnalyzer().fromClassNames([
        'HomeScreen',
        'CustomWidget',
        'UserModel',
        'LoginPage',
      ]).graph;
      final labels = graph.nodes.map((n) => n.label).toSet();
      expect(labels, containsAll(['HomeScreen', 'CustomWidget', 'LoginPage']));
      expect(labels, isNot(contains('UserModel')));
    });
  });

  group('APIAnalyzer', () {
    test('extracts real endpoints from an OpenAPI-shaped spec', () {
      const spec =
          '{"paths": {"/users": {"get": {}, "post": {}}, "/users/{id}": {"delete": {}}}}';
      final api = const APIAnalyzer().fromOpenApiJson(spec);
      final labels = api.endpoints.graph.nodes.map((n) => n.label).toSet();
      expect(
        labels,
        containsAll(['GET /users', 'POST /users', 'DELETE /users/{id}']),
      );
    });

    test('malformed JSON never throws — produces an empty graph', () {
      final api = const APIAnalyzer().fromOpenApiJson('not json');
      expect(api.endpoints.graph.nodes, isEmpty);
    });

    test('extracts real schemas from components.schemas', () {
      const spec = '{"components": {"schemas": {"User": {}, "Order": {}}}}';
      final api = const APIAnalyzer().fromOpenApiJson(spec);
      final labels = api.schemas.graph.nodes.map((n) => n.label).toSet();
      expect(labels, containsAll(['User', 'Order']));
    });

    test('fromDecorators only recognizes real HTTP-verb-shaped decorators', () {
      final api = const APIAnalyzer().fromDecorators([
        'get',
        'post',
        'override',
        'deprecated',
      ]);
      final labels = api.endpoints.graph.nodes.map((n) => n.label).toSet();
      expect(labels, {'get', 'post'});
    });
  });

  group('ArchitectureAnalyzer', () {
    test('infers real layers from conventional top-level directory names', () {
      final model = RepositoryAnalyzer().analyze(
        RepositoryContext(
          source: '',
          metadata: _metadata('layered-app'),
          files: ['ui/', 'domain/', 'data/', 'ui/home.dart'],
        ),
      );
      final layers = const ArchitectureAnalyzer()
          .analyze(model)
          .graph
          .nodes
          .map((n) => n.label)
          .toSet();
      expect(layers, {'presentation', 'domain', 'data'});
    });

    test(
      'an unconventional directory layout produces no fabricated layers',
      () {
        final model = RepositoryAnalyzer().analyze(
          RepositoryContext(
            source: '',
            metadata: _metadata('flat-app'),
            files: ['misc/'],
          ),
        );
        expect(
          const ArchitectureAnalyzer().analyze(model).graph.nodes,
          isEmpty,
        );
      },
    );
  });

  group('StorageAnalyzer', () {
    test('detects a real, known storage dependency', () {
      final model = RepositoryAnalyzer().analyze(
        RepositoryContext(
          source: 'sqflite\nflutter\n',
          metadata: _metadata('storage-app'),
        ),
      );
      final labels = const StorageAnalyzer()
          .analyze(model)
          .graph
          .nodes
          .map((n) => n.label)
          .toSet();
      expect(labels, contains('sqflite'));
      expect(labels, isNot(contains('flutter')));
    });
  });

  group('DependencyProjections', () {
    test('dependencyGraph contains only dependsOn-kind nodes/edges', () {
      final model = RepositoryAnalyzer().analyze(
        RepositoryContext(source: 'http\n', metadata: _metadata('dep-app')),
      );
      final projected = const DependencyProjections()
          .dependencyGraph(model)
          .graph;
      expect(projected.edges, isNotEmpty);
      expect(
        projected.edges.every(
          (e) => e.kind == SoftwareRelationshipKind.dependsOn,
        ),
        isTrue,
      );
    });
  });
}
