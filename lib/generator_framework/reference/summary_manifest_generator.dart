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
///
/// Implementation Milestone R12: artifact PATHS/NAMING are no longer
/// hardcoded here — they are read from a real, injected
/// [GenerationSpecification] (`lib/generation_specification/`),
/// defaulting to [GenerationSpecification.defaultReference] (the exact
/// pre-R12 path shape, so this default construction's OBSERVABLE
/// behavior is unchanged — proven directly by this milestone's own
/// regression-equivalence test). Content ASSEMBLY (turning an entity's
/// real fields into summary text lines) deliberately remains real
/// generator logic — genuine data-shaping behavior a declarative path
/// rule cannot honestly represent without becoming a template engine
/// (explicitly out of scope) — see
/// `docs/architecture/GENERATION_SPECIFICATION.md` for the full,
/// honest boundary.
library;

import '../../generation_specification/generation_specification.dart';
import '../../build_graph/build_graph.dart';
import '../artifact.dart';
import '../generation_result.dart';
import '../generator.dart';

class SummaryManifestGenerator implements Generator {
  final GenerationSpecification specification;

  const SummaryManifestGenerator({this.specification = GenerationSpecification.defaultReference});

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

    // Implementation Milestone R12: WHETHER entity nodes get an artifact
    // at all, and WHERE, is now a specification decision — never a
    // hardcoded `for (final entity in model.entities)` assumption alone.
    final entityRule = specification.ruleFor(BuildNodeKind.entity);
    final entityArtifacts = <Artifact>[];
    if (entityRule != null) {
      for (final entity in model.entities) {
        final lines = <String>['Entity: ${entity.name} (${entity.id})', 'Fields:'];
        for (final field in entity.fields) {
          lines.add('  - ${field.name} (${field.type.name}${field.required ? ', required' : ''})');
        }
        final path = entityRule.mapping.pathTemplate.resolve(id: entity.id, label: entity.name);
        entityArtifacts.add(
          Artifact(id: '${entity.id}.summary', path: path, kind: ArtifactKind.file, content: lines.join('\n')),
        );
      }
    } else {
      diagnostics.add(
        const GenerationDiagnostic(
          severity: DiagnosticSeverity.info,
          category: DiagnosticCategory.skippedFeature,
          message: 'Specification declares no rule for BuildNodeKind.entity — entity summaries skipped.',
        ),
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
      path: specification.manifestPathTemplate.resolve(id: 'manifest', label: 'manifest'),
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
