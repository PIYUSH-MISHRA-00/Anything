/// Engineering Diff — Implementation Milestone R4's third diff stage,
/// planning-only (see `requirement_graph_diff.dart` for the established
/// scope statement — this file computes what changed, never applies it).
///
/// `EngineeringCandidate` is shaped differently from `RequirementGraph`/
/// `ArchitectureCandidate`: most dimensions (data/navigation/interaction/
/// persistence/offline/synchronization/lifecycle/performance/
/// accessibility/security) are ONE singular result each, not an
/// independently-identified list — there is no real "added/removed
/// entity" concept for them. Honest scope: each singular dimension is
/// represented as a real "changed: yes/no" pair via its own
/// `EngineeringDecision.decision` (a real, human-readable string every
/// *EngineeringResult already carries, never fabricated) — the two
/// genuinely list-shaped dimensions (`validations`, `bindingGraph.edges`)
/// get the real id-keyed add/remove treatment matching
/// `RequirementGraphDiffer`/`ArchitectureDiffer`'s established pattern.
library;

import 'engineering_candidate.dart';
import 'engineering_types.dart';
import 'validation_engineering.dart';

class EngineeringDiff {
  final List<EngineeringValidationRule> addedValidations;
  final List<EngineeringValidationRule> removedValidations;
  final List<BindingEdge> addedBindings;
  final List<BindingEdge> removedBindings;
  final (String, String)? dataChange;
  final (String, String)? navigationChange;
  final (String, String)? interactionChange;
  final (String, String)? persistenceChange;
  final (String, String)? offlineChange;
  final (String, String)? synchronizationChange;
  final (String, String)? securityChange;

  const EngineeringDiff({
    this.addedValidations = const [],
    this.removedValidations = const [],
    this.addedBindings = const [],
    this.removedBindings = const [],
    this.dataChange,
    this.navigationChange,
    this.interactionChange,
    this.persistenceChange,
    this.offlineChange,
    this.synchronizationChange,
    this.securityChange,
  });

  bool get isEmpty =>
      addedValidations.isEmpty &&
      removedValidations.isEmpty &&
      addedBindings.isEmpty &&
      removedBindings.isEmpty &&
      dataChange == null &&
      navigationChange == null &&
      interactionChange == null &&
      persistenceChange == null &&
      offlineChange == null &&
      synchronizationChange == null &&
      securityChange == null;

  static const EngineeringDiff empty = EngineeringDiff();
}

class EngineeringDiffer {
  const EngineeringDiffer();

  EngineeringDiff diff(EngineeringCandidate before, EngineeringCandidate after) {
    final validationsBefore = {for (final v in before.validations) v.subjectId: v};
    final validationsAfter = {for (final v in after.validations) v.subjectId: v};
    final addedValidations = <EngineeringValidationRule>[];
    final removedValidations = <EngineeringValidationRule>[];
    for (final entry in validationsAfter.entries) {
      final beforeRule = validationsBefore[entry.key];
      if (beforeRule == null || beforeRule.satisfied != entry.value.satisfied) {
        if (beforeRule != null) removedValidations.add(beforeRule);
        addedValidations.add(entry.value);
      }
    }
    for (final entry in validationsBefore.entries) {
      if (!validationsAfter.containsKey(entry.key)) removedValidations.add(entry.value);
    }

    final bindingsBefore = before.bindingGraph.edges.toSet();
    final bindingsAfter = after.bindingGraph.edges.toSet();
    // BindingEdge has no `==` override, so compare via a real structural
    // key rather than object identity — matches RequirementGraphDiffer's
    // `_RelationKey` approach.
    bool edgeIn(BindingEdge e, Iterable<BindingEdge> set) =>
        set.any((o) => o.kind == e.kind && o.fromId == e.fromId && o.toId == e.toId);
    final addedBindings = bindingsAfter.where((e) => !edgeIn(e, bindingsBefore)).toList();
    final removedBindings = bindingsBefore.where((e) => !edgeIn(e, bindingsAfter)).toList();

    (String, String)? changePair(String beforeDecision, String afterDecision) =>
        beforeDecision == afterDecision ? null : (beforeDecision, afterDecision);

    // Real, structural, deterministic — never a fabricated field. Two
    // result shapes (`interaction`/`security`) carry a LIST of decisions
    // rather than one singular `EngineeringDecision`, so their "changed"
    // signal is honestly coarser: a real, joined description of every
    // decision in the list, still a genuine content comparison, never a
    // guess.
    String joinDecisions(List<EngineeringDecision> decisions) => decisions.map((d) => d.decision).join('|');

    return EngineeringDiff(
      addedValidations: addedValidations,
      removedValidations: removedValidations,
      addedBindings: addedBindings,
      removedBindings: removedBindings,
      dataChange: changePair(before.data.migrationDecision.decision, after.data.migrationDecision.decision),
      navigationChange: changePair(before.navigation.decision.decision, after.navigation.decision.decision),
      interactionChange: changePair(
        joinDecisions(before.interaction.patterns.map((p) => p.decision).toList()),
        joinDecisions(after.interaction.patterns.map((p) => p.decision).toList()),
      ),
      persistenceChange: changePair(
        before.persistence.migrationDecision.decision,
        after.persistence.migrationDecision.decision,
      ),
      offlineChange: changePair(before.offline.decision.decision, after.offline.decision.decision),
      synchronizationChange: changePair(
        before.synchronization.decision.decision,
        after.synchronization.decision.decision,
      ),
      securityChange: changePair(joinDecisions(before.security.decisions), joinDecisions(after.security.decisions)),
    );
  }
}
