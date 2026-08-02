/// Engineering Planner — the top-level orchestrator. Given an
/// EngineeringContext (approved architecture + the original semantic
/// app), runs every *Engineering module and assembles one
/// EngineeringCandidate, with confidence computed from what was actually
/// planned.
library;

import 'package:uuid/uuid.dart';

import '../software_architect/confidence.dart';
import 'accessibility_performance_security_engineering.dart';
import 'behavior_engineering.dart';
import 'binding_engineering.dart';
import 'data_engineering.dart';
import 'engineering_candidate.dart';
import 'engineering_confidence.dart';
import 'engineering_context.dart';
import 'interaction_engineering.dart';
import 'lifecycle_engineering.dart';
import 'navigation_engineering.dart';
import 'persistence_offline_sync_engineering.dart';
import 'validation_engineering.dart';

class EngineeringPlanner {
  final BehaviorEngineering _behavior;
  final DataEngineering _data;
  final NavigationEngineering _navigation;
  final InteractionEngineering _interaction;
  final BindingEngineering _binding;
  final ValidationEngineering _validation;
  final PersistenceEngineering _persistence;
  final OfflineEngineering _offline;
  final SynchronizationEngineering _synchronization;
  final LifecycleEngineering _lifecycle;
  final PerformanceEngineering _performance;
  final AccessibilityEngineering _accessibility;
  final SecurityEngineering _security;
  final EngineeringConfidence _confidenceAnalyzer;

  const EngineeringPlanner({
    BehaviorEngineering behavior = const BehaviorEngineering(),
    DataEngineering data = const DataEngineering(),
    NavigationEngineering navigation = const NavigationEngineering(),
    InteractionEngineering interaction = const InteractionEngineering(),
    BindingEngineering binding = const BindingEngineering(),
    ValidationEngineering validation = const ValidationEngineering(),
    PersistenceEngineering persistence = const PersistenceEngineering(),
    OfflineEngineering offline = const OfflineEngineering(),
    SynchronizationEngineering synchronization = const SynchronizationEngineering(),
    LifecycleEngineering lifecycle = const LifecycleEngineering(),
    PerformanceEngineering performance = const PerformanceEngineering(),
    AccessibilityEngineering accessibility = const AccessibilityEngineering(),
    SecurityEngineering security = const SecurityEngineering(),
    EngineeringConfidence confidenceAnalyzer = const EngineeringConfidence(),
  }) : _behavior = behavior,
       _data = data,
       _navigation = navigation,
       _interaction = interaction,
       _binding = binding,
       _validation = validation,
       _persistence = persistence,
       _offline = offline,
       _synchronization = synchronization,
       _lifecycle = lifecycle,
       _performance = performance,
       _accessibility = accessibility,
       _security = security,
       _confidenceAnalyzer = confidenceAnalyzer;

  EngineeringCandidate plan(EngineeringContext context) {
    final behaviors = _behavior.plan(context.architecture);
    final data = _data.plan(context);
    final navigation = _navigation.plan(context);
    final interaction = _interaction.plan(context);
    final bindingResult = _binding.plan(context.architecture);
    final validations = _validation.plan(
      candidate: context.architecture,
      eventGraphs: behaviors.map((b) => b.eventGraph).toList(),
      stateMachines: behaviors.map((b) => b.stateMachine).toList(),
    );
    final persistence = _persistence.plan(context.architecture, data.migrationDecision);
    final offline = _offline.plan(context.architecture);
    final synchronization = _synchronization.plan(context.architecture);
    final lifecycle = _lifecycle.plan();
    final performance = _performance.plan();
    final accessibility = _accessibility.plan();
    final security = _security.plan();

    final candidate = EngineeringCandidate(
      id: const Uuid().v4(),
      behaviors: behaviors,
      data: data,
      navigation: navigation,
      interaction: interaction,
      bindingGraph: bindingResult.graph,
      bindingDecision: bindingResult.decision,
      validations: validations,
      persistence: persistence,
      offline: offline,
      synchronization: synchronization,
      lifecycle: lifecycle,
      performance: performance,
      accessibility: accessibility,
      security: security,
      overallConfidence: const Confidence(score: 0.0, reason: 'not yet analyzed'),
    );

    return candidate.copyWith(overallConfidence: _confidenceAnalyzer.analyze(candidate));
  }
}
