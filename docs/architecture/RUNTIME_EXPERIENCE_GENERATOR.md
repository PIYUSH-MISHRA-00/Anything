# Runtime Experience Generator — Implementation Milestone R13

## Overview

R9-R12 built the full generator ARCHITECTURE — a language-independent
intermediate representation (`CanonicalImplementationModel`, R9), a
dependency graph over it (`UniversalBuildGraph`, R11), a declarative
path/naming contract (`GenerationSpecification`, R12), and the one
canonical `Generator` interface + pipeline (R10) — but every real
`Generator` implementation that existed before this milestone
(`SummaryManifestGenerator`) was deliberately trivial: plain text
summaries, never anything a runtime could load and run.

R13 closes the loop with the first real, substantial generator:
`RuntimeExperienceGenerator`
(`lib/generator_framework/reference/runtime_experience_generator.dart`).
It consumes a real `CanonicalImplementationModel` (via
`UniversalBuildGraph.sourceModel`) and produces a real, valid
`ExperiencePackage` — the SAME, existing, unmodified declarative format
`ExperienceRenderer`/`BehaviorInterpreter`/`AnythingRuntime`/
`ExperienceHostScreen` already know how to load and run. This is
explicitly **not** Flutter/Dart source-code generation and **not**
recompilation — it is a real compiler in the sense the milestone names:
Intent-shaped structure in, a runnable Experience out, through one
deterministic, inspectable pipeline.

## Design: mirrors `CreationEngine`'s conversion shape, different source

`CreationEngine` (`lib/creation/creation_engine.dart`, Vision Milestone
V3) already solves "convert a structured description of an app into an
`ExperiencePackage`" — from `AppBlueprint` (Flutter-package-specific:
entities + typed `BlueprintView`s). `RuntimeExperienceGenerator` solves
the same problem from a different, language-independent source
(`CanonicalImplementationModel`'s entities + `ImplementationController`
operations) and deliberately reuses the same trusted output vocabulary:

- Screen-id convention: `<entityId>_list` / `_form` / `_edit` /
  `_detail` — the exact suffixes `ExperienceHostScreen` already parses
  (`screenId.endsWith('_edit')` / `'_detail'` to load record data;
  `_findFormScreenForAction` matches `_form`).
- Event-id convention: `create_<entityId>` / `update_<entityId>` /
  `delete_<entityId>`, wrapped in a `<eventId>_event` behavior node —
  the exact naming `BehaviorInterpreter._resolveGenericEvent` already
  expects when the renderer dispatches generic `submitForm`/
  `deleteRecord` events.
- Interface node types: `entityList`/`entityForm`/`entityDetail`/
  `searchField`/`button` — the SAME `RuntimeComponentRegistry`/
  `ExperienceRenderer` vocabulary, never a new component type.

The real difference from `CreationEngine` is entirely in the SOURCE
data read, not in the OUTPUT shape produced — confirmed directly by
reading `experience_renderer.dart`/`behavior_interpreter.dart`/
`experience_host_screen.dart` before writing any generation logic
(Rule 3: investigate before implementing).

### Operation-kind -> UI/behavior mapping (real, not fabricated)

For each entity, its `ImplementationController.operations` (already
computed, R9) determine what gets generated — never a hardcoded
assumption that every entity gets every screen:

| Operation kind present | Generated |
|---|---|
| `list` or `search` | A list screen (`entityList`, `searchField` if `search` present, `Add` button if `create` present) |
| `create` | A form screen (`entityForm`, mode `create`) |
| `update` | An edit screen (`entityForm`, mode `edit`) |
| `get` or `delete` | A detail screen (`entityDetail` — its own built-in Edit/Delete buttons are used directly; CreationEngine's redundant standalone delete button, called out in Stage 11's own test comments, is not replicated) |
| none | Entity honestly skipped — a `skippedFeature` diagnostic names it, never a fabricated empty screen |

`list`/`get`/`search` produce **no behavior node** — confirmed by
reading `experience_renderer.dart`: `entityList`/`entityDetail` already
query `ExperienceDataRuntime` live via `runtimeContext`. Only
`create`/`update`/`delete` mutate data and get a real
`event` -> `dataMutation` node pair, matching
`CreationEngine._buildBehaviorFromBlueprint`'s own scope exactly.

### Package-level assembly

- `DataSchema` — a direct, 1:1 mapping of `ImplementationEntity`/
  `ImplementationField` to `DataEntitySchema`/`DataFieldSchema`.
- `StateSchema` — one `searchTerm` session variable whenever any entity
  gets a list screen (the renderer's `entityList` unconditionally reads
  it); no per-field input state (unlike `CreationEngine`'s blueprint
  path) since `entityForm` manages its own internal form controller
  state and never reads per-field global state.
- `NavigationDefinition` — `bottomNavigation` only when more than one
  entity produced a list screen, one item per such entity, matching
  `CreationEngine`'s own "more than one primary destination" threshold.
- `ExperienceManifest.experienceId`/`.name` come from `GeneratorTarget`
  (the only per-run identity `GeneratorContext` carries).
  `PackageProvenance.specVersion`/`.planVersion` have no meaningful
  upstream equivalent in the Generator Framework pipeline
  (`GeneratorContext` carries no spec/plan version of its own) — set to
  `1` honestly, documented in code as a real, named placeholder, never
  fabricated from invented upstream data.

## The artifact: one aggregate `ExperiencePackage`, not per-node files

Unlike `SummaryManifestGenerator` (one text artifact per entity node),
`RuntimeExperienceGenerator` emits exactly ONE `Artifact`
(`ArtifactKind.manifest`, `content: jsonEncode(package.toJson())`) —
this is precisely the case `GenerationSpecification.manifestPathTemplate`'s
own doc comment describes: "a real, generator-produced aggregate over
the whole graph," never derived from one `BuildGraphNode`. The
generator therefore defines its own `defaultSpecification` with only a
`manifestPathTemplate` (`experience/{id}.json`) and no per-node `rules`
— `GenerationSpecification.rules` (R12) remains genuinely unused by
this generator, an honest, structural consequence of the shape of what
it produces, not an oversight.

The generator internally re-validates its own output through the
REAL, unmodified `ExperiencePackageValidator` before returning, turning
any validation failure into a real `GenerationDiagnostic(severity:
error)` rather than silently emitting a broken package — reusing the
existing validation boundary (Rule 1: extend, never replace).

## Honest, named limitations (never fabricated)

`CanonicalImplementationModel` concepts with no real representation in
`ExperiencePackage`'s format are reported via
`GenerationDiagnostic(category: skippedFeature)`, never silently
dropped or invented into fake package structure:

1. DTOs/Validators/Services — `ExperiencePackage` enforces field
   requiredness directly from entity/form field definitions; no
   separate DTO/validator/service layer exists in this format.
2. `StateContainerSpec` transitions — `ExperiencePackage.state` models
   simple session/persistent variables, not a generic state machine.
3. `NavigationHandlerSpec` routes — the generated `NavigationDefinition`
   is derived directly from entity list screens, not from modal/
   deep-link route specs.
4. `AuthenticationAdapterSpec`/`BackgroundWorkerSpec` — noted but not
   modeled; no authentication-UI or background-job concept exists in
   `ExperiencePackage`.

## A real, pre-existing `ExperienceHostScreen` characteristic found (not fixed)

Writing this milestone's own centerpiece widget test surfaced a real
behavior: `ExperienceHostScreen` caches a detail screen's loaded record
keyed only by screen ID (`_detailScreenId != screenId`). For a
single-entity Experience with no bottom navigation, popping back from
an edit screen to the SAME detail screen ID (`list -> detail -> edit ->
pop`) does not re-fetch — the detail view keeps showing its pre-edit
cached record even though SQLite already holds the update. Stage 11's
own certification test never exercises this path; it always leaves and
re-enters a detail screen via a fresh bottom-navigation destination
push in its multi-entity fixture, which resets the cache as a side
effect.

This is a genuine characteristic of the EXISTING, unmodified
`ExperienceHostScreen` — out of scope for R13 per the milestone's own
"existing, unmodified Runtime/Renderer" framing, and this milestone
does not touch `experience_host_screen.dart`. It is named here, plus in
the R13 test file itself, rather than silently worked around: the
correct data-level assertions (SQLite reflects the same record ID with
updated fields) are made directly; the test does not additionally
assert the stale UI reflects the update on that specific screen
instance, and documents exactly why.

## Determinism

`RuntimeExperienceGenerator.generate()` is a pure function of its
`GeneratorContext` for every structural decision — screens, behavior
nodes/edges, state variables, data schema, artifact path — proven by a
dedicated test that runs the same model twice and asserts structurally
identical output. The three real generation-timestamp fields
(`ExperienceManifest.createdAt`/`.updatedAt`,
`PackageIntegrity.computedAt`) use `DateTime.now()`, matching
`CreationEngine`'s own existing, pre-R13 precedent exactly — an honest,
named exception for genuine wall-clock metadata, never a claim that
timestamps themselves are reproducible.

## AI boundary

Zero new LLM calls. `RuntimeExperienceGenerator.generate()` is a pure,
deterministic function of its `GeneratorContext`.

## No duplicate architecture

No second Runtime/Renderer/`ExperiencePackage` type/Kernel/Planner/
Build-Graph/Generator-Framework/Component-Registry/Capability-Platform/
World-Model. `ExperienceRenderer`/`BehaviorInterpreter`/
`AnythingRuntime`/`ExperienceHostScreen`/`RuntimeComponentRegistry`/
`ExperiencePackageValidator` are all read, never modified, by this
milestone.

## Known limitations

1. Only entities with real `list`/`get`/`search`/`create`/`update`/
   `delete` operations produce a UI surface — entities with only
   custom/unrecognized `ImplementationOperationKind` values (there are
   none beyond these six today) would be honestly skipped, not a
   currently-reachable gap.
2. Single-`Artifact`-per-generation output — a real future need for
   multiple physical files per Experience (e.g. splitting a large
   package) is not addressed; no real signal in this codebase currently
   demonstrates that need.
3. The `ExperienceHostScreen` detail-cache characteristic named above
   is real, pre-existing, and unfixed by this milestone (out of scope).

## Recommendation for future milestones

The milestone's own spec ends with an explicit stop instruction; no R14
should begin without new direction. If work resumes on the generator
arc, the highest-value next steps are: (1) a second, genuinely
different real generator (a true test of `Generator`'s "one interface,
many implementations" claim, still proven by exactly one real consumer
of `CanonicalImplementationModel` in `RuntimeExperienceGenerator`'s
class today), and (2) fixing the `ExperienceHostScreen` detail-cache
characteristic named above, as its own, independently-scoped, honestly
justified change — not silently folded into a future generator
milestone.
