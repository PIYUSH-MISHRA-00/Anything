# Compiler Production Integration — Implementation Milestone R19

## Reality before this milestone

R18 confirmed the R9-R13 compiler chain (`CanonicalImplementationModel` ->
`UniversalBuildGraph` -> `GenerationSpecification` -> `Generator`/
`GenerationPipeline` -> `RuntimeExperienceGenerator` -> `ExperiencePackage`)
was real, deterministic, and fully tested, but had **zero production
callers anywhere in this codebase** — confirmed again, freshly, before
writing any code in this milestone: `grep -rln "GenerationPipeline("
lib/`, `grep -rln "BuildGraphBuilder(" lib/`, and `grep -rln
"RuntimeExperienceGenerator(" lib/` each return exactly one file, their
own definition. The live, user-facing creation path
(`ExperienceCreationCoordinator._createExperience` ->
`CreationEngine.create`, `lib/creation/creation_engine.dart`, Vision
Milestone V3) has always been, and remains by default, what actually
validates/persists/serves an `ExperiencePackage`.

The one structural advantage that made this milestone tractable and
low-risk: both pipelines' real inputs already coexist in a single Kernel
run. `AnythingKernel.processIntent` produces both `kernelOutcome.blueprint`
(`AppBlueprint`, legacy input) and `kernelOutcome.canonicalImplementationModel`
(R9, compiler input) from the SAME one reasoning call — `_createExperience`
already receives both today. An equivalence harness comparing the two
pipelines' output for one real request therefore requires **zero new
AI/reasoning call**.

## What this milestone built

1. **`lib/compiler_integration/compiler_pipeline_runner.dart`** — the
   first, real, production-shaped caller of the compiler chain outside a
   test file: `runCompilerPipeline(CanonicalImplementationModel, {id,
   name})` runs `BuildGraphBuilder().build(model)` ->
   `GenerationPipeline().run(generator: RuntimeExperienceGenerator())` ->
   decodes the one aggregate artifact back into a real `ExperiencePackage`.
   All three pipeline stages are used completely unmodified.
2. **`lib/compiler_integration/equivalence_comparator.dart`** — real,
   itemized structural comparison across 11 individually-checked
   dimensions between a legacy and a compiler `ExperiencePackage` for the
   SAME request: `entityCoverage`, `dataFieldCountParity`,
   `crudCreateCoverage`, `crudUpdateCoverage`, `crudDeleteCoverage`,
   `capabilityCoverage`, `networkModeMatch`, `storageModeMatch`,
   `stateVariableSubset`, `navigationShapeMatch`, `screenCountParity`.
   `compatibilityScore = passed / 11` — a real, computed fraction, never a
   fabricated constant. `structurallyIdentical()` re-verifies determinism
   by stripping only the fields both pipelines document as genuine
   wall-clock metadata (`manifest.createdAt`/`updatedAt`,
   `integrity.computedAt`/`contentHash`) and deep-comparing everything
   else.
3. **ONE production feature flag** — `useCompilerPipeline` (default
   `false`), threaded through `ExperienceCreationCoordinator.createFromIntent`
   /`createFromExpression`/`_createExperience`. When `true` and a real,
   non-empty `CanonicalImplementationModel` is available, the compiler
   pipeline runs first; its package is served ONLY if generation succeeds
   AND it passes the exact same, unmodified `ExperiencePackageValidator`
   the legacy package must also pass. Any failure — no entities, a
   generation error, a validation failure — falls back to the legacy path
   automatically; the flag can never silently break creation. When the
   compiler path is used, it flows through the identical
   persist/World-Model-ingestion/Engineering-Memory code that already
   existed — never a second, parallel serving path.

## Equivalence Testing — real, measured results, not a fabricated 100%

For a real, single-entity, full-CRUD fixture ("Field Log": one entity,
one field, create+delete actions, one list view) run through a real
`AnythingKernel.processIntent` call:

**Compatibility score: 9 / 11 (0.82).** Passed: entityCoverage,
crudCreateCoverage, crudUpdateCoverage, crudDeleteCoverage,
capabilityCoverage, networkModeMatch, storageModeMatch,
stateVariableSubset, navigationShapeMatch. **Failed, real, and expected:**
`dataFieldCountParity` and `screenCountParity` — see Known Differences.

**Determinism score: both pipelines independently re-verified
deterministic** — running each twice on the same input produces
structurally identical output (timestamps aside), confirmed by a real
`structurallyIdentical()` re-check in this milestone's own tests, not
assumed from R13/R17/R18's separate test suites.

## Known Differences (real, permanent, not defects to silently patch)

1. **Screen-id / screen-count scheme.** Legacy generates one
   `InterfaceScreen` per blueprint VIEW (and can produce
   dashboard/calendar/settings/summary views the compiler never
   generates at all — R10-R13 deliberately scoped the compiler to
   CRUD-shaped list/form/edit/detail only). The compiler generates one
   screen set per ENTITY, driven by real `ImplementationOperationKind`
   coverage (`<entityId>_list`/`_form`/`_edit`/`_detail`), independent of
   blueprint views entirely. For the Field Log fixture (one declared
   view), legacy produced 1 screen; the compiler produced 3
   (list/form/detail — no `_edit`, since no update action was declared).
2. **Field-count/richness.** Legacy's `DataFieldSchema` carries
   `defaultValue`/`referenceEntityId`/`allowedValues`/`minLength`/
   `maxLength`/`minimum`/`maximum`/`hint`; `ImplementationField` (R9) only
   carries `id`/`name`/`type`/`required`. Real entity-derivation paths
   (via a real `BackendEngineeringPlanner`-derived `DatabaseSchemaModel`)
   can also add a real primary-key `id` column to the compiler's entity
   fields that a hand-built fixture (like R13's own test) would not show.
3. **State richness.** Legacy adds a state variable per input field, plus
   `current_screen`/`current_record_id`/derived-value variables; the
   compiler adds only `searchTerm` when any list screen exists (an
   intentional design choice — R13's `entityForm` manages its own
   internal form state). The compiler's state is always a strict subset
   of legacy's for the same request — verified, not assumed.
4. **Manifest/provenance metadata.** Legacy derives `category` from the
   blueprint's archetype and copies `tags`; the compiler hardcodes
   `category: 'generated'` and never sets `tags` (R13's own documented,
   honest placeholder). `provenance.creationEngineVersion` differs by
   design (`'1.0.0'` vs `'reference.runtime-experience-1.0.0'`) — this is
   in fact the real, hard signal this milestone's own tests use to prove
   which pipeline actually served a request.
5. **DTOs/Validators/Services/StateContainers/NavigationHandler
   routes/AuthenticationAdapter/StorageAdapter/BackgroundWorker** — R13's
   own long-documented, unchanged limitation: none of these
   `CanonicalImplementationModel` concepts have any representation in
   `ExperiencePackage`'s format at all.

## Migration Strategy — concrete, unmet conditions before Legacy could ever be removed

Legacy is **not** removed or disabled by this milestone (R19's own
"MANDATORY VISION VALIDATION": do not remove Legacy unless equivalence is
objectively demonstrated — even then, removal is explicitly out of this
milestone's scope). Concrete, currently-unmet conditions for a future
removal decision:

1. **Non-CRUD blueprint views** (dashboard/calendar/settings/summary) —
   real production apps using these would need either a compiler
   extension or an accepted, documented functionality loss.
2. **Richer field metadata** (`defaultValue`/`allowedValues`/
   `minLength`/`maxLength`/`minimum`/`maximum`) — currently silently
   dropped by the compiler path; needs either `CanonicalImplementationModel`
   extension (R9-adjacent, out of this milestone) or an accepted UX
   regression.
3. **EngineeringPlan-driven state augmentation**
   (`EngineeringToBlueprintAugmenter`, generic status-tracking state) has
   no compiler-side equivalent at all.
4. **A broader real-world equivalence sample** — this milestone measured
   ONE real fixture shape (single entity, full CRUD). A representative
   corpus across multi-entity/offline/permission-bearing/backend-required
   apps has not yet been measured.
5. **Compatibility score threshold and owner sign-off** — no numeric
   threshold has been set as a go/no-go gate; this is a product/architecture
   decision for a future milestone, not an engineering one.

## World Model / Engineering Memory

Deliberately untouched, per R19's own explicit "Remain unchanged"
instruction. The equivalence harness is a comparison utility; it produces
no durable knowledge of its own to persist.

## AI Boundary

Still exactly one. Every pipeline this milestone compares or invokes is
downstream, deterministic reuse of data the single existing reasoning
call already produced.
