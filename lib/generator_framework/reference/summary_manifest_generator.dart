/// SummaryManifestGenerator — Implementation Milestone R10's ONE reference
/// generator. Its ONLY job is to validate the Generator Framework
/// end-to-end (per this milestone's own explicit "IMPORTANT
/// ARCHITECTURAL REQUIREMENT": do NOT attempt a production Flutter/
/// backend/web/desktop/mobile generator here — that is explicitly
/// deferred to a future milestone, after the framework itself has been
/// proven).
///
/// Consumes a real `CanonicalImplementationModel` and emits small,
/// deterministic, human-readable TEXT artifacts — one per entity, plus
/// one top-level manifest — never source code in any real target
/// language/framework. This is deliberately the simplest possible real
/// consumer: proof that `Generator`/`GeneratorContext`/`GenerationResult`/
/// `Artifact`/`ArtifactGroup`/`GenerationPipeline` all compose correctly
/// against real, already-computed R9 data, nothing more.
library;

import '../artifact.dart';
import '../generation_result.dart';
import '../generator.dart';

class SummaryManifestGenerator implements Generator {
  const SummaryManifestGenerator();

  @override
  GeneratorMetadata get metadata => const GeneratorMetadata(
    id: 'reference.summary-manifest',
    name: 'Summary Manifest (Reference Generator)',
    version: GeneratorVersion(major: 1, minor: 0, patch: 0),
    capabilities: [GeneratorCapability.documentation, GeneratorCapability.manifests],
  );

  @override
  GenerationResult generate(GeneratorContext context) {
    // Implementation Milestone R11: reads the retained source model off
    // the build graph — this generator's own entity/field-level logic is
    // unchanged, it just reaches the same data through
    // `UniversalBuildGraph.sourceModel` instead of a bare
    // `CanonicalImplementationModel` parameter.
    final model = context.buildGraph.sourceModel;
    final diagnostics = <GenerationDiagnostic>[];

    if (model.entities.isEmpty) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.general,
          message: 'No entities in the supplied CanonicalImplementationModel — nothing to summarize.',
        ),
      );
      return GenerationResult(diagnostics: diagnostics);
    }

    final entityArtifacts = <Artifact>[];
    for (final entity in model.entities) {
      final lines = <String>['Entity: ${entity.name} (${entity.id})', 'Fields:'];
      for (final field in entity.fields) {
        lines.add('  - ${field.name} (${field.type.name}${field.required ? ', required' : ''})');
      }
      entityArtifacts.add(
        Artifact(id: '${entity.id}.summary', path: 'summary/${entity.id}.txt', kind: ArtifactKind.file, content: lines.join('\n')),
      );
    }

    // Diagnostics for concepts this minimal reference generator honestly
    // cannot represent — never a silent skip.
    if (model.services.isEmpty && model.entities.isNotEmpty) {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.skippedFeature,
          message: 'No Service groupings present — manifest lists entities only.',
        ),
      );
    }

    final manifestLines = <String>[
      'CanonicalImplementationModel Summary',
      'Entities: ${model.entities.length}',
      'Repositories: ${model.repositories.length}',
      'Controllers: ${model.controllers.length}',
      'Services: ${model.services.length}',
      'Dependencies: ${model.dependencies.length}',
      'Requires authentication: ${model.authentication.requiresCredentials}',
      'Requires background sync: ${model.backgroundWorker.requiresBackgroundSync}',
    ];
    final manifestArtifact = Artifact(
      id: 'manifest',
      path: 'summary/manifest.txt',
      kind: ArtifactKind.manifest,
      content: manifestLines.join('\n'),
    );

    return GenerationResult(
      artifactGroups: [
        ArtifactGroup(id: 'entities', artifacts: entityArtifacts),
        ArtifactGroup(id: 'manifest', artifacts: [manifestArtifact]),
      ],
      diagnostics: diagnostics,
    );
  }
}
