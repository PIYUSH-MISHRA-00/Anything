/// Synthesis Patterns — reusable building blocks for app synthesis.
///
/// Patterns encode the structural knowledge for different app archetypes.
/// They define what entities, views, actions, and derived values are needed
/// for a given archetype, and how to compose them into an AppBlueprint.
///
/// Patterns are STRUCTURAL only. They do NOT contain domain knowledge.
/// Domain knowledge comes from the ApplicationReasoner.
library;

import 'app_archetype.dart';
import 'app_blueprint.dart';

/// A synthesis pattern defines how to build an AppBlueprint for a specific archetype.
abstract class SynthesisPattern {
  const SynthesisPattern();

  /// Unique pattern identifier.
  String get patternId;

  /// Archetypes this pattern supports.
  List<AppArchetype> get supportedArchetypes;

  /// Apply this pattern with semantic input to create an AppBlueprint.
  AppBlueprint apply({
    required String name,
    required String description,
    required List<BlueprintEntity> entities,
    required List<BlueprintAction> actions,
    required List<BlueprintView> views,
    required List<BlueprintDerivedValue> derivedValues,
    List<String> tags = const [],
  });
}

/// Collection pattern — manages a collection of records.
///
/// Characteristics: persistent records, CRUD, list + form views.
class CollectionPattern extends SynthesisPattern {
  const CollectionPattern();

  @override
  String get patternId => 'collection';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.collection];

  @override
  AppBlueprint apply({
    required String name,
    required String description,
    required List<BlueprintEntity> entities,
    required List<BlueprintAction> actions,
    required List<BlueprintView> views,
    required List<BlueprintDerivedValue> derivedValues,
    List<String> tags = const [],
  }) {
    return AppBlueprint(
      id: _stableId(name),
      name: name,
      description: description,
      archetypes: [AppArchetype.collection],
      tags: tags,
      entities: entities,
      views: views,
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String name) {
    return 'bp_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
  }
}

/// Tracker pattern — tracks periodic/daily state.
///
/// Characteristics: daily records, completion tracking, streaks.
class TrackerPattern extends SynthesisPattern {
  const TrackerPattern();

  @override
  String get patternId => 'tracker';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.tracker];

  @override
  AppBlueprint apply({
    required String name,
    required String description,
    required List<BlueprintEntity> entities,
    required List<BlueprintAction> actions,
    required List<BlueprintView> views,
    required List<BlueprintDerivedValue> derivedValues,
    List<String> tags = const [],
  }) {
    return AppBlueprint(
      id: _stableId(name),
      name: name,
      description: description,
      archetypes: [AppArchetype.tracker],
      tags: tags,
      entities: entities,
      views: views,
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String name) {
    return 'bp_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
  }
}

/// Planner pattern — tasks with dates and status.
///
/// Characteristics: tasks, due dates, status, priority.
class PlannerPattern extends SynthesisPattern {
  const PlannerPattern();

  @override
  String get patternId => 'planner';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.planner];

  @override
  AppBlueprint apply({
    required String name,
    required String description,
    required List<BlueprintEntity> entities,
    required List<BlueprintAction> actions,
    required List<BlueprintView> views,
    required List<BlueprintDerivedValue> derivedValues,
    List<String> tags = const [],
  }) {
    return AppBlueprint(
      id: _stableId(name),
      name: name,
      description: description,
      archetypes: [AppArchetype.planner],
      tags: tags,
      entities: entities,
      views: views,
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String name) {
    return 'bp_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
  }
}

/// Dashboard pattern — summary-first with aggregation.
///
/// Characteristics: aggregated data, category totals, trends.
class DashboardPattern extends SynthesisPattern {
  const DashboardPattern();

  @override
  String get patternId => 'dashboard';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.dashboard];

  @override
  AppBlueprint apply({
    required String name,
    required String description,
    required List<BlueprintEntity> entities,
    required List<BlueprintAction> actions,
    required List<BlueprintView> views,
    required List<BlueprintDerivedValue> derivedValues,
    List<String> tags = const [],
  }) {
    return AppBlueprint(
      id: _stableId(name),
      name: name,
      description: description,
      archetypes: [AppArchetype.dashboard],
      tags: tags,
      entities: entities,
      views: views,
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String name) {
    return 'bp_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
  }
}

/// Registry of available synthesis patterns.
class PatternRegistry {
  static final Map<String, SynthesisPattern Function()> _factories = {
    'collection': () => const CollectionPattern(),
    'tracker': () => const TrackerPattern(),
    'planner': () => const PlannerPattern(),
    'dashboard': () => const DashboardPattern(),
  };

  /// Register a custom pattern.
  static void register(String patternId, SynthesisPattern Function() factory) {
    _factories[patternId] = factory;
  }

  /// Get a pattern by ID.
  static SynthesisPattern? getPattern(String patternId) {
    return _factories[patternId]?.call();
  }

  /// Get all registered pattern IDs.
  static List<String> get registeredPatterns => _factories.keys.toList();
}
