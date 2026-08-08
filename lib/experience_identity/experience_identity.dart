/// CanonicalExperienceIdentity — Implementation Milestone R22. Both the
/// legacy `CreationEngine` pipeline and the compiler (`RuntimeExperienceGenerator`)
/// pipeline already organize every screen/action they produce around the
/// SAME real structural pair: an entity, and a role (list/detail/form/
/// dashboard/...). Neither pipeline needed to invent this — it is the
/// literal shape of `SemanticView`/`SemanticAction`
/// (`lib/synthesis/application_reasoner.dart`), the single existing
/// reasoning call's own output.
///
/// The problem this milestone closes is narrower than it may look: legacy's
/// `BlueprintView.id` (`lib/synthesis/synthesis_planner.dart` line ~89,
/// `id: sv.id`) is a DIRECT passthrough of `SemanticView.id` — free text
/// the LLM itself writes (`model_reasoner.dart`:
/// `id: _normalizeId(view['id'] as String? ?? view['name'] as String)`,
/// confirmed by reading it — falls back to a normalized `name` when the
/// model omits `id`, but never to a deterministic `<entityId>_<role>`
/// formula). The compiler's own screen ids (`RuntimeExperienceGenerator`,
/// R13/R20/R21) ARE such a deterministic formula
/// (`'${entity.id}_list'`/`'${entity.id}_form'`/etc., or `view.id` verbatim
/// for non-CRUD views). Comparing these two naming schemes as opaque
/// strings (pre-R22) makes semantically identical screens look like real
/// differences. `ScreenIdentity`/`ActionIdentity` below are the REAL,
/// already-present structural pair, named and exposed so callers (chiefly
/// `EquivalenceComparator`, R19-R22) can compare what a screen/action
/// MEANS instead of what it happens to be spelled.
///
/// Modeled (real, already-structured signal exists on both sides):
///  - Screen Identity (entity + `ScreenRole`, mirrors `BlueprintViewType`
///    exactly — 8 real values, never invented ones).
///  - Action Identity (entity + `ActionRole` — only create/update/delete:
///    the subset `ImplementationOperationKind` (compiler) can express.
///    `BlueprintActionType` (legacy) also has toggle/increment/decrement/
///    setValue/clearValue/changeStatus/navigate — real LLM-producible
///    values with NO compiler-side counterpart at all (`RuntimeExperienceGenerator`
///    only ever builds create/update/delete behavior nodes) — these
///    honestly resolve to no `ActionIdentity` rather than a fabricated one.
///  - Behavior Identity: NOT a separate type. A behavior node pair
///    (`event`+`dataMutation` on the compiler side; the analogous legacy
///    nodes) already exists ONLY as the deterministic execution of one
///    action — its identity IS that action's `ActionIdentity`, on both
///    sides. Minting a second, structurally identical type would
///    duplicate, not model something new.
///  - Navigation Identity: NOT a separate type either. A
///    `NavigationItem.screenId` already points at a screen — its identity
///    IS the `ScreenIdentity` of the screen it targets. Both pipelines
///    build navigation items directly from the same screen list.
///
/// Honestly NOT modeled — no real, already-structured signal exists on
/// both sides to project from (verified by reading every relevant type,
/// never assumed): Component Identity, Artifact Identity, Route Identity.
/// Neither `AppBlueprint` nor `CanonicalImplementationModel` carries a
/// component-boundary, build-artifact, or URL-route concept distinct from
/// Screen/Action — inventing identity types for concepts that don't exist
/// on either side would fabricate structure, not close a verified gap
/// (matching R17's `UnmodeledConcept`/R18's `standingGaps` precedent).
library;

import '../implementation_model/canonical_implementation_model.dart';
import '../synthesis/app_blueprint.dart';

/// Mirrors `BlueprintViewType` exactly — the real, already-existing view
/// taxonomy both `SemanticView` (legacy) and `ImplementationViewKind`
/// (compiler, R21) already draw from. Not re-declared as an import to keep
/// this identity module usable from contexts that only have one side's
/// types in scope (matches `ImplementationDataType`'s own established
/// mirror-not-import convention relative to `DatabaseColumnType`, R9).
enum ScreenRole {
  list,
  detail,
  form,
  dashboard,
  calendar,
  settings,
  empty,
  summary,
}

/// A screen's real structural identity — entity + role, never the
/// incidental id string either pipeline happens to spell it with.
/// `entityId` is nullable because a real `SemanticView`/`BlueprintView` can
/// legitimately have none (e.g. a settings view with no single source
/// entity) — both pipelines already tolerate this.
class ScreenIdentity {
  final String? entityId;
  final ScreenRole role;

  const ScreenIdentity({this.entityId, required this.role});

  @override
  bool operator ==(Object other) =>
      other is ScreenIdentity &&
      other.entityId == entityId &&
      other.role == role;

  @override
  int get hashCode => Object.hash(entityId, role);

  @override
  String toString() => '${entityId ?? '<none>'}:${role.name}';
}

/// Only the 3 `ActionRole`s `ImplementationOperationKind` (compiler) can
/// express — real, not exhaustive of what `BlueprintActionType` (legacy)
/// can name.
enum ActionRole { create, update, delete }

class ActionIdentity {
  final String entityId;
  final ActionRole role;

  const ActionIdentity({required this.entityId, required this.role});

  @override
  bool operator ==(Object other) =>
      other is ActionIdentity &&
      other.entityId == entityId &&
      other.role == role;

  @override
  int get hashCode => Object.hash(entityId, role);

  @override
  String toString() => '$entityId:${role.name}';
}

ScreenRole _mapBlueprintViewType(BlueprintViewType type) => switch (type) {
  BlueprintViewType.list => ScreenRole.list,
  BlueprintViewType.detail => ScreenRole.detail,
  BlueprintViewType.form => ScreenRole.form,
  BlueprintViewType.dashboard => ScreenRole.dashboard,
  BlueprintViewType.calendar => ScreenRole.calendar,
  BlueprintViewType.settings => ScreenRole.settings,
  BlueprintViewType.empty => ScreenRole.empty,
  BlueprintViewType.summary => ScreenRole.summary,
};

ScreenRole _mapImplementationViewKind(ImplementationViewKind kind) =>
    switch (kind) {
      ImplementationViewKind.dashboard => ScreenRole.dashboard,
      ImplementationViewKind.calendar => ScreenRole.calendar,
      ImplementationViewKind.settings => ScreenRole.settings,
      ImplementationViewKind.empty => ScreenRole.empty,
      ImplementationViewKind.summary => ScreenRole.summary,
    };

/// Legacy projection — derived from `sourceEntityId`/`viewType`, the real
/// structured fields; `view.id` is never read here (Implementation
/// Milestone R22's whole point).
ScreenIdentity legacyScreenIdentity(BlueprintView view) => ScreenIdentity(
  entityId: view.sourceEntityId,
  role: _mapBlueprintViewType(view.viewType),
);

List<ScreenIdentity> legacyScreenIdentities(AppBlueprint blueprint) =>
    blueprint.views.map(legacyScreenIdentity).toList();

/// Legacy action projection — `null` for any `BlueprintActionType` with no
/// real compiler-side counterpart (toggle/increment/decrement/setValue/
/// clearValue/changeStatus/navigate) — never fabricated.
ActionIdentity? legacyActionIdentity(BlueprintAction action) =>
    switch (action.actionType) {
      BlueprintActionType.create => ActionIdentity(
        entityId: action.targetEntityId,
        role: ActionRole.create,
      ),
      BlueprintActionType.update => ActionIdentity(
        entityId: action.targetEntityId,
        role: ActionRole.update,
      ),
      BlueprintActionType.delete => ActionIdentity(
        entityId: action.targetEntityId,
        role: ActionRole.delete,
      ),
      _ => null,
    };

List<ActionIdentity> legacyActionIdentities(AppBlueprint blueprint) =>
    blueprint.actions.map(legacyActionIdentity).nonNulls.toList();

/// Compiler projection — mirrors `RuntimeExperienceGenerator._buildInterface`'s
/// own real screen-synthesis conditions exactly (`hasList`/`hasCreate`/
/// `hasUpdate`/`hasDetail`), so this stays a real reflection of what the
/// generator actually produces, never a re-derivation that could drift
/// from it. Both the create-mode form (`_form`) and the edit-mode form
/// (`_edit`) resolve to the SAME `ScreenRole.form` — legacy's own
/// `BlueprintViewType` has no create/edit split (`CreationEngine`'s form
/// case hardcodes `'mode': 'create'`, verified by reading it), so a real,
/// honest 2-vs-1 count difference for that identity is the correct,
/// expected signal — not something to hide by inventing a `formEdit` role
/// legacy could never produce.
List<ScreenIdentity> compilerScreenIdentities(
  CanonicalImplementationModel model,
) {
  final identities = <ScreenIdentity>[];
  for (final entity in model.entities) {
    final controller = model.controllers
        .where((c) => c.entityId == entity.id)
        .firstOrNull;
    final kinds =
        controller?.operations.map((o) => o.kind).toSet() ??
        <ImplementationOperationKind>{};
    final hasList =
        kinds.contains(ImplementationOperationKind.list) ||
        kinds.contains(ImplementationOperationKind.search);
    final hasCreate = kinds.contains(ImplementationOperationKind.create);
    final hasUpdate = kinds.contains(ImplementationOperationKind.update);
    final hasDetail =
        kinds.contains(ImplementationOperationKind.get) ||
        kinds.contains(ImplementationOperationKind.delete);
    if (hasList) {
      identities.add(
        ScreenIdentity(entityId: entity.id, role: ScreenRole.list),
      );
    }
    if (hasCreate) {
      identities.add(
        ScreenIdentity(entityId: entity.id, role: ScreenRole.form),
      );
    }
    if (hasUpdate) {
      identities.add(
        ScreenIdentity(entityId: entity.id, role: ScreenRole.form),
      );
    }
    if (hasDetail) {
      identities.add(
        ScreenIdentity(entityId: entity.id, role: ScreenRole.detail),
      );
    }
  }
  for (final view in model.views) {
    identities.add(
      ScreenIdentity(
        entityId: view.sourceEntityId,
        role: _mapImplementationViewKind(view.kind),
      ),
    );
  }
  return identities;
}

/// Compiler action projection — mirrors `RuntimeExperienceGenerator._buildBehavior`'s
/// own real create/update/delete-only scope exactly.
List<ActionIdentity> compilerActionIdentities(
  CanonicalImplementationModel model,
) => [
  for (final controller in model.controllers)
    for (final op in controller.operations)
      if (switch (op.kind) {
            ImplementationOperationKind.create => ActionRole.create,
            ImplementationOperationKind.update => ActionRole.update,
            ImplementationOperationKind.delete => ActionRole.delete,
            _ => null,
          }
          case final role?)
        ActionIdentity(entityId: controller.entityId, role: role),
];
