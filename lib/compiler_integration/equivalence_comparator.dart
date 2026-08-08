/// EquivalenceComparator — Implementation Milestone R19, identity-aware
/// since R22. Real, itemized structural comparison between a legacy-pipeline
/// and a compiler-pipeline `ExperiencePackage` produced from the SAME real
/// creation request. Eleven real, individually-checked dimensions (see
/// `_dimensionChecks`) — the compatibility score is `passed / total`, never
/// a hand-waved constant.
///
/// `missingComponents`/`extraComponents` (Implementation Milestone R22):
/// when the caller supplies the real source `legacyBlueprint`/
/// `compilerModel` alongside the two packages, screen presence is compared
/// by `ScreenIdentity` (`lib/experience_identity/`) — entity+role — instead
/// of raw `InterfaceScreen.id` strings, so the `entries_list`-vs-`entry_list`
/// class of incidental naming difference (R19's own documented finding) no
/// longer reads as a real structural gap. Omitting them keeps the exact
/// pre-R22 string-based behavior — purely additive, every existing R19-R21
/// call site is unaffected.
library;

import '../creation/experience_package.dart';
import '../experience_identity/experience_identity.dart';
import '../implementation_model/canonical_implementation_model.dart';
import '../synthesis/app_blueprint.dart';
import 'equivalence_report.dart';

/// Dart's default `Set<T>.==` is identity-based, not content-based — this
/// comparator needs real structural set equality throughout.
bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

class EquivalenceComparator {
  const EquivalenceComparator();

  EquivalenceReport compare(
    ExperiencePackage legacy,
    ExperiencePackage compiler, {
    required Duration legacyLatency,
    required Duration compilerLatency,
    AppBlueprint? legacyBlueprint,
    CanonicalImplementationModel? compilerModel,
  }) {
    final List<String> missingComponents;
    final List<String> extraComponents;
    if (legacyBlueprint != null && compilerModel != null) {
      final identityDiff = _identityDiff(
        legacyScreenIdentities(legacyBlueprint),
        compilerScreenIdentities(compilerModel),
      );
      missingComponents = identityDiff.missing;
      extraComponents = identityDiff.extra;
    } else {
      final legacyScreenIds = legacy.interface.screens.map((s) => s.id).toSet();
      final compilerScreenIds = compiler.interface.screens
          .map((s) => s.id)
          .toSet();
      missingComponents = legacyScreenIds.difference(compilerScreenIds).toList()
        ..sort();
      extraComponents = compilerScreenIds.difference(legacyScreenIds).toList()
        ..sort();
    }

    final behaviorDifferences = _behaviorDifferences(legacy, compiler);
    final capabilityDifferences = _capabilityDifferences(legacy, compiler);

    final checks = _dimensionChecks(legacy, compiler);
    if (legacyBlueprint != null && compilerModel != null) {
      checks['screenIdentityCoverage'] =
          missingComponents.isEmpty && extraComponents.isEmpty;
    }
    final passed = checks.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    return EquivalenceReport(
      missingComponents: missingComponents,
      extraComponents: extraComponents,
      behaviorDifferences: behaviorDifferences,
      capabilityDifferences: capabilityDifferences,
      legacyLatency: legacyLatency,
      compilerLatency: compilerLatency,
      compatibilityScore: checks.isEmpty ? 0.0 : passed.length / checks.length,
      determinismScore:
          0.0, // Filled in separately by checkDeterminism — a compare() call alone never re-runs a pipeline.
      dimensionsChecked: checks.keys.toList(),
      dimensionsPassed: passed,
    );
  }

  /// Real multiset comparison (Implementation Milestone R22): counts each
  /// `ScreenIdentity`, not just set presence, so the compiler's genuine
  /// create+edit split (2 `form`-role screens vs. legacy's 1, since legacy
  /// has no create/edit distinction — see `experience_identity.dart`'s doc
  /// comment) shows up as a real, honest, quantified difference rather than
  /// being hidden or falsely equated.
  ({List<String> missing, List<String> extra}) _identityDiff(
    List<ScreenIdentity> legacyIds,
    List<ScreenIdentity> compilerIds,
  ) {
    final legacyCounts = <ScreenIdentity, int>{};
    for (final id in legacyIds) {
      legacyCounts[id] = (legacyCounts[id] ?? 0) + 1;
    }
    final compilerCounts = <ScreenIdentity, int>{};
    for (final id in compilerIds) {
      compilerCounts[id] = (compilerCounts[id] ?? 0) + 1;
    }

    final missing = <String>[];
    for (final entry in legacyCounts.entries) {
      final deficit = entry.value - (compilerCounts[entry.key] ?? 0);
      if (deficit > 0) {
        missing.add('${entry.key} (legacy $deficit more than compiler)');
      }
    }
    final extra = <String>[];
    for (final entry in compilerCounts.entries) {
      final surplus = entry.value - (legacyCounts[entry.key] ?? 0);
      if (surplus > 0) {
        extra.add('${entry.key} (compiler $surplus more than legacy)');
      }
    }
    missing.sort();
    extra.sort();
    return (missing: missing, extra: extra);
  }

  /// Ten real, itemized structural dimensions. Each predicate is
  /// documented at its definition — several are EXPECTED to fail today
  /// (e.g. `screenCountParity`, since the legacy blueprint pipeline
  /// supports dashboard/calendar/settings/summary views the compiler
  /// pipeline explicitly never generates, per R13's own honest scope) —
  /// a failing dimension is real signal, not a bug in this comparator.
  Map<String, bool> _dimensionChecks(
    ExperiencePackage legacy,
    ExperiencePackage compiler,
  ) {
    final legacyEntityIds =
        legacy.data?.entities.map((e) => e.id).toSet() ?? const <String>{};
    final compilerEntityIds =
        compiler.data?.entities.map((e) => e.id).toSet() ?? const <String>{};

    return {
      // Both packages describe the SAME real entities — the one dimension
      // that must always hold, since both pipelines are fed the same
      // underlying entity list for one creation request.
      'entityCoverage':
          legacyEntityIds.length == compilerEntityIds.length &&
          legacyEntityIds.containsAll(compilerEntityIds),
      // Same per-entity field COUNT (legacy's DataFieldSchema carries
      // richer metadata per field — defaultValue/referenceEntityId/
      // allowedValues/hint — CanonicalImplementationModel's
      // ImplementationField does not; field count itself should still
      // match).
      'dataFieldCountParity': _fieldCountsMatch(
        legacy,
        compiler,
        legacyEntityIds.intersection(compilerEntityIds),
      ),
      // Same set of entities with a real create-mutation behavior node.
      'crudCreateCoverage': _setEquals(
        _mutationEntitySet(legacy, 'create'),
        _mutationEntitySet(compiler, 'create'),
      ),
      'crudUpdateCoverage': _setEquals(
        _mutationEntitySet(legacy, 'update'),
        _mutationEntitySet(compiler, 'update'),
      ),
      'crudDeleteCoverage': _setEquals(
        _mutationEntitySet(legacy, 'delete'),
        _mutationEntitySet(compiler, 'delete'),
      ),
      // Same declared capability id set.
      'capabilityCoverage': _setEquals(
        legacy.capabilityDeclarations.map((c) => c.capabilityId).toSet(),
        compiler.capabilityDeclarations.map((c) => c.capabilityId).toSet(),
      ),
      'networkModeMatch':
          legacy.manifest.networkMode == compiler.manifest.networkMode,
      'storageModeMatch':
          legacy.manifest.storageMode == compiler.manifest.storageMode,
      // Compiler's state is intentionally a strict subset (searchTerm
      // only) — real per compiler's own documented design (R13); checks
      // the subset relationship holds, not equality.
      'stateVariableSubset': compiler.state.variables
          .map((v) => v.id)
          .toSet()
          .every((id) => legacy.state.variables.any((v) => v.id == id)),
      // Same navigation SHAPE (both none, or both bottomNavigation) — real
      // structural check, not identical item lists (screen ids differ by
      // convention, see `missingComponents`/`extraComponents`).
      'navigationShapeMatch':
          (legacy.interface.navigation == null) ==
          (compiler.interface.navigation == null),
      // Same TOTAL screen count — expected to fail whenever the legacy
      // blueprint used a view type (dashboard/calendar/settings/summary)
      // the compiler pipeline does not generate at all.
      'screenCountParity':
          legacy.interface.screens.length == compiler.interface.screens.length,
      // Implementation Milestone R20 — a SEPARATE dimension from
      // `dataFieldCountParity`: that check is a raw field COUNT, which
      // genuinely (and correctly) still differs whenever the compiler's
      // real, deliberate auto primary-key column
      // (`BackendEngineeringPlanner._planDatabase`) has no legacy
      // counterpart — that is real backend modeling, not a defect to
      // patch here. This dimension instead checks, for fields that exist
      // on BOTH sides (matched by name, since the two pipelines use
      // different id-namespacing schemes), whether the real metadata R20
      // threads through (defaultValue/referenceEntityId/allowedValues/
      // hint) actually agrees.
      'sharedFieldMetadataParity': _sharedFieldMetadataMatches(
        legacy,
        compiler,
        legacyEntityIds.intersection(compilerEntityIds),
      ),
    };
  }

  bool _sharedFieldMetadataMatches(
    ExperiencePackage legacy,
    ExperiencePackage compiler,
    Set<String> sharedEntityIds,
  ) {
    for (final id in sharedEntityIds) {
      final legacyFields = {
        for (final f
            in legacy.data!.entities.firstWhere((e) => e.id == id).fields)
          f.name: f,
      };
      final compilerFields = {
        for (final f
            in compiler.data!.entities.firstWhere((e) => e.id == id).fields)
          f.name: f,
      };
      for (final name in legacyFields.keys.toSet().intersection(
        compilerFields.keys.toSet(),
      )) {
        final lf = legacyFields[name]!;
        final cf = compilerFields[name]!;
        if (lf.defaultValue != cf.defaultValue) return false;
        if (lf.referenceEntityId != cf.referenceEntityId) return false;
        if (!_setEquals(lf.allowedValues.toSet(), cf.allowedValues.toSet())) {
          return false;
        }
        if (lf.hint != cf.hint) return false;
      }
    }
    return true;
  }

  bool _fieldCountsMatch(
    ExperiencePackage legacy,
    ExperiencePackage compiler,
    Set<String> sharedEntityIds,
  ) {
    if (sharedEntityIds.isEmpty) return true;
    for (final id in sharedEntityIds) {
      final legacyFields = legacy.data!.entities
          .firstWhere((e) => e.id == id)
          .fields
          .length;
      final compilerFields = compiler.data!.entities
          .firstWhere((e) => e.id == id)
          .fields
          .length;
      if (legacyFields != compilerFields) return false;
    }
    return true;
  }

  Set<String> _mutationEntitySet(ExperiencePackage package, String operation) =>
      package.behavior.nodes
          .where(
            (n) =>
                n.type == 'dataMutation' && n.config['operation'] == operation,
          )
          .map((n) => n.config['entity'] as String)
          .toSet();

  List<ComponentDifference> _behaviorDifferences(
    ExperiencePackage legacy,
    ExperiencePackage compiler,
  ) {
    final differences = <ComponentDifference>[];
    if (legacy.behavior.nodes.length != compiler.behavior.nodes.length) {
      differences.add(
        ComponentDifference(
          category: 'behaviorNodeCount',
          description:
              'Legacy produced ${legacy.behavior.nodes.length} behavior nodes; compiler produced ${compiler.behavior.nodes.length} — '
              'expected, since legacy also models derived-value query/calculation nodes the compiler does not.',
        ),
      );
    }
    if (legacy.behavior.edges.length != compiler.behavior.edges.length) {
      differences.add(
        ComponentDifference(
          category: 'behaviorEdgeCount',
          description:
              'Legacy produced ${legacy.behavior.edges.length} behavior edges; compiler produced ${compiler.behavior.edges.length}.',
        ),
      );
    }
    return differences;
  }

  List<ComponentDifference> _capabilityDifferences(
    ExperiencePackage legacy,
    ExperiencePackage compiler,
  ) {
    final legacySet = legacy.capabilityDeclarations
        .map((c) => c.capabilityId)
        .toSet();
    final compilerSet = compiler.capabilityDeclarations
        .map((c) => c.capabilityId)
        .toSet();
    final differences = <ComponentDifference>[];
    for (final id in legacySet.difference(compilerSet)) {
      differences.add(
        ComponentDifference(
          category: 'missingCapability',
          description: 'Legacy declares "$id"; compiler does not.',
        ),
      );
    }
    for (final id in compilerSet.difference(legacySet)) {
      differences.add(
        ComponentDifference(
          category: 'extraCapability',
          description: 'Compiler declares "$id"; legacy does not.',
        ),
      );
    }
    return differences;
  }

  /// Real re-check: strips only the fields BOTH pipelines document as
  /// genuine wall-clock metadata (`manifest.createdAt`/`updatedAt`,
  /// `integrity.computedAt` — see `RuntimeExperienceGenerator`'s own
  /// "Determinism" doc comment, R13) and compares everything else for
  /// exact structural identity.
  bool structurallyIdentical(ExperiencePackage a, ExperiencePackage b) {
    final aJson = _stripTimestamps(a.toJson());
    final bJson = _stripTimestamps(b.toJson());
    return _deepEquals(aJson, bJson);
  }

  Map<String, dynamic> _stripTimestamps(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (copy['manifest'] is Map) {
      final manifest = Map<String, dynamic>.from(copy['manifest'] as Map);
      manifest.remove('createdAt');
      manifest.remove('updatedAt');
      copy['manifest'] = manifest;
    }
    if (copy['integrity'] is Map) {
      final integrity = Map<String, dynamic>.from(copy['integrity'] as Map);
      integrity.remove('computedAt');
      integrity.remove(
        'contentHash',
      ); // hash changes because timestamps fed the hash input.
      copy['integrity'] = integrity;
    }
    return copy;
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
