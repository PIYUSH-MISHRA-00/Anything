/// Canonical Generation Specification — Implementation Milestone R12.
/// The real, declarative, LANGUAGE-INDEPENDENT contract for HOW a
/// `UniversalBuildGraph` node (R11) becomes a generated [Artifact]
/// (`lib/generator_framework/artifact.dart`, R10) — moving "what becomes
/// an artifact, and where" out of generator code and into real, typed,
/// inspectable rule data. `Generator` implementations (R10) become
/// simple emitters: they read the specification's rules, supply the
/// real content for whatever the rules say should exist, and never
/// themselves decide artifact paths.
///
/// Investigation (Rule 3) confirmed no generic mapping/transformation/
/// template/projection concept exists anywhere else in this codebase —
/// `RuntimeComponentRegistry` (`lib/runtime/component_registry.dart`) is
/// the closest DESIGN precedent (a closed, declarative kind-to-output
/// mapping) but is Flutter-widget-specific and not reusable directly;
/// only its shape — a real, closed, typed "kind maps to a concrete
/// output rule" registry — informs this file's design, never its
/// content. `lib/screens/templates_screen.dart` is part of the dead,
/// unreferenced v1 tree (MIS-1 Part 1) and is not a real precedent.
///
/// Depth is honest, matching R9-R11's established discipline: real
/// coverage for what `SummaryManifestGenerator`'s own existing behavior
/// actually demonstrates a genuine need for — per-node-kind artifact
/// emission and path/naming — never fabricated `LifecycleMapping`/
/// `ConfigurationMapping`/`BuildMapping`/etc. data with no real generator
/// behavior behind it (see Known Limitations,
/// `docs/architecture/GENERATION_SPECIFICATION.md`). Content ASSEMBLY
/// (which fields go into a line of text) deliberately stays real
/// generator logic — it is genuine data-shaping behavior, not a
/// structural mapping rule, and forcing it into "specification" data
/// would mean either fabricating a template engine (explicitly out of
/// scope) or a rule type with no real declarative meaning.
library;

import '../build_graph/build_graph.dart';
import 'path_template.dart';

/// Real, declarative artifact-shape rule: what [ArtifactKind]
/// (`lib/generator_framework/artifact.dart`) a matching node becomes,
/// and where. Values from `ArtifactKind` are the SAME real, existing
/// enum a `Generator` already returns — never a parallel taxonomy.
class ArtifactMapping {
  final PathTemplate pathTemplate;
  final String artifactKind;

  const ArtifactMapping({
    required this.pathTemplate,
    required this.artifactKind,
  });
}

/// One real, typed generation rule: nodes of [nodeKind] each produce one
/// artifact via [mapping]. A `BuildNodeKind` (R11) with no matching rule
/// in a [GenerationSpecification] is honestly NOT emitted — never a
/// silent, undeclared default.
class GenerationRule {
  final BuildNodeKind nodeKind;
  final ArtifactMapping mapping;

  const GenerationRule({required this.nodeKind, required this.mapping});
}

/// The real, top-level, inspectable specification a [Generator] (R10)
/// consumes instead of hardcoding its own path/naming decisions.
/// [manifestPathTemplate] is separate from [rules] since a top-level
/// manifest artifact is not itself derived from one `BuildGraphNode` —
/// it is a real, generator-produced aggregate over the whole graph, only
/// its OWN path is a specification-owned naming decision.
class GenerationSpecification {
  final List<GenerationRule> rules;
  final PathTemplate manifestPathTemplate;

  const GenerationSpecification({
    this.rules = const [],
    required this.manifestPathTemplate,
  });

  /// The real, default specification `SummaryManifestGenerator` (R10)
  /// used when the specification concept didn't exist yet — reproduces
  /// its exact pre-R12 hardcoded paths (`summary/{id}.txt` per entity,
  /// `summary/manifest.txt`), so switching to specification-driven
  /// paths is proven, by a dedicated regression-equivalence test, to
  /// change WHERE the naming decision lives without changing WHAT it
  /// produces.
  static const GenerationSpecification defaultReference =
      GenerationSpecification(
        rules: [
          GenerationRule(
            nodeKind: BuildNodeKind.entity,
            mapping: ArtifactMapping(
              pathTemplate: PathTemplate('summary/{id}.txt'),
              artifactKind: 'file',
            ),
          ),
        ],
        manifestPathTemplate: PathTemplate('summary/manifest.txt'),
      );

  GenerationRule? ruleFor(BuildNodeKind kind) {
    for (final rule in rules) {
      if (rule.nodeKind == kind) return rule;
    }
    return null;
  }
}
