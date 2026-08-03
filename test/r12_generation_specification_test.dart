/// Implementation Milestone R12 — Canonical Generation Specification.
/// Proves `SummaryManifestGenerator` (R10) is GENUINELY refactored to
/// consume a real `GenerationSpecification` for artifact naming/paths —
/// not merely given new, unused sibling types alongside its old
/// hardcoded logic. The core proof: (a) the DEFAULT specification
/// reproduces the exact pre-R12 output (regression-equivalence), and
/// (b) a DIFFERENT, custom specification measurably changes the
/// generator's real output (genuine consumption, not decoration).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/build_graph/build_graph.dart';
import 'package:anything/build_graph/universal_build_graph.dart';
import 'package:anything/generation_specification/generation_specification.dart';
import 'package:anything/generation_specification/path_template.dart';
import 'package:anything/generator_framework/artifact.dart';
import 'package:anything/generator_framework/generation_pipeline.dart';
import 'package:anything/generator_framework/generation_result.dart';
import 'package:anything/generator_framework/generator.dart';
import 'package:anything/generator_framework/reference/summary_manifest_generator.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';

CanonicalImplementationModel _twoEntityModel() {
  return const CanonicalImplementationModel(
    entities: [
      ImplementationEntity(
        id: 'task',
        name: 'Task',
        fields: [
          ImplementationField(id: 'task.title', name: 'title', type: ImplementationDataType.text, required: true),
          ImplementationField(id: 'task.done', name: 'done', type: ImplementationDataType.boolean),
        ],
      ),
      ImplementationEntity(id: 'tag', name: 'Tag', fields: [ImplementationField(id: 'tag.label', name: 'label', type: ImplementationDataType.text, required: true)]),
    ],
    authentication: AuthenticationAdapterSpec(requiresCredentials: false),
    backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
  );
}

CanonicalImplementationModel _largeModel(int count) => CanonicalImplementationModel(
  entities: List.generate(count, (i) => ImplementationEntity(id: 'e$i', name: 'Entity $i', fields: const [])),
  authentication: const AuthenticationAdapterSpec(requiresCredentials: false),
  backgroundWorker: const BackgroundWorkerSpec(requiresBackgroundSync: false),
);

const _target = GeneratorTarget(id: 'reference-summary', name: 'Reference Summary');

void main() {
  group('PathTemplate (R12)', () {
    test('substitutes {id} and {label} deterministically', () {
      const template = PathTemplate('summary/{id}/{label}.txt');
      expect(template.resolve(id: 'task', label: 'Task'), 'summary/task/Task.txt');
    });

    test('a template with no placeholders is returned unchanged', () {
      const template = PathTemplate('manifest.txt');
      expect(template.resolve(id: 'x', label: 'y'), 'manifest.txt');
    });
  });

  group('GenerationSpecification (R12)', () {
    test('ruleFor returns the real matching rule, or null when none is declared', () {
      const spec = GenerationSpecification(
        rules: [GenerationRule(nodeKind: BuildNodeKind.entity, mapping: ArtifactMapping(pathTemplate: PathTemplate('x/{id}.txt'), artifactKind: 'file'))],
        manifestPathTemplate: PathTemplate('manifest.txt'),
      );
      expect(spec.ruleFor(BuildNodeKind.entity), isNotNull);
      expect(spec.ruleFor(BuildNodeKind.repository), isNull);
    });
  });

  group('SummaryManifestGenerator genuinely consumes GenerationSpecification (R12)', () {
    test('regression-equivalence: the DEFAULT specification reproduces the exact pre-R12 output paths', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());
      const generator = SummaryManifestGenerator();
      final result = generator.generate(GeneratorContext(buildGraph: graph, target: _target));

      final paths = result.allArtifacts.map((a) => a.path).toSet();
      expect(paths, {'summary/task.txt', 'summary/tag.txt', 'summary/manifest.txt'}, reason: 'must match SummaryManifestGenerator\'s exact pre-R12 hardcoded paths');
    });

    test('a CUSTOM specification measurably changes real generator output — genuine consumption, not decoration', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());
      const customSpec = GenerationSpecification(
        rules: [GenerationRule(nodeKind: BuildNodeKind.entity, mapping: ArtifactMapping(pathTemplate: PathTemplate('custom/{label}/entity.txt'), artifactKind: 'file'))],
        manifestPathTemplate: PathTemplate('custom/index.txt'),
      );
      const generator = SummaryManifestGenerator(specification: customSpec);
      final result = generator.generate(GeneratorContext(buildGraph: graph, target: _target));

      final paths = result.allArtifacts.map((a) => a.path).toSet();
      expect(paths, {'custom/Task/entity.txt', 'custom/Tag/entity.txt', 'custom/index.txt'});
      // Content is still real generator-authored data, unaffected by the
      // path-only specification — proves content assembly correctly
      // stayed separate from naming.
      final taskArtifact = result.allArtifacts.firstWhere((a) => a.path == 'custom/Task/entity.txt');
      expect(taskArtifact.content, contains('title (text, required)'));
    });

    test('a specification with NO rule for BuildNodeKind.entity honestly emits no entity artifacts, with a real diagnostic', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());
      const emptySpec = GenerationSpecification(rules: [], manifestPathTemplate: PathTemplate('manifest.txt'));
      const generator = SummaryManifestGenerator(specification: emptySpec);
      final result = generator.generate(GeneratorContext(buildGraph: graph, target: _target));

      expect(result.allArtifacts.where((a) => a.kind == ArtifactKind.file), isEmpty);
      expect(result.diagnostics.any((d) => d.category == DiagnosticCategory.skippedFeature && d.message.contains('entity')), isTrue);
      // The manifest artifact is still produced — it is not gated by the
      // per-node-kind rule set.
      expect(result.allArtifacts.any((a) => a.path == 'manifest.txt'), isTrue);
    });

    test('determinism: the same graph and specification run twice through the real GenerationPipeline produce byte-for-byte identical artifacts', () {
      final graph = const BuildGraphBuilder().build(_twoEntityModel());
      const generator = SummaryManifestGenerator();
      const pipeline = GenerationPipeline();

      final first = pipeline.run(buildGraph: graph, generator: generator, target: _target);
      final second = pipeline.run(buildGraph: graph, generator: generator, target: _target);

      final firstByPath = {for (final a in first.allArtifacts) a.path: a.content};
      final secondByPath = {for (final a in second.allArtifacts) a.path: a.content};
      expect(firstByPath, secondByPath);
    });

    test('performance: specification-driven mapping over a 200-entity model stays correct and reports real elapsed time', () {
      final graph = const BuildGraphBuilder().build(_largeModel(200));
      const generator = SummaryManifestGenerator();

      final stopwatch = Stopwatch()..start();
      final result = generator.generate(GeneratorContext(buildGraph: graph, target: _target));
      stopwatch.stop();

      expect(result.allArtifacts.where((a) => a.kind == ArtifactKind.file), hasLength(200));
      // ignore: avoid_print
      print('SummaryManifestGenerator (specification-driven) over 200 entities: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
