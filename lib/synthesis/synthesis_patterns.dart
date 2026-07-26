/// Synthesis Patterns — reusable building blocks for app synthesis.
///
/// Patterns encode the structural knowledge for different app archetypes.
/// They define what entities, views, actions, and derived values are needed
/// for a given archetype, and how to compose them into an AppBlueprint.
library;

import '../kernel/understanding/intent_understanding.dart';
import 'app_archetype.dart';
import 'app_blueprint.dart';

/// A synthesis pattern defines how to build an AppBlueprint for a specific archetype.
abstract class SynthesisPattern {
  const SynthesisPattern();

  /// Unique pattern identifier.
  String get patternId;

  /// Archetypes this pattern supports.
  List<AppArchetype> get supportedArchetypes;

  /// Apply this pattern to create an AppBlueprint from an intent understanding.
  AppBlueprint apply(IntentUnderstanding understanding);
}

/// Collection pattern — manages a collection of records.
///
/// Used for: Notes, Reading List, Grocery List, Bookmarks.
/// Characteristics: persistent records, CRUD, list + form views.
class CollectionPattern extends SynthesisPattern {
  const CollectionPattern({
    required this.entityName,
    this.entityId = 'item',
    this.fields = const [],
    this.displayName = 'Item',
    this.primaryFieldName = 'name',
  });

  final String entityName;
  final String entityId;
  final List<BlueprintField> fields;
  final String displayName;
  final String primaryFieldName;

  @override
  String get patternId => 'collection';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.collection];

  @override
  AppBlueprint apply(IntentUnderstanding understanding) {
    final id = _stableId(understanding.objective);

    final entityFields = [
      BlueprintField(
        id: '${entityId}_id',
        name: 'ID',
        type: BlueprintFieldType.text,
        required: true,
      ),
      BlueprintField(
        id: '${entityId}_name',
        name: primaryFieldName,
        type: BlueprintFieldType.text,
        required: true,
      ),
      ...fields,
      BlueprintField(
        id: '${entityId}_created_at',
        name: 'Created At',
        type: BlueprintFieldType.dateTime,
        required: true,
      ),
      BlueprintField(
        id: '${entityId}_updated_at',
        name: 'Updated At',
        type: BlueprintFieldType.dateTime,
        required: true,
      ),
    ];

    final entity = BlueprintEntity(
      id: entityId,
      name: entityName,
      fields: entityFields,
      displayField: '${entityId}_name',
    );

    final listView = BlueprintView(
      id: '${entityId}_list',
      name: '$displayName List',
      purpose: 'View all $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      primaryActionId: 'create_${entityId}',
      sections: [
        BlueprintViewSection(
          id: '${entityId}_list_section',
          purpose: 'All $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
      ],
      isDefault: true,
    );

    final formView = BlueprintView(
      id: '${entityId}_form',
      name: 'Add/Edit $displayName',
      purpose: 'Create or edit $entityName',
      entityId: entityId,
      viewType: BlueprintViewType.form,
    );

    final actions = [
      BlueprintAction(
        id: 'create_${entityId}',
        name: 'Create $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
        fields: entityFields
            .where((f) => f.id != '${entityId}_id')
            .map((f) => f.id)
            .toList(),
      ),
      BlueprintAction(
        id: 'update_${entityId}',
        name: 'Update $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.update,
      ),
      BlueprintAction(
        id: 'delete_${entityId}',
        name: 'Delete $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    return AppBlueprint(
      id: id,
      name: understanding.objective,
      description: 'A collection of $entityName',
      archetypes: [AppArchetype.collection],
      domain: _domainFromClassification(understanding.objective),
      entities: [entity],
      views: [listView, formView],
      actions: actions,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String objective) {
    return 'bp_${objective.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${entityId}';
  }

  AppDomain _domainFromClassification(String objective) {
    final lower = objective.toLowerCase();
    if (lower.contains('note') || lower.contains('text'))
      return AppDomain.notes;
    if (lower.contains('book') || lower.contains('read'))
      return AppDomain.reading;
    if (lower.contains('grocery') || lower.contains('shop'))
      return AppDomain.productivity;
    return AppDomain.custom;
  }
}

/// Tracker pattern — tracks periodic/daily state.
///
/// Used for: Habit Tracker, Mood Tracker, Water Intake.
/// Characteristics: daily records, completion tracking, streaks.
class TrackerPattern extends SynthesisPattern {
  const TrackerPattern({
    required this.entityName,
    this.entityId = 'trackable',
    this.fields = const [],
    this.displayName = 'Trackable',
  });

  final String entityName;
  final String entityId;
  final List<BlueprintField> fields;
  final String displayName;

  @override
  String get patternId => 'tracker';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.tracker];

  @override
  AppBlueprint apply(IntentUnderstanding understanding) {
    final id = _stableId(understanding.objective);

    final entityFields = [
      BlueprintField(
        id: '${entityId}_id',
        name: 'ID',
        type: BlueprintFieldType.text,
        required: true,
      ),
      BlueprintField(
        id: '${entityId}_name',
        name: 'Name',
        type: BlueprintFieldType.text,
        required: true,
      ),
      ...fields,
      BlueprintField(
        id: '${entityId}_created_at',
        name: 'Created At',
        type: BlueprintFieldType.dateTime,
        required: true,
      ),
    ];

    final entity = BlueprintEntity(
      id: entityId,
      name: entityName,
      fields: entityFields,
      displayField: '${entityId}_name',
    );

    // Completion records entity
    final completionEntity = BlueprintEntity(
      id: '${entityId}_completions',
      name: '${entityName} Completions',
      fields: [
        BlueprintField(
          id: 'completion_id',
          name: 'ID',
          type: BlueprintFieldType.text,
          required: true,
        ),
        BlueprintField(
          id: 'trackable_id',
          name: 'Trackable ID',
          type: BlueprintFieldType.text,
          required: true,
        ),
        BlueprintField(
          id: 'completion_date',
          name: 'Date',
          type: BlueprintFieldType.date,
          required: true,
        ),
        BlueprintField(
          id: 'completed',
          name: 'Completed',
          type: BlueprintFieldType.boolean,
          defaultValue: 'false',
        ),
        BlueprintField(
          id: 'completion_note',
          name: 'Note',
          type: BlueprintFieldType.text,
        ),
      ],
    );

    final todayView = BlueprintView(
      id: '${entityId}_today',
      name: 'Today',
      purpose: "Today's $entityName",
      sourceEntityId: entityId,
      viewType: BlueprintViewType.dashboard,
      primaryActionId: 'create_${entityId}',
      sections: [
        BlueprintViewSection(
          id: 'today_list',
          purpose: "Today's $entityName",
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
        BlueprintViewSection(
          id: 'today_summary',
          purpose: 'Completion summary',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.summary,
        ),
      ],
      isDefault: true,
    );

    final allView = BlueprintView(
      id: '${entityId}_all',
      name: 'All $displayName',
      purpose: 'View all $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      sections: [
        BlueprintViewSection(
          id: 'all_list',
          purpose: 'All $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
      ],
    );

    final formView = BlueprintView(
      id: '${entityId}_form',
      name: 'Add/Edit $displayName',
      purpose: 'Create or edit $entityName',
      entityId: entityId,
      viewType: BlueprintViewType.form,
    );

    final derivedValues = [
      BlueprintDerivedValue(
        id: 'today_completed',
        name: 'Completed Today',
        sourceEntityId: '${entityId}_completions',
        operation: DerivedOperation.count,
        description: 'Number of items completed today',
      ),
    ];

    final actions = [
      BlueprintAction(
        id: 'create_${entityId}',
        name: 'Add $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      BlueprintAction(
        id: 'toggle_${entityId}',
        name: 'Toggle $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.toggle,
        derivedEffect: 'Toggle today completion',
      ),
      BlueprintAction(
        id: 'delete_${entityId}',
        name: 'Delete $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    return AppBlueprint(
      id: id,
      name: understanding.objective,
      description: 'Track $entityName daily',
      archetypes: [AppArchetype.tracker],
      domain: AppDomain.habits,
      entities: [entity, completionEntity],
      views: [todayView, allView, formView],
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String objective) {
    return 'bp_${objective.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${entityId}';
  }
}

/// Planner pattern — tasks with dates and status.
///
/// Used for: Study Planner, Task Manager, Project Tracker.
/// Characteristics: tasks, due dates, status, priority.
class PlannerPattern extends SynthesisPattern {
  const PlannerPattern({
    required this.entityName,
    this.entityId = 'task',
    this.fields = const [],
    this.displayName = 'Task',
  });

  final String entityName;
  final String entityId;
  final List<BlueprintField> fields;
  final String displayName;

  @override
  String get patternId => 'planner';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.planner];

  @override
  AppBlueprint apply(IntentUnderstanding understanding) {
    final id = _stableId(understanding.objective);

    final entityFields = [
      BlueprintField(
        id: '${entityId}_id',
        name: 'ID',
        type: BlueprintFieldType.text,
        required: true,
      ),
      BlueprintField(
        id: '${entityId}_title',
        name: 'Title',
        type: BlueprintFieldType.text,
        required: true,
      ),
      BlueprintField(
        id: '${entityId}_subject',
        name: 'Subject',
        type: BlueprintFieldType.text,
      ),
      BlueprintField(
        id: '${entityId}_due_date',
        name: 'Due Date',
        type: BlueprintFieldType.date,
      ),
      BlueprintField(
        id: '${entityId}_completed',
        name: 'Completed',
        type: BlueprintFieldType.boolean,
        defaultValue: 'false',
      ),
      ...fields,
      BlueprintField(
        id: '${entityId}_created_at',
        name: 'Created At',
        type: BlueprintFieldType.dateTime,
        required: true,
      ),
    ];

    final entity = BlueprintEntity(
      id: entityId,
      name: entityName,
      fields: entityFields,
      displayField: '${entityId}_title',
    );

    final upcomingView = BlueprintView(
      id: '${entityId}_upcoming',
      name: 'Upcoming',
      purpose: 'Upcoming $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      primaryActionId: 'create_${entityId}',
      sections: [
        BlueprintViewSection(
          id: 'upcoming_list',
          purpose: 'Pending $entityName',
          sourceEntityId: entityId,
          filter: 'completed = false',
          sectionType: BlueprintSectionType.list,
        ),
        BlueprintViewSection(
          id: 'upcoming_summary',
          purpose: 'Summary',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.summary,
        ),
      ],
      isDefault: true,
    );

    final allView = BlueprintView(
      id: '${entityId}_all',
      name: 'All $displayName',
      purpose: 'All $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      sections: [
        BlueprintViewSection(
          id: 'all_list',
          purpose: 'All $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
      ],
    );

    final formView = BlueprintView(
      id: '${entityId}_form',
      name: 'Add/Edit $displayName',
      purpose: 'Create or edit $entityName',
      entityId: entityId,
      viewType: BlueprintViewType.form,
    );

    final derivedValues = [
      BlueprintDerivedValue(
        id: 'pending_count',
        name: 'Pending Count',
        sourceEntityId: entityId,
        operation: DerivedOperation.count,
        description: 'Number of pending tasks',
      ),
      BlueprintDerivedValue(
        id: 'completed_count',
        name: 'Completed Count',
        sourceEntityId: entityId,
        operation: DerivedOperation.count,
        description: 'Number of completed tasks',
      ),
    ];

    final actions = [
      BlueprintAction(
        id: 'create_${entityId}',
        name: 'Add $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      BlueprintAction(
        id: 'complete_${entityId}',
        name: 'Complete $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.setValue,
        derivedEffect: 'Mark as completed',
      ),
      BlueprintAction(
        id: 'update_${entityId}',
        name: 'Update $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.update,
      ),
      BlueprintAction(
        id: 'delete_${entityId}',
        name: 'Delete $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    return AppBlueprint(
      id: id,
      name: understanding.objective,
      description: 'Plan and track $entityName',
      archetypes: [AppArchetype.planner],
      domain: AppDomain.education,
      entities: [entity],
      views: [upcomingView, allView, formView],
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String objective) {
    return 'bp_${objective.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${entityId}';
  }
}

/// Dashboard pattern — summary-first with aggregation.
///
/// Used for: Expense Tracker, Budget Tracker, Analytics.
/// Characteristics: aggregated data, category totals, trends.
class DashboardPattern extends SynthesisPattern {
  const DashboardPattern({
    required this.entityName,
    this.entityId = 'item',
    this.fields = const [],
    this.displayName = 'Item',
    this.aggregateFieldName = 'amount',
  });

  final String entityName;
  final String entityId;
  final List<BlueprintField> fields;
  final String displayName;
  final String aggregateFieldName;

  @override
  String get patternId => 'dashboard';

  @override
  List<AppArchetype> get supportedArchetypes => [AppArchetype.dashboard];

  @override
  AppBlueprint apply(IntentUnderstanding understanding) {
    final id = _stableId(understanding.objective);

    final entityFields = [
      BlueprintField(
        id: '${entityId}_id',
        name: 'ID',
        type: BlueprintFieldType.text,
        required: true,
      ),
      ...fields,
      BlueprintField(
        id: '${entityId}_date',
        name: 'Date',
        type: BlueprintFieldType.date,
        required: true,
      ),
      BlueprintField(
        id: '${entityId}_created_at',
        name: 'Created At',
        type: BlueprintFieldType.dateTime,
        required: true,
      ),
    ];

    final entity = BlueprintEntity(
      id: entityId,
      name: entityName,
      fields: entityFields,
      displayField: '${entityId}_id',
    );

    final overviewView = BlueprintView(
      id: '${entityId}_overview',
      name: 'Overview',
      purpose: '$entityName overview with totals',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.dashboard,
      primaryActionId: 'create_${entityId}',
      sections: [
        BlueprintViewSection(
          id: 'overview_total',
          purpose: 'Total summary',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.summary,
        ),
        BlueprintViewSection(
          id: 'overview_recent',
          purpose: 'Recent $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
          limit: 10,
        ),
      ],
      isDefault: true,
    );

    final listView = BlueprintView(
      id: '${entityId}_list',
      name: 'All $displayName',
      purpose: 'All $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      sections: [
        BlueprintViewSection(
          id: 'all_list',
          purpose: 'All $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
      ],
    );

    final formView = BlueprintView(
      id: '${entityId}_form',
      name: 'Add/Edit $displayName',
      purpose: 'Add or edit $entityName',
      entityId: entityId,
      viewType: BlueprintViewType.form,
    );

    final derivedValues = [
      BlueprintDerivedValue(
        id: 'total_${aggregateFieldName}',
        name: 'Total $aggregateFieldName',
        sourceEntityId: entityId,
        operation: DerivedOperation.sum,
        fieldId: aggregateFieldName,
        description: 'Sum of all $aggregateFieldName',
      ),
      BlueprintDerivedValue(
        id: 'count_${entityId}',
        name: 'Total Count',
        sourceEntityId: entityId,
        operation: DerivedOperation.count,
        description: 'Total number of $entityName',
      ),
    ];

    final actions = [
      BlueprintAction(
        id: 'create_${entityId}',
        name: 'Add $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      BlueprintAction(
        id: 'update_${entityId}',
        name: 'Update $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.update,
      ),
      BlueprintAction(
        id: 'delete_${entityId}',
        name: 'Delete $displayName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    return AppBlueprint(
      id: id,
      name: understanding.objective,
      description: 'Track and summarize $entityName',
      archetypes: [AppArchetype.dashboard],
      domain: AppDomain.finances,
      entities: [entity],
      views: [overviewView, listView, formView],
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: OfflinePolicy.full,
    );
  }

  String _stableId(String objective) {
    return 'bp_${objective.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${entityId}';
  }
}

/// Registry of available synthesis patterns.
class PatternRegistry {
  static final Map<String, SynthesisPattern Function()> _factories = {
    'collection': () => const _DefaultCollectionPattern(),
    'tracker': () => const _DefaultTrackerPattern(),
    'planner': () => const _DefaultPlannerPattern(),
    'dashboard': () => const _DefaultDashboardPattern(),
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

/// Default collection pattern for auto-selection.
class _DefaultCollectionPattern extends CollectionPattern {
  const _DefaultCollectionPattern()
    : super(entityName: 'Item', displayName: 'Item');
}

/// Default tracker pattern for auto-selection.
class _DefaultTrackerPattern extends TrackerPattern {
  const _DefaultTrackerPattern()
    : super(entityName: 'Trackable', displayName: 'Trackable');
}

/// Default planner pattern for auto-selection.
class _DefaultPlannerPattern extends PlannerPattern {
  const _DefaultPlannerPattern()
    : super(entityName: 'Task', displayName: 'Task');
}

/// Default dashboard pattern for auto-selection.
class _DefaultDashboardPattern extends DashboardPattern {
  const _DefaultDashboardPattern()
    : super(entityName: 'Record', displayName: 'Record');
}
