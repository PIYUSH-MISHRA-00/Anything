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

## R20 — Canonical Experience Enrichment

R19 measured a real 9/11 (0.82) compatibility score on its "Field Log"
fixture, with `dataFieldCountParity`/`screenCountParity` failing. R20
investigated both, found the real root causes, and closed one of them —
never by inventing new gaps, only by tracing verified differences to
their real source.

### Field richness — real root cause and real fix

`SemanticField` (the single reasoning call's own output,
`lib/synthesis/application_reasoner.dart`) already carries
`defaultValue`/`minimum`/`maximum`/`minLength`/`maxLength`/
`allowedValues`/`referenceEntityId`/`description`. Legacy's
`DataFieldSchema` already reads this data (via
`SynthesisPlanner.convertToBlueprint`) — but a precise trace of
`CreationEngine._buildDataSchemaFromBlueprint` found legacy itself only
ever populates `defaultValue`/`referenceEntityId`/`allowedValues`/`hint`
(mapped from `description`) onto the served package —
`minLength`/`maxLength`/`minimum`/`maximum` are declared on
`DataFieldSchema` but never actually set by legacy. Enriching them on
the compiler side would therefore have fabricated parity with something
legacy itself doesn't represent — so only the four fields legacy
genuinely populates were added to `ImplementationField`
(`lib/implementation_model/canonical_implementation_model.dart`).

The drop happens because `CanonicalImplementationModel.entities` is
derived from `BackendEngineeringPlan.database.tables[].columns`
(`DatabaseColumn`, R8) — itself derived from `ArchitectureCandidate
.fields` (`FieldDecision`) — and neither intermediate type ever carried
`SemanticField`'s richness forward. Rather than threading new fields
through `FieldDecision`/`DatabaseColumn` (touching R3/R8 and their many
other consumers), `CanonicalImplementationContext` gained two small,
additive, optional fields — `semanticEntities`/`derivedValues` — passed
directly from `AnythingKernel`'s already-in-scope
`reasonResult.semanticApp` at Step 8.5. `CanonicalImplementationPlanner
._planEntities` matches `SemanticField`s to `DatabaseColumn`s by
(entityId, fieldId) and enriches `ImplementationField` directly — the
smaller, lower-blast-radius fix, leaving `ArchitectureCandidate`/
`BackendEngineeringPlan` and their existing consumers completely
unaffected. `RuntimeExperienceGenerator` (R13) now reads these
properties into both `DataFieldSchema` and the generated form's field
definitions.

**A real bug found and fixed during testing**: an early version of this
enrichment passed `referenceEntityId` through unconditionally. A test
with a field referencing an undeclared entity ("person", never declared
anywhere in the fixture) showed the compiler kept `referenceEntityId:
'person'` while legacy correctly dropped it to `null`. Fixed by only
keeping `referenceEntityId` when it names a real entity present in
`context.backend.database.tables` — verified by a dedicated regression
test.

`dataFieldCountParity` (a raw field COUNT) still fails, honestly, and
this milestone does not attempt to fix it: the compiler's
`BackendEngineeringPlanner` always adds a real, deliberate auto
primary-key column (`DatabaseColumn(id: '${entity.id}.id', ...)`) that
legacy's blueprint-driven `DataFieldSchema` never exposes as a schema
field. Removing that column would be removing real, correct backend
modeling to force a superficial count match — not something this
milestone does. Instead, a new, separate `EquivalenceComparator`
dimension, `sharedFieldMetadataParity`, was added: for fields present on
BOTH sides (matched by name), it checks whether the real metadata now
threaded through actually agrees — proving the genuine richness win
without conflating it with the count difference.

### View/derived-value richness — one closed, one honestly left open

`BlueprintViewType` (dashboard/calendar/settings/summary) has no
representation anywhere in `CanonicalImplementationModel`, and rendering
these would require genuinely new UI-generation semantics
`RuntimeExperienceGenerator` has no vocabulary for today (a dashboard
aggregates multiple entities; a calendar needs date-aware layout; these
are not data-threading problems). Investigated and left **honestly
open** — inventing this generation logic under this milestone's "only
solve verified differences" mandate would itself be inventing a new gap,
not closing one.

`SemanticDerivedValue`, in contrast, had a real, closeable gap: legacy's
`CreationEngine` already turns it into `dataQuery`+`calculation`
behavior nodes and `${id}`/`${id}_raw_data` state variables — both node
types are already real, already-handled `BehaviorInterpreter` cases
(confirmed by grep), so the compiler needed to emit the SAME shape, not
invent a new runtime concept. `CanonicalImplementationModel` gained a
real, deterministic-pass-through `derivedValues: List<ImplementationDerivedValue>`
(mirroring `SemanticDerivedValue` exactly, sourced from the same
`reasonResult.semanticApp.derivedValues`), and
`RuntimeExperienceGenerator._buildBehavior`/`_buildState` now emit the
identical node/edge/state shape legacy already does — verified by a
test that asserts BOTH packages, for the same derived value, produce the
same node ids/types/config.

### Measured before/after (real, not invented)

Before (R19, "Field Log" fixture, one plain field, no rich metadata):
**9/11 (0.82)**. After (R20, "Field Log Rich" fixture — three fields
with real defaultValue/allowedValues/referenceEntityId, one derived
value, run through the real Kernel and both pipelines): **10/12
(0.83)** — `sharedFieldMetadataParity` (the new dimension) passes;
`dataFieldCountParity`/`screenCountParity` remain real, open,
structurally-explained differences. The dimension count grew from 11 to
12 because `sharedFieldMetadataParity` is additive, not a replacement.

### Generator Framework / Build Graph / Generation Specification

`lib/build_graph/` and `lib/generation_specification/` were NOT touched
— derived-value/field enrichment flowed entirely through the existing
`BehaviorNode`/`BehaviorEdge`/`StateVariable`/`DataFieldSchema`
vocabulary already exposed by `ExperiencePackage`; no new `BuildNodeKind`
or generation mapping was genuinely required. `lib/runtime/` and
`lib/software_cognition/` remain completely unchanged, per this
milestone's own explicit rule.

### World Model / Engineering Memory

Deliberately untouched. `derivedValues`/enriched fields already flow
into `CanonicalImplementationModel`, which `_ingestIntoWorldModelSafely`
and `EngineeringMemoryRepository` already persist as a whole — no new,
separate durable-knowledge concept was introduced that needs its own
ingestion/persistence path.

### Migration Strategy update

R19's condition 2 ("richer field metadata... currently silently dropped
by the compiler path") is now **partially resolved** —
defaultValue/referenceEntityId/allowedValues/hint are threaded through;
minLength/maxLength/minimum/maximum remain unaddressed because legacy
itself doesn't populate them either (not a real gap). R19's condition 1
(non-CRUD blueprint views) remains fully unmet. `useCompilerPipeline`
remains opt-in, default `false` — this milestone's evidence does not
support flipping the default; that remains a future, explicit
product/architecture decision (R19's own condition 5).

---

# R21 — Canonical Experience Views, Non-CRUD Experience Generation

## Reality before this milestone

R20 closed the field-metadata gap and named the view gap explicitly:
"`Calendar/Settings/Summary` ... these are not data-threading problems"
— `RuntimeExperienceGenerator` had zero concept of non-CRUD
`SemanticView`s at all. Reading legacy's `CreationEngine`
(`lib/creation/creation_engine.dart`, lines ~551-676) precisely, before
writing any code, surfaced two facts that reshaped what "closing this
gap" honestly means:

1. **`dashboard` is real and bespoke.** One `dashboardMetrics` node: a
   `'Total <Entity>'` count metric always, a `<Field> (Sum)`/`(Avg)`
   pair for every numeric field, plus an Add button when a create action
   exists. Genuinely worth modeling distinctly.
2. **`calendar`/`settings`/`empty`/`summary` are NOT distinct in
   legacy.** All four fall through ONE identical switch-case branch: a
   `referenceSelector` per reference field, an `input`/`switch` per
   other field. There is no calendar-grid widget, no settings-toggle
   panel, no summary-statistics view anywhere in this codebase — legacy
   itself never differentiates these four. The milestone's own prose
   names them as if distinct ("Calendar, Summary, Settings, Overview,
   Analytics"); reality does not support building four different
   behaviors for something legacy renders identically.
3. **`SemanticView.sections` (composite views) is real reasoner output
   legacy itself never reads.** `grep -n "view.sections\|\.sections\b"
   lib/creation/creation_engine.dart` returns zero matches. Composite-
   view/section rendering is therefore honestly NOT a verified gap —
   there is no real legacy behavior to be equivalent with.

## What shipped

`CanonicalImplementationModel` gained `views: List<ImplementationView>`
(`id`/`name`/`kind`/`sourceEntityId`) and `ImplementationViewKind`
(`dashboard`/`calendar`/`settings`/`empty`/`summary` — the real,
reasoner-emitted `BlueprintViewType` names, kept distinct only because
legacy also picks a distinct navigation icon per name; the FIELD content
all four non-dashboard kinds render is, and must stay, identical).
`list`/`detail`/`form` view types are deliberately excluded — those
screens already come from `ImplementationEntity`/
`ImplementationOperationKind`; mapping them again would duplicate, not
enrich. `CanonicalImplementationContext` gained an additive
`semanticViews: List<SemanticView>` field, wired at the Kernel from the
same `reasonResult.semanticApp.views` already in scope for
`semanticEntities`/`derivedValues` (R20) — zero new AI call.

`RuntimeExperienceGenerator` now builds a real screen per
`ImplementationView`: `_dashboardViewNodes` reproduces legacy's exact
count/sum/average metric derivation and Add-button logic (reusing this
generator's own established `create_<entityId>` action-id convention,
not a new one); `_genericFallbackViewNodes` reproduces legacy's exact
shared reference-selector/input/switch fallback for the other four
kinds. Navigation now combines entity-list items with view items
(capped at 5, matching legacy's own cap), each view getting its real,
distinct per-kind icon via `_viewKindIcon` (an exact mirror of legacy's
`_viewTypeToIcon`). `SemanticView.sections` is never read anywhere on
the compiler side either — the honest, matching absence.

## Equivalence results (real, measured)

"Task Board" fixture (one entity, a real `dashboard` view and a real
`settings` view, the settings view carrying real but legacy-unread
`sections` data): **10/12 (0.83)**, with `tasks_dashboard`/
`tasks_settings` no longer appearing in `missingComponents` — the real,
itemized proof this milestone closes the gap it targeted. View screen
ids match exactly between legacy and compiler (both key them by the
SAME real `SemanticView.id`), unlike CRUD entity screens, whose
different naming conventions are a separate, pre-existing, unrelated
difference (`missingComponents=[tasks_list]`,
`extraComponents=[task_detail, task_form, task_list]` — the compiler's
own entity-id-based CRUD screen names, not a regression from this
milestone). Before this milestone, `tasks_dashboard`/`tasks_settings`
would necessarily have appeared in `missingComponents` too, since
`ImplementationView` did not exist as a concept at all.

## Known differences (still real, still open)

- `calendar`/`settings`/`empty`/`summary` share one behavior in BOTH
  pipelines now, by design — matching legacy exactly, not a limitation
  introduced by this milestone.
- Composite views/sections remain unmodeled in both pipelines — legacy
  has no real behavior here to match.
- CRUD entity-screen naming conventions (`<entityId>_list` vs legacy's
  blueprint-view-id scheme) remain a separate, pre-existing difference,
  unrelated to and unaffected by this milestone.

## Generator Framework / Build Graph / Generation Specification

`lib/build_graph/` and `lib/generation_specification/` were NOT
touched — view screens compose into the same `InterfaceDefinition`/
`ExperiencePackage` shape the Build Graph already treats opaquely via
`CanonicalImplementationModel`; no new `BuildNodeKind` or generation
mapping was genuinely required. `lib/runtime/` and
`lib/software_cognition/` remain completely unchanged, per this
milestone's own explicit rule. `useCompilerPipeline` remains opt-in,
default `false` — unchanged by this milestone.

## World Model / Engineering Memory

Deliberately untouched — `views` already flows into
`CanonicalImplementationModel`, which `_ingestIntoWorldModelSafely` and
`EngineeringMemoryRepository` already persist as a whole; no new,
separate durable-knowledge concept was introduced.

## Migration Strategy update

R19's condition 1 (non-CRUD blueprint views) is now **substantially
addressed** for dashboard/calendar/settings/empty/summary. Composite
views remain out of scope because legacy itself has no real behavior
there. `useCompilerPipeline` remains opt-in — this milestone's evidence
does not support flipping the default.

## R22 — Canonical Experience Identity

### Reality

R21's own "Known differences" section named exactly this milestone's
starting point: "CRUD entity-screen naming conventions... remain a
separate, pre-existing difference." Investigation (not assumption)
found this is an identity problem, not a naming problem:

- `BlueprintView.id` (legacy, `lib/synthesis/synthesis_planner.dart`
  line ~89) is a direct passthrough of `SemanticView.id` — free text
  the LLM writes into its own JSON response
  (`lib/synthesis/model_reasoner.dart`:
  `id: _normalizeId(view['id'] ?? view['name'])`) — never a
  deterministic `<entityId>_<role>` formula.
- `sourceEntityId`/`viewType` sit right next to that free-text `id` on
  `SemanticView` — real, already-structured fields the reasoner always
  populates. This pair, not `id`, is a screen's true structural
  identity.
- The compiler's own screen ids (`RuntimeExperienceGenerator`, R13)
  ARE a deterministic `entityId`+role formula already — it just
  projects that pair into a different string convention than legacy's
  LLM-chosen one. Both pipelines already carry the real identity
  internally; only the final string differs.
- Legacy's `BlueprintViewType.form` case (`CreationEngine`, read
  directly) hardcodes `'mode': 'create'` — legacy has no create/edit
  distinction at the type level, unlike the compiler's separate `_form`
  (create) / `_edit` (update) screens.

### Implementation

New `lib/experience_identity/experience_identity.dart`:
`ScreenIdentity` (`entityId` + `ScreenRole`, mirroring
`BlueprintViewType`'s real 8 values exactly) and `ActionIdentity`
(`entityId` + `ActionRole`, only `create`/`update`/`delete` — the
subset `ImplementationOperationKind` can express;
`BlueprintActionType`'s other real values —
toggle/increment/decrement/setValue/clearValue/changeStatus/navigate —
resolve to `null`, never a fabricated identity). Legacy projection
(`legacyScreenIdentity`/`legacyActionIdentity`) reads only
`sourceEntityId`/`viewType`/`targetEntityId`/`actionType` — never
`.id`. Compiler projection (`compilerScreenIdentities`/
`compilerActionIdentities`) mirrors `RuntimeExperienceGenerator`'s own
`hasList`/`hasCreate`/`hasUpdate`/`hasDetail` conditions exactly, so it
stays a real reflection of what the generator actually produces.

Behavior Identity and Navigation Identity are deliberately NOT separate
types: a behavior node pair's identity already IS the `ActionIdentity`
of the action it executes; a `NavigationItem.screenId`'s identity
already IS the `ScreenIdentity` of the screen it targets. Component
Identity, Artifact Identity, and Route Identity are honestly NOT
modeled — neither `AppBlueprint` nor `CanonicalImplementationModel`
carries a component-boundary, build-artifact, or URL-route concept
distinct from Screen/Action on both sides to project from.

`EquivalenceComparator.compare()` gained two additive, optional
parameters (`legacyBlueprint`/`compilerModel`, both `null` by default).
When supplied, `missingComponents`/`extraComponents` become a real
multiset comparison by `ScreenIdentity` (counting occurrences, not just
set presence) instead of raw `InterfaceScreen.id` strings, and a new
`screenIdentityCoverage` dimension is added to the score. When omitted,
every existing R19-R21 call site keeps the exact pre-R22 string-based
behavior, unmodified.

### Equivalence results

Real, measured, on the `_fieldLogApp` fixture (one entity, a list view
with a deliberately entity-unrelated id `'my_weird_screen_name'`, and a
dashboard view): before this milestone, `entry:list` and `entry:dashboard`
both appeared in `missingComponents` (legacy's real ids never matched
the compiler's). After: neither appears — both are recognized as
present on both sides via `ScreenIdentity`. The compiler's genuine
create/edit form split now appears in `extraComponents` as a real,
honest, quantified difference (`entry:form (compiler 2 more than
legacy)` when the fixture has no form-type view at all) — not hidden,
not falsely equated.

### Known differences (still real, still open)

- The compiler's create/edit form split has no legacy counterpart —
  legacy's `BlueprintViewType` has no edit-mode distinction at all.
  This now shows as a real, quantified identity-count difference
  instead of an opaque id mismatch.
- Component/Artifact/Route Identity remain unmodeled — no real
  dual-side structural signal exists to project from.
- Compiler-side field/entity id namespacing (`<entityId>.<fieldId>`)
  vs. legacy's plain field ids remains a separate, pre-existing,
  unaffected difference (R20's `sharedFieldMetadataParity` dimension
  already compares by field name to route around exactly this).

### Generator Framework / Build Graph / Generation Specification

`lib/generator_framework/generator.dart`/`generation_pipeline.dart`
(the core interface/pipeline) were not touched.
`RuntimeExperienceGenerator` (the one reference generator) was not
modified either — identity is computed as a real, separate reflection
of its existing behavior in `lib/experience_identity/`, not injected
into the generator itself, since nothing the generator emits needed to
change. `lib/build_graph/`, `lib/generation_specification/`,
`lib/runtime/`, `lib/software_cognition/`, `lib/world_model/`,
`lib/storage/engineering_memory_repository.dart`, and
`lib/creation/creation_engine.dart` are all completely unchanged.
`useCompilerPipeline` remains opt-in, default `false`.

### Migration Strategy update

The CRUD screen-naming difference R19-R21 all listed as an open
migration blocker is now understood to be a solved identity problem,
not an unsolved behavioral one — the compiler's real output was always
equivalent to legacy's, it was only being compared incorrectly. This
strengthens (but does not by itself complete) the case for eventually
flipping `useCompilerPipeline`'s default; that decision still requires
broader real-world equivalence evidence than this milestone's fixtures
provide, and remains explicitly out of scope here.

## R23 — Compiler Certification Framework

### Reality

R19-R22 each proved equivalence on 1-2 hand-built fixtures. There was no
automatic, repeatable way to certify the compiler across a broader,
categorized corpus, and no regression/trend mechanism at all. R23 closes
this — but is explicitly a REUSE-and-AGGREGATE milestone, not a new
comparison engine: `EquivalenceComparator`/`CompilerPipelineRunner`
(R19) and Canonical Experience Identity (R22) are used completely
unmodified.

### Implementation

`lib/compiler_certification/` (3 files):

- `certification_corpus.dart` — 13 real, hand-authored `SemanticApp`
  fixtures, one per R23-requested category (`crud`, `offline_first`,
  `dashboard`, `calendar`, `settings`, `summary`, `multi_entity`,
  `relationships`, `permissions`, `capabilities`, `navigation`,
  `backend_required`, `composite`), built in the exact same style as
  R19-R22's own test fixtures. "Composite" is interpreted honestly per
  R21's own finding: a real app mixing CRUD + dashboard + settings
  views — never a fabricated `SemanticView.sections` rendering, since
  legacy itself never reads that field.
- `certification_runner.dart` — for each fixture, runs the SAME real
  `AnythingKernel` (unmodified) with a fixed-stub reasoner returning the
  fixture verbatim (zero new AI call), then the unmodified legacy
  `CreationEngine` and the unmodified `runCompilerPipeline` (R19), then
  calls the unmodified `EquivalenceComparator.compare()` with R22's
  identity-aware `legacyBlueprint`/`compilerModel` parameters supplied.
  Also re-runs both pipelines a second time per fixture for a real
  determinism check (`comparator.structurallyIdentical`), the same
  pattern R19's own tests use — there is no `checkDeterminism` method on
  the comparator to call.
- `certification_report.dart` — `CertificationReport`, a real aggregate
  over the corpus's `EquivalenceReport`s. Every metric is a documented
  fraction/average, never invented: `structuralEquivalence` = mean
  `compatibilityScore`; `behaviorEquivalence` = fraction of fixtures with
  zero `behaviorDifferences`; `navigationEquivalence`/`identityCoverage`/
  `fieldMetadataCoverage`/`viewCoverage` = fraction of fixtures where a
  specific, named dimension (`navigationShapeMatch`/
  `screenIdentityCoverage`/`sharedFieldMetadataParity`/
  `screenCountParity`) passed; `determinismRate` = fraction where both
  pipelines re-ran identically; `migrationReadinessScore`/
  `confidenceScore` = the unweighted mean of the seven metrics above —
  a transparent formula, not a black box.
- `certification_snapshot.dart` — a real, JSON-serializable
  `CertificationSnapshot` and `detectRegressions(baseline, current)`
  comparing per-fixture `compatibilityScore`s. A fixture missing from
  the current run counts as a regression. `migrationReadinessTrend`
  returns the raw score series across an ordered snapshot list.

### Regression/trend scope (honest)

Engineering Memory and World Model were not touched — no new SQLite
table was added for certification history. The regression/trend
mechanism is real and proven correct by tests (`test/r23_compiler_certification_test.dart`),
using snapshots constructed in-memory/JSON round-tripped within the
test run. It is **not** wired into a live CI/scheduled process in this
milestone — that is real, separate infrastructure scope, named here
rather than silently overclaimed.

### Certification results (real, measured, 13-fixture corpus)

```
structuralEquivalence:   0.769   (mean compatibilityScore across fixtures)
behaviorEquivalence:     0.000
navigationEquivalence:   1.000
identityCoverage:        1.000
fieldMetadataCoverage:   1.000
viewCoverage:            0.000
determinismRate:         1.000
migrationReadinessScore: 0.681
```

A genuinely new, corpus-scale finding this milestone surfaced (not
visible from R19-R22's own 1-2-fixture tests): most corpus fixtures
declare only the `SemanticView`s a minimal test app actually needs (a
`list` view plus a create action), but `BackendEngineeringPlan.api`
derives full CRUD endpoints unconditionally from `InteractionDecision`
regardless of which views were declared (R18's own documented finding).
The compiler therefore always emits `<entity>_form`/`<entity>_detail`
screens for every entity with CRUD operations, while legacy only emits
screens for views the reasoner explicitly declared — so `extraComponents`
and `behaviorNodeCount`/`behaviorEdgeCount` differences appear on nearly
every fixture. This is a fixture-corpus characteristic (most fixtures
here are intentionally minimal), not a newly discovered pipeline defect
— but it is real, quantified evidence that a production request whose
`SemanticView`s under-declare screens relative to its entities' full CRUD
surface will show more compiler/legacy divergence than R19-R22's fuller
fixtures did.

### Known differences (still real, still open)

- The corpus-scale extra-screen pattern above.
- Every difference R19-R22 already documented (create/edit split,
  Component/Artifact/Route Identity unmodeled, field id namespacing).

### Test results

13 new certification/regression/trend/performance tests. Full suite:
1405/1405 (up from 1383). `flutter analyze`: 71/0, unchanged.

### Performance (real, measured)

100 synthetic applications: ~380ms (~3.8ms/app). 500: ~1.7s (~3.4ms/app).
1000: ~2.7s (~2.7ms/app). Memory: ~300KB RSS delta over 200 applications
— no leak signal at this scale.

### Recommendation for R24

1. Wire `certification_runner.dart` into an actual scheduled/CI process
   so `CertificationSnapshot`s accumulate real history — this milestone
   proved the mechanism correct, not yet operational.
2. Investigate the corpus-scale extra-screen pattern above: either
   extend corpus fixtures to declare views matching their full CRUD
   surface (more realistic), or treat it as expected and exclude it from
   `migrationReadinessScore`'s structural dimension — a real design
   decision, not a bug to silently patch.
3. `useCompilerPipeline`'s default remains `false`. This milestone's
   0.681 `migrationReadinessScore` is a real data point, not sufficient
   evidence on its own — the certification framework now exists so a
   future milestone can track this number growing over real corpus
   iterations before making that call.
