/// Engineering Candidate / Engineering Plan — the complete, typed output
/// of the AEE pipeline, before/after review and refinement.
library;

import '../software_architect/confidence.dart';
import 'accessibility_performance_security_engineering.dart';
import 'behavior_engineering.dart';
import 'data_engineering.dart';
import 'engineering_types.dart';
import 'interaction_engineering.dart';
import 'lifecycle_engineering.dart';
import 'navigation_engineering.dart';
import 'persistence_offline_sync_engineering.dart';
import 'validation_engineering.dart';

class EngineeringCandidate {
  final String id;
  final int iteration;
  final List<BehaviorEngineeringResult> behaviors;
  final DataEngineeringResult data;
  final NavigationEngineeringResult navigation;
  final InteractionEngineeringResult interaction;
  final BindingGraph bindingGraph;
  final EngineeringDecision bindingDecision;
  final List<EngineeringValidationRule> validations;
  final PersistenceEngineeringResult persistence;
  final OfflineEngineeringResult offline;
  final SynchronizationEngineeringResult synchronization;
  final LifecycleEngineeringResult lifecycle;
  final PerformanceEngineeringResult performance;
  final AccessibilityEngineeringResult accessibility;
  final SecurityEngineeringResult security;
  final Confidence overallConfidence;

  const EngineeringCandidate({
    required this.id,
    this.iteration = 0,
    this.behaviors = const [],
    required this.data,
    required this.navigation,
    required this.interaction,
    required this.bindingGraph,
    required this.bindingDecision,
    this.validations = const [],
    required this.persistence,
    required this.offline,
    required this.synchronization,
    required this.lifecycle,
    required this.performance,
    required this.accessibility,
    required this.security,
    required this.overallConfidence,
  });

  List<EventGraph> get eventGraphs => behaviors.map((b) => b.eventGraph).toList();
  List<StateMachineDefinition> get stateMachines => behaviors.map((b) => b.stateMachine).toList();

  List<EngineeringDecision> get allDecisions => [
    ...behaviors.map((b) => b.decision),
    ...data.indexes.map((i) => i.decision),
    ...data.aggregations.map((a) => a.decision),
    data.migrationDecision,
    navigation.decision,
    navigation.historyDecision,
    navigation.recoveryDecision,
    ...interaction.patterns.map((p) => p.decision),
    bindingDecision,
    ...validations.map((v) => v.decision),
    ...persistence.entityStorageDecisions,
    persistence.migrationDecision,
    offline.decision,
    synchronization.decision,
    ...lifecycle.hooks.map((h) => h.decision),
    ...performance.decisions,
    ...accessibility.decisions,
    ...security.decisions,
  ];

  EngineeringCandidate copyWith({
    int? iteration,
    List<BehaviorEngineeringResult>? behaviors,
    BindingGraph? bindingGraph,
    EngineeringDecision? bindingDecision,
    List<EngineeringValidationRule>? validations,
    Confidence? overallConfidence,
  }) {
    return EngineeringCandidate(
      id: id,
      iteration: iteration ?? this.iteration,
      behaviors: behaviors ?? this.behaviors,
      data: data,
      navigation: navigation,
      interaction: interaction,
      bindingGraph: bindingGraph ?? this.bindingGraph,
      bindingDecision: bindingDecision ?? this.bindingDecision,
      validations: validations ?? this.validations,
      persistence: persistence,
      offline: offline,
      synchronization: synchronization,
      lifecycle: lifecycle,
      performance: performance,
      accessibility: accessibility,
      security: security,
      overallConfidence: overallConfidence ?? this.overallConfidence,
    );
  }
}
