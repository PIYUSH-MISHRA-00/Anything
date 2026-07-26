/// Synthesis Planner — converts IntentUnderstanding into an AppBlueprint.
///
/// The planner is the core synthesis engine. It takes a structured understanding
/// of what the user wants and produces a technology-independent AppBlueprint
/// that can be validated and synthesized into an ExperiencePackage.
library;

import '../kernel/understanding/intent_understanding.dart';
import '../kernel/specification/experience_spec.dart' show NetworkNeed;
import 'app_archetype.dart';
import 'app_blueprint.dart';
import 'synthesis_patterns.dart';

/// Result of synthesis planning.
class SynthesisResult {
  const SynthesisResult({
    required this.blueprint,
    this.patterns = const [],
    this.notes = const [],
  });

  final AppBlueprint blueprint;
  final List<String> patterns;
  final List<String> notes;
}

/// The Synthesis Planner converts IntentUnderstanding into AppBlueprints.
///
/// It detects the app's archetype from the understanding, selects appropriate
/// synthesis patterns, and produces a validated AppBlueprint.
class SynthesisPlanner {
  const SynthesisPlanner();

  /// Plan an AppBlueprint from an IntentUnderstanding.
  ///
  /// The planner:
  /// 1. Detects the primary archetype from the objective
  /// 2. Selects appropriate synthesis patterns
  /// 3. Applies patterns to build entity/view/action structure
  /// 4. Adds derived values based on archetype
  /// 5. Returns a complete AppBlueprint
  SynthesisResult plan(IntentUnderstanding understanding) {
    final archetype = _detectArchetype(understanding);
    final patterns = _selectPatterns(understanding, archetype);
    final blueprint = _applyPatterns(understanding, patterns);
    final enriched = _addDerivedValues(blueprint, understanding);
    final customized = _customizeFromUnderstanding(enriched, understanding);

    return SynthesisResult(
      blueprint: customized,
      patterns: patterns.map((p) => p.patternId).toList(),
      notes: _generateNotes(understanding, patterns),
    );
  }

  /// Detect the primary archetype from the understanding.
  AppArchetype _detectArchetype(IntentUnderstanding understanding) {
    final objective = understanding.objective.toLowerCase();

    // Keyword-based archetype detection
    if (_isUtility(objective)) return AppArchetype.utility;
    if (_isTracker(objective)) return AppArchetype.tracker;
    if (_isPlanner(objective)) return AppArchetype.planner;
    if (_isDashboard(objective)) return AppArchetype.dashboard;
    if (_isReference(objective)) return AppArchetype.reference;
    if (_isCollection(objective)) return AppArchetype.collection;

    // Default to collection for most create intents
    return AppArchetype.collection;
  }

  bool _isUtility(String objective) {
    return objective.contains('calculator') ||
        objective.contains('converter') ||
        objective.contains('timer') ||
        objective.contains('clock');
  }

  bool _isTracker(String objective) {
    return objective.contains('habit') ||
        objective.contains('track') && objective.contains('daily') ||
        objective.contains('mood') ||
        objective.contains('water intake') ||
        objective.contains('exercise');
  }

  bool _isPlanner(String objective) {
    return objective.contains('planner') ||
        objective.contains('study') ||
        objective.contains('task') ||
        objective.contains('homework') ||
        objective.contains('assignment');
  }

  bool _isDashboard(String objective) {
    return objective.contains('expense') ||
        objective.contains('budget') ||
        objective.contains('finance') ||
        objective.contains('spending') ||
        objective.contains('price');
  }

  bool _isReference(String objective) {
    return objective.contains('weather') ||
        objective.contains('dashboard') && objective.contains('price') ||
        objective.contains('news');
  }

  bool _isCollection(String objective) {
    return objective.contains('note') ||
        objective.contains('list') ||
        objective.contains('book') ||
        objective.contains('grocery') ||
        objective.contains('bookmark') ||
        objective.contains('keep') ||
        objective.contains('collection');
  }

  /// Select synthesis patterns based on archetype and domain.
  List<SynthesisPattern> _selectPatterns(
    IntentUnderstanding understanding,
    AppArchetype archetype,
  ) {
    final objective = understanding.objective.toLowerCase();
    final patterns = <SynthesisPattern>[];

    switch (archetype) {
      case AppArchetype.tracker:
        final domain = _detectTrackerDomain(objective);
        patterns.add(
          TrackerPattern(
            entityName: domain.entityName,
            entityId: domain.entityId,
            displayName: domain.displayName,
            fields: domain.extraFields,
          ),
        );
        break;

      case AppArchetype.planner:
        final domain = _detectPlannerDomain(objective);
        patterns.add(
          PlannerPattern(
            entityName: domain.entityName,
            entityId: domain.entityId,
            displayName: domain.displayName,
            fields: domain.extraFields,
          ),
        );
        break;

      case AppArchetype.dashboard:
        final domain = _detectDashboardDomain(objective);
        patterns.add(
          DashboardPattern(
            entityName: domain.entityName,
            entityId: domain.entityId,
            displayName: domain.displayName,
            fields: domain.extraFields,
            aggregateFieldName: domain.aggregateField,
          ),
        );
        break;

      case AppArchetype.collection:
        final domain = _detectCollectionDomain(objective);
        patterns.add(
          CollectionPattern(
            entityName: domain.entityName,
            entityId: domain.entityId,
            displayName: domain.displayName,
            fields: domain.extraFields,
          ),
        );
        break;

      case AppArchetype.reference:
        // Reference apps get network configuration but no collection pattern
        break;

      default:
        patterns.add(const _DefaultCollectionPattern());
    }

    return patterns;
  }

  _DomainInfo _detectTrackerDomain(String objective) {
    if (objective.contains('habit')) {
      return _DomainInfo(
        entityName: 'Habit',
        entityId: 'habit',
        displayName: 'Habit',
      );
    }
    if (objective.contains('water')) {
      return _DomainInfo(
        entityName: 'Water Intake',
        entityId: 'water_intake',
        displayName: 'Water Entry',
        extraFields: [
          const BlueprintField(
            id: 'amount_ml',
            name: 'Amount (ml)',
            type: BlueprintFieldType.integer,
            defaultValue: '250',
          ),
        ],
      );
    }
    return _DomainInfo(
      entityName: 'Trackable',
      entityId: 'trackable',
      displayName: 'Item',
    );
  }

  _DomainInfo _detectPlannerDomain(String objective) {
    if (objective.contains('study')) {
      return _DomainInfo(
        entityName: 'Study Task',
        entityId: 'study_task',
        displayName: 'Study Task',
        extraFields: [
          const BlueprintField(
            id: 'study_subject',
            name: 'Subject',
            type: BlueprintFieldType.text,
          ),
        ],
      );
    }
    return _DomainInfo(
      entityName: 'Task',
      entityId: 'task',
      displayName: 'Task',
    );
  }

  _DomainInfo _detectDashboardDomain(String objective) {
    if (objective.contains('expense') ||
        objective.contains('spending') ||
        objective.contains('track') && objective.contains('money')) {
      return _DomainInfo(
        entityName: 'Expense',
        entityId: 'expense',
        displayName: 'Expense',
        aggregateField: 'expense_amount',
        extraFields: [
          const BlueprintField(
            id: 'expense_amount',
            name: 'Amount',
            type: BlueprintFieldType.decimal,
            required: true,
            minimum: 0,
          ),
          const BlueprintField(
            id: 'expense_category',
            name: 'Category',
            type: BlueprintFieldType.category,
            allowedValues: [
              'Food',
              'Transport',
              'Entertainment',
              'Shopping',
              'Bills',
              'Other',
            ],
          ),
          const BlueprintField(
            id: 'expense_note',
            name: 'Note',
            type: BlueprintFieldType.text,
          ),
        ],
      );
    }
    return _DomainInfo(
      entityName: 'Record',
      entityId: 'record',
      displayName: 'Record',
      aggregateField: 'record_value',
      extraFields: [
        const BlueprintField(
          id: 'record_value',
          name: 'Value',
          type: BlueprintFieldType.decimal,
          required: true,
        ),
      ],
    );
  }

  _DomainInfo _detectCollectionDomain(String objective) {
    if (objective.contains('note')) {
      return _DomainInfo(
        entityName: 'Note',
        entityId: 'note',
        displayName: 'Note',
        extraFields: [
          const BlueprintField(
            id: 'note_content',
            name: 'Content',
            type: BlueprintFieldType.multilineText,
          ),
        ],
      );
    }
    if (objective.contains('book') || objective.contains('read')) {
      return _DomainInfo(
        entityName: 'Book',
        entityId: 'book',
        displayName: 'Book',
        extraFields: [
          const BlueprintField(
            id: 'book_author',
            name: 'Author',
            type: BlueprintFieldType.text,
          ),
          const BlueprintField(
            id: 'book_status',
            name: 'Status',
            type: BlueprintFieldType.category,
            allowedValues: ['Want to Read', 'Reading', 'Finished'],
            defaultValue: 'Want to Read',
          ),
        ],
      );
    }
    if (objective.contains('grocery') || objective.contains('shop')) {
      return _DomainInfo(
        entityName: 'Grocery Item',
        entityId: 'grocery',
        displayName: 'Item',
        extraFields: [
          const BlueprintField(
            id: 'grocery_quantity',
            name: 'Quantity',
            type: BlueprintFieldType.integer,
            defaultValue: '1',
          ),
          const BlueprintField(
            id: 'grocery_purchased',
            name: 'Purchased',
            type: BlueprintFieldType.boolean,
            defaultValue: 'false',
          ),
        ],
      );
    }
    return _DomainInfo(
      entityName: 'Item',
      entityId: 'item',
      displayName: 'Item',
    );
  }

  /// Apply selected patterns to create the blueprint.
  AppBlueprint _applyPatterns(
    IntentUnderstanding understanding,
    List<SynthesisPattern> patterns,
  ) {
    if (patterns.isEmpty) {
      return _createDefaultBlueprint(understanding);
    }

    // Apply the first (primary) pattern
    return patterns.first.apply(understanding);
  }

  AppBlueprint _createDefaultBlueprint(IntentUnderstanding understanding) {
    return AppBlueprint(
      id: 'bp_default',
      name: understanding.objective,
      description: 'A custom application',
      archetypes: [AppArchetype.collection],
      offlinePolicy: OfflinePolicy.full,
    );
  }

  /// Add derived values based on archetype and domain.
  AppBlueprint _addDerivedValues(
    AppBlueprint blueprint,
    IntentUnderstanding understanding,
  ) {
    // Derived values are already added by patterns
    return blueprint;
  }

  /// Customize blueprint based on specific understanding details.
  AppBlueprint _customizeFromUnderstanding(
    AppBlueprint blueprint,
    IntentUnderstanding understanding,
  ) {
    // Apply any specific constraints or requirements from the understanding
    var result = blueprint;

    if (understanding.networkNeed == NetworkNeed.required) {
      result = result.copyWith(
        offlinePolicy: OfflinePolicy.networkRequired,
        networkConfig: const BlueprintNetworkConfig(
          purpose: 'External data',
          cacheStrategy: BlueprintCacheStrategy.networkFirst,
        ),
      );
    }

    return result;
  }

  /// Generate human-readable notes about the synthesis.
  List<String> _generateNotes(
    IntentUnderstanding understanding,
    List<SynthesisPattern> patterns,
  ) {
    final notes = <String>[];
    notes.add('Detected archetype: ${_detectArchetype(understanding).name}');
    notes.add(
      'Applied patterns: ${patterns.map((p) => p.patternId).join(", ")}',
    );
    if (understanding.ambiguities.isNotEmpty) {
      notes.add(
        'Ambiguities: ${understanding.ambiguities.map((a) => a.description).join(", ")}',
      );
    }
    return notes;
  }
}

class _DomainInfo {
  const _DomainInfo({
    required this.entityName,
    required this.entityId,
    required this.displayName,
    this.extraFields = const [],
    this.aggregateField = '',
  });

  final String entityName;
  final String entityId;
  final String displayName;
  final List<BlueprintField> extraFields;
  final String aggregateField;
}

/// Default collection pattern for auto-selection.
class _DefaultCollectionPattern extends CollectionPattern {
  const _DefaultCollectionPattern()
    : super(entityName: 'Item', displayName: 'Item');
}
