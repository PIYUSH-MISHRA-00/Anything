# Canonical Generation Specification — Implementation Milestone R12

## Overview

R10 built the Generator Framework and one reference generator
(`SummaryManifestGenerator`) that worked, but hardcoded its own
artifact-naming decisions directly in Dart code (`path:
'summary/${entity.id}.txt'`, string-interpolated by hand). R11 gave
generators a real dependency graph but didn't touch this. R12 closes the
gap the milestone's own text names precisely: the framework had no
declarative answer to "how does a graph concept become a generated
artifact" — that knowledge lived inside each generator's own logic,
which does not scale past one trivial reference implementation.

R12 introduces `lib/generation_specification/` — a real, typed,
language-independent contract for exactly that question — and
**genuinely refactors** `SummaryManifestGenerator` to consume it,
rather than adding new, unused sibling types beside the old hardcoded
logic.

## Investigation: no reusable mapping/template concept existed

Searched broadly (`lib/synthesis/`, `lib/creation/`, `lib/runtime/`) for
any existing Mapping/Transformation/Template/Projection/Emitter concept.
`lib/runtime/component_registry.dart`'s `RuntimeComponentRegistry` is
the closest DESIGN precedent — a closed, declarative "component kind →
concrete widget" registry — but it is Flutter-widget-specific and not
reusable directly; only its SHAPE (a real, closed, typed "kind maps to
concrete output" registry) informed this milestone's design.
`lib/screens/templates_screen.dart` is part of the dead, unreferenced
v1 tree (MIS-1 Part 1) and is not a real precedent. No duplication
occurred — this is genuinely new, sanctioned work.

## The specification (`lib/generation_specification/`)

- `path_template.dart` — `PathTemplate`, a real, minimal, deterministic
  `{id}`/`{label}` string-substitution rule. Deliberately NOT a general
  templating engine (no conditionals, no loops, no expressions) — a
  bounded, real, checkable string-replace over already-validated
  `BuildGraphNode` id/label data, never capable of path traversal or
  arbitrary evaluation.
- `generation_specification.dart` — `ArtifactMapping` (a `PathTemplate` +
  the real, existing `ArtifactKind` name a matching node becomes),
  `GenerationRule` (nodes of a given `BuildNodeKind` (R11) each produce
  one artifact via a mapping), `GenerationSpecification` (the real,
  inspectable, top-level rule set a `Generator` consumes, plus a
  separate `manifestPathTemplate` for the one real aggregate artifact
  that isn't derived from a single graph node).

## The refactor: `SummaryManifestGenerator` genuinely consumes it

`SummaryManifestGenerator` now takes an injected
`GenerationSpecification` (`this.specification = 
GenerationSpecification.defaultReference`). Its `generate()` method:

- Looks up `specification.ruleFor(BuildNodeKind.entity)` to decide
  WHETHER entity nodes produce an artifact at all (previously implicit,
  via an unconditional `for (final entity in model.entities)` loop) —
  and, when a rule exists, resolves each entity's real artifact path
  through the rule's `PathTemplate` instead of hardcoded interpolation.
- Resolves the manifest artifact's path through
  `specification.manifestPathTemplate`.
- **Content assembly deliberately stays real generator logic.** Turning
  an entity's real fields into human-readable summary lines is genuine
  data-shaping behavior — forcing it into "specification" data would
  mean either fabricating a real template ENGINE (explicitly out of this
  milestone's scope) or a rule type with no honest declarative meaning.
  The boundary drawn here — WHICH node kinds get artifacts and WHERE
  they go is declarative; WHAT the content says remains the generator's
  job — is the real, defensible line this milestone draws, not an
  arbitrary one.

`GenerationSpecification.defaultReference` reproduces
`SummaryManifestGenerator`'s exact pre-R12 hardcoded paths
(`summary/{id}.txt` per entity, `summary/manifest.txt`) — proven by a
dedicated regression-equivalence test
(`test/r12_generation_specification_test.dart`) that the refactor moved
WHERE the naming decision lives without changing WHAT it produces. A
second test proves a genuinely DIFFERENT specification measurably
changes the generator's real output — the strongest possible proof this
is real consumption, not decoration.

## Determinism

`PathTemplate.resolve()` and the generator's own logic add no
randomness, timestamps, or I/O. The same `(BuildGraph, 
GenerationSpecification)` always produces a structurally identical
`GenerationResult`, proven directly by a dedicated test.

## Engineering Memory / World Model: deliberately NOT extended this milestone

Investigated and declined, mirroring R10/R11's own precedent exactly. A
`GenerationSpecification` is architecturally closer to CODE than to
per-Experience durable knowledge: `GenerationSpecification.defaultReference`
is a `const`, generator-owned ruleset, not derived from or varying per
`CanonicalImplementationModel`/`UniversalBuildGraph` — every generation
run for every Experience uses the same specification unless a caller
explicitly supplies a different one at the call site. There is nothing
per-Experience to persist, and nothing durable/semantic about a fixed
ruleset a future generator's own source code will simply declare. This
should be revisited only if a real future generator's specification
genuinely becomes per-Experience-derived (not yet the case for anything
in this codebase).

## AI boundary

Zero new LLM calls anywhere in this milestone. `PathTemplate.resolve()`
and `SummaryManifestGenerator.generate()` are both pure functions of
their inputs.

## Known limitations

1. Content assembly (as opposed to naming/paths) is not covered by the
   specification — a real, honest, named boundary (see above), not a
   silent gap.
2. `GenerationSpecification` currently has real rule coverage for one
   `BuildNodeKind` (`entity`) — `repository`/`controller`/`capability`
   nodes have no declared rule and are honestly not emitted by the
   reference generator, matching its own pre-R12 scope exactly (it
   never emitted artifacts for these either). A real future generator
   with a genuine need for these would add real rules for them.
3. `ModuleMapping`/`PackageMapping`/`ResourceMapping`/`CapabilityMapping`/
   `DependencyMapping`/`LifecycleMapping`/`ConfigurationMapping`/
   `BuildMapping`/`ValidationMapping` (named in the milestone's own
   spec) are NOT modeled — no real generator behavior anywhere in this
   codebase demonstrates a genuine need for them yet; building them now
   would mean fabricating rule shapes with nothing real to validate
   against, violating this project's established "never fabricate"
   discipline (R9/R10/R11 precedent).
4. Only one reference generator exists — "used by every future language
   generator" remains structurally sound but proven by exactly one,
   deliberately trivial, consumer.

## Recommendation for R13

1. A real target-language generator remains the highest-value next step
   — it would be the first real pressure-test of whether
   `GenerationSpecification`'s current rule shape (path/naming only)
   is sufficient, or whether a real generator's genuine needs (e.g. real
   content templates, real per-file-type rules) motivate extending it
   with real, justified depth.
2. Revisit the deferred mapping types (Module/Package/Resource/
   Capability/Dependency/Lifecycle/Configuration/Build/Validation
   Mapping) once a real generator actually needs them — never
   speculatively.
