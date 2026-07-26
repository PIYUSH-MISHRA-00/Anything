/// Deterministic Application Reasoner — handles simple structural requests
/// without AI.
///
/// This reasoner works from generic semantic information already available
/// in the user's intent. It does not contain domain-specific knowledge.
///
/// Its purpose is to handle requests where:
/// - objective already contains explicit entities/fields/actions
/// - simple collection request
/// - simple counter
/// - simple form/list
library;

import '../kernel/understanding/intent_understanding.dart';
import 'app_blueprint.dart';
import 'application_reasoner.dart';

/// Deterministic application reasoner.
///
/// Handles simple structural requests by extracting semantic information
/// directly from the intent understanding. No AI required.
class DeterministicReasoner implements ApplicationReasoner {
  const DeterministicReasoner();

  @override
  Future<AppReasoningResult> reason(IntentUnderstanding understanding) async {
    final objective = understanding.objective;

    // Simple tracker patterns: "track X", "daily X", "X tracker"
    final trackerResult = _tryTrackerReasoning(objective);
    if (trackerResult != null) {
      return ReasoningReady(semanticApp: trackerResult);
    }

    // Simple planner patterns: "plan X", "schedule X", "organize X"
    final plannerResult = _tryPlannerReasoning(objective);
    if (plannerResult != null) {
      return ReasoningReady(semanticApp: plannerResult);
    }

    // Simple dashboard/aggregation: "total X", "summarize X"
    final dashboardResult = _tryDashboardReasoning(objective);
    if (dashboardResult != null) {
      return ReasoningReady(semanticApp: dashboardResult);
    }

    // Simple collection patterns: "make a list of X", "create a list of X"
    final collectionResult = _tryCollectionReasoning(objective);
    if (collectionResult != null) {
      return ReasoningReady(semanticApp: collectionResult);
    }

    // Cannot handle deterministically — require model reasoning
    return const ReasoningProviderRequired();
  }

  SemanticApp? _tryCollectionReasoning(String objective) {
    final lower = objective.toLowerCase();

    // Detect collection intent
    if (!lower.contains('list') &&
        !lower.contains('track') &&
        !lower.contains('manage') &&
        !lower.contains('organize') &&
        !lower.contains('create')) {
      return null;
    }

    // Extract the subject/entity from the objective
    final entityName = _extractEntityName(objective);
    if (entityName == null) return null;

    final entityId = _toEntityId(entityName);

    final entity = SemanticEntity(
      id: entityId,
      name: entityName,
      fields: [
        SemanticField(
          id: '${entityId}_name',
          name: 'Name',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: '${entityId}_description',
          name: 'Description',
          type: BlueprintFieldType.multilineText,
        ),
        SemanticField(
          id: '${entityId}_created_at',
          name: 'Created At',
          type: BlueprintFieldType.dateTime,
          required: true,
        ),
        SemanticField(
          id: '${entityId}_updated_at',
          name: 'Updated At',
          type: BlueprintFieldType.dateTime,
          required: true,
        ),
      ],
      displayField: '${entityId}_name',
    );

    final actions = [
      SemanticAction(
        id: 'create_${entityId}',
        name: 'Add $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      SemanticAction(
        id: 'update_${entityId}',
        name: 'Update $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.update,
      ),
      SemanticAction(
        id: 'delete_${entityId}',
        name: 'Delete $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    final listView = SemanticView(
      id: '${entityId}_list',
      name: '$entityName List',
      purpose: 'View all $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      sections: [
        SemanticViewSection(
          id: '${entityId}_list_section',
          purpose: 'All $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
      ],
      isDefault: true,
    );

    final formView = SemanticView(
      id: '${entityId}_form',
      name: 'Add/Edit $entityName',
      purpose: 'Create or edit $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.form,
    );

    return SemanticApp(
      name: _deriveName(objective),
      purpose: objective,
      entities: [entity],
      actions: actions,
      views: [listView, formView],
      archetypes: ['collection'],
      tags: _extractTags(objective),
    );
  }

  SemanticApp? _tryTrackerReasoning(String objective) {
    final lower = objective.toLowerCase();

    // Detect tracker intent
    if (!lower.contains('track') &&
        !lower.contains('daily') &&
        !lower.contains('habit') &&
        !lower.contains('streak')) {
      return null;
    }

    final entityName = _extractEntityName(objective) ?? 'Trackable';
    final entityId = _toEntityId(entityName);

    final entity = SemanticEntity(
      id: entityId,
      name: entityName,
      fields: [
        SemanticField(
          id: '${entityId}_name',
          name: 'Name',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: '${entityId}_created_at',
          name: 'Created At',
          type: BlueprintFieldType.dateTime,
          required: true,
        ),
      ],
      displayField: '${entityId}_name',
    );

    final completionEntity = SemanticEntity(
      id: '${entityId}_completions',
      name: '$entityName Completions',
      fields: [
        SemanticField(
          id: 'completion_id',
          name: 'ID',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: 'trackable_id',
          name: 'Trackable ID',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: 'completion_date',
          name: 'Date',
          type: BlueprintFieldType.date,
          required: true,
        ),
        SemanticField(
          id: 'completed',
          name: 'Completed',
          type: BlueprintFieldType.boolean,
          defaultValue: 'false',
        ),
        SemanticField(
          id: 'completion_note',
          name: 'Note',
          type: BlueprintFieldType.text,
        ),
      ],
    );

    final derivedValues = [
      SemanticDerivedValue(
        id: 'today_completed',
        name: 'Completed Today',
        sourceEntityId: '${entityId}_completions',
        operation: DerivedOperation.count,
        description: 'Number of items completed today',
      ),
    ];

    final actions = [
      SemanticAction(
        id: 'create_${entityId}',
        name: 'Add $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      SemanticAction(
        id: 'toggle_${entityId}',
        name: 'Toggle $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.toggle,
        derivedEffect: 'Toggle today completion',
      ),
      SemanticAction(
        id: 'delete_${entityId}',
        name: 'Delete $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    final todayView = SemanticView(
      id: '${entityId}_today',
      name: 'Today',
      purpose: "Today's $entityName",
      sourceEntityId: entityId,
      viewType: BlueprintViewType.dashboard,
      sections: [
        SemanticViewSection(
          id: 'today_list',
          purpose: "Today's $entityName",
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
        SemanticViewSection(
          id: 'today_summary',
          purpose: 'Completion summary',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.summary,
        ),
      ],
      isDefault: true,
    );

    final formView = SemanticView(
      id: '${entityId}_form',
      name: 'Add/Edit $entityName',
      purpose: 'Create or edit $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.form,
    );

    return SemanticApp(
      name: _deriveName(objective),
      purpose: objective,
      entities: [entity, completionEntity],
      actions: actions,
      derivedValues: derivedValues,
      views: [todayView, formView],
      archetypes: ['tracker'],
      tags: _extractTags(objective),
    );
  }

  SemanticApp? _tryPlannerReasoning(String objective) {
    final lower = objective.toLowerCase();

    if (!_containsWord(lower, 'plan') &&
        !_containsWord(lower, 'schedule') &&
        !_containsWord(lower, 'task') &&
        !_containsWord(lower, 'todo') &&
        !_containsWord(lower, 'assignment')) {
      return null;
    }

    final entityName = _extractEntityName(objective) ?? 'Task';
    final entityId = _toEntityId(entityName);

    final entity = SemanticEntity(
      id: entityId,
      name: entityName,
      fields: [
        SemanticField(
          id: '${entityId}_title',
          name: 'Title',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: '${entityId}_description',
          name: 'Description',
          type: BlueprintFieldType.multilineText,
        ),
        SemanticField(
          id: '${entityId}_due_date',
          name: 'Due Date',
          type: BlueprintFieldType.date,
        ),
        SemanticField(
          id: '${entityId}_completed',
          name: 'Completed',
          type: BlueprintFieldType.boolean,
          defaultValue: 'false',
        ),
        SemanticField(
          id: '${entityId}_created_at',
          name: 'Created At',
          type: BlueprintFieldType.dateTime,
          required: true,
        ),
      ],
      displayField: '${entityId}_title',
    );

    final derivedValues = [
      SemanticDerivedValue(
        id: 'pending_count',
        name: 'Pending Count',
        sourceEntityId: entityId,
        operation: DerivedOperation.count,
        description: 'Number of pending tasks',
      ),
      SemanticDerivedValue(
        id: 'completed_count',
        name: 'Completed Count',
        sourceEntityId: entityId,
        operation: DerivedOperation.count,
        description: 'Number of completed tasks',
      ),
    ];

    final actions = [
      SemanticAction(
        id: 'create_${entityId}',
        name: 'Add $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      SemanticAction(
        id: 'complete_${entityId}',
        name: 'Complete $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.setValue,
        derivedEffect: 'Mark as completed',
      ),
      SemanticAction(
        id: 'update_${entityId}',
        name: 'Update $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.update,
      ),
      SemanticAction(
        id: 'delete_${entityId}',
        name: 'Delete $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    final listView = SemanticView(
      id: '${entityId}_list',
      name: '$entityName List',
      purpose: 'View all $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      sections: [
        SemanticViewSection(
          id: 'upcoming_list',
          purpose: 'Pending $entityName',
          sourceEntityId: entityId,
          filter: 'completed = false',
          sectionType: BlueprintSectionType.list,
        ),
        SemanticViewSection(
          id: 'upcoming_summary',
          purpose: 'Summary',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.summary,
        ),
      ],
      isDefault: true,
    );

    final formView = SemanticView(
      id: '${entityId}_form',
      name: 'Add/Edit $entityName',
      purpose: 'Create or edit $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.form,
    );

    return SemanticApp(
      name: _deriveName(objective),
      purpose: objective,
      entities: [entity],
      actions: actions,
      derivedValues: derivedValues,
      views: [listView, formView],
      archetypes: ['planner'],
      tags: _extractTags(objective),
    );
  }

  SemanticApp? _tryDashboardReasoning(String objective) {
    final lower = objective.toLowerCase();

    if (!lower.contains('total') &&
        !lower.contains('summarize') &&
        !lower.contains('summary') &&
        !lower.contains('aggregate') &&
        !lower.contains('budget')) {
      return null;
    }

    final entityName = _extractEntityName(objective) ?? 'Record';
    final entityId = _toEntityId(entityName);

    final entity = SemanticEntity(
      id: entityId,
      name: entityName,
      fields: [
        SemanticField(
          id: '${entityId}_name',
          name: 'Name',
          type: BlueprintFieldType.text,
          required: true,
        ),
        SemanticField(
          id: '${entityId}_amount',
          name: 'Amount',
          type: BlueprintFieldType.decimal,
          required: true,
          minimum: 0,
        ),
        SemanticField(
          id: '${entityId}_date',
          name: 'Date',
          type: BlueprintFieldType.date,
          required: true,
        ),
        SemanticField(
          id: '${entityId}_created_at',
          name: 'Created At',
          type: BlueprintFieldType.dateTime,
          required: true,
        ),
      ],
      displayField: '${entityId}_name',
    );

    final derivedValues = [
      SemanticDerivedValue(
        id: 'total_${entityId}',
        name: 'Total ${entityName}',
        sourceEntityId: entityId,
        operation: DerivedOperation.sum,
        fieldId: '${entityId}_amount',
        description: 'Sum of all ${entityName}',
      ),
      SemanticDerivedValue(
        id: 'count_${entityId}',
        name: 'Total Count',
        sourceEntityId: entityId,
        operation: DerivedOperation.count,
        description: 'Total number of ${entityName}',
      ),
    ];

    final actions = [
      SemanticAction(
        id: 'create_${entityId}',
        name: 'Add $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      SemanticAction(
        id: 'update_${entityId}',
        name: 'Update $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.update,
      ),
      SemanticAction(
        id: 'delete_${entityId}',
        name: 'Delete $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.delete,
      ),
    ];

    final dashboardView = SemanticView(
      id: '${entityId}_overview',
      name: '$entityName Overview',
      purpose: '$entityName overview with totals',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.dashboard,
      sections: [
        SemanticViewSection(
          id: 'overview_total',
          purpose: 'Total summary',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.summary,
        ),
        SemanticViewSection(
          id: 'overview_recent',
          purpose: 'Recent $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
          limit: 10,
        ),
      ],
      isDefault: true,
    );

    final listView = SemanticView(
      id: '${entityId}_list',
      name: 'All $entityName',
      purpose: 'All $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.list,
      sections: [
        SemanticViewSection(
          id: 'all_list',
          purpose: 'All $entityName',
          sourceEntityId: entityId,
          sectionType: BlueprintSectionType.list,
        ),
      ],
    );

    final formView = SemanticView(
      id: '${entityId}_form',
      name: 'Add/Edit $entityName',
      purpose: 'Add or edit $entityName',
      sourceEntityId: entityId,
      viewType: BlueprintViewType.form,
    );

    return SemanticApp(
      name: _deriveName(objective),
      purpose: objective,
      entities: [entity],
      actions: actions,
      derivedValues: derivedValues,
      views: [dashboardView, listView, formView],
      archetypes: ['dashboard'],
      tags: _extractTags(objective),
    );
  }

  /// Extract entity name from the objective.
  ///
  /// This is purely structural — it looks for nouns after verbs like
  /// "list of", "track", "manage", "create", etc.
  /// It does NOT contain domain-specific knowledge.
  String? _extractEntityName(String objective) {
    // Try to extract after common patterns
    final patterns = [
      RegExp(r'list of (\w+)', caseSensitive: false),
      RegExp(r'track (?:my )?(\w+)', caseSensitive: false),
      RegExp(r'manage (?:my )?(\w+)', caseSensitive: false),
      RegExp(r'create (?:a )?(?:new )?(\w+)', caseSensitive: false),
      RegExp(r'organize (?:my )?(\w+)', caseSensitive: false),
      RegExp(r'(\w+) tracker', caseSensitive: false),
      RegExp(r'(\w+) planner', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(objective);
      if (match != null) {
        final name = match.group(1)!;
        // Capitalize
        return name[0].toUpperCase() + name.substring(1);
      }
    }

    return null;
  }

  /// Derive a display name from the objective.
  String _deriveName(String objective) {
    if (objective.isEmpty) return 'Untitled';
    return objective[0].toUpperCase() + objective.substring(1);
  }

  /// Convert a name to a stable entity ID.
  String _toEntityId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Extract open-world tags from the objective.
  List<String> _extractTags(String objective) {
    final tags = <String>[];
    final lower = objective.toLowerCase();

    // Structural tags (not domain-specific)
    if (lower.contains('list')) tags.add('list');
    if (lower.contains('track')) tags.add('tracker');
    if (lower.contains('daily') || lower.contains('daily')) {
      tags.add('daily');
    }
    if (lower.contains('plan') || lower.contains('schedule')) {
      tags.add('planner');
    }
    if (lower.contains('total') || lower.contains('summarize')) {
      tags.add('dashboard');
    }
    if (lower.contains('manage')) tags.add('management');

    return tags;
  }

  /// Check if text contains a whole word (not as substring of another word).
  bool _containsWord(String text, String word) {
    return RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(text);
  }
}
