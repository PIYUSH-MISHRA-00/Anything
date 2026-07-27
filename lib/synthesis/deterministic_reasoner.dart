/// Deterministic Application Reasoner — handles simple structural requests
/// without AI.
///
/// This reasoner works from generic semantic information already available
/// in the user's intent. It does not contain domain-specific knowledge.
///
/// Its purpose is to handle requests where:
/// - objective already contains explicit entities/fields/actions
/// - simple collection request where entity name is obvious from words
///
/// Everything else escalates to model reasoning.
library;

import 'app_blueprint.dart';
import 'application_reasoner.dart';

/// Deterministic application reasoner.
///
/// Handles simple structural requests by extracting semantic information
/// directly from the intent understanding. No AI required.
///
/// Principle: only handle requests whose semantics are obvious from
/// the words themselves. When uncertain, escalate.
class DeterministicReasoner implements ApplicationReasoner {
  const DeterministicReasoner();

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    final understanding = context.understanding;
    final objective = understanding.objective;

    // Simple collection patterns: "make a list of X", "create a list of X"
    final collectionResult = _tryCollectionReasoning(objective);
    if (collectionResult != null) {
      return ReasoningReady(semanticApp: collectionResult);
    }

    // Cannot handle deterministically — require model reasoning
    return const ReasoningProviderRequired();
  }

  /// Try to handle as a simple collection.
  ///
  /// Only succeeds when:
  /// - "list of X" or "create a list of X" pattern is explicit
  /// - Entity name is clearly extractable from the objective
  /// - No ambiguous domain semantics
  SemanticApp? _tryCollectionReasoning(String objective) {
    final lower = objective.toLowerCase();

    // Must contain collection keywords
    if (!lower.contains('list') && !lower.contains('collection')) {
      return null;
    }

    // Must have "of X" or similar explicit entity reference
    final entityName = _extractEntityName(objective);
    if (entityName == null) return null;

    // Reject overly generic requests
    if (_isTooGeneric(lower)) return null;

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
        id: 'create_$entityId',
        name: 'Add $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.create,
      ),
      SemanticAction(
        id: 'update_$entityId',
        name: 'Update $entityName',
        targetEntityId: entityId,
        actionType: BlueprintActionType.update,
      ),
      SemanticAction(
        id: 'delete_$entityId',
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

  /// Check if the objective is too generic for deterministic handling.
  bool _isTooGeneric(String lower) {
    const genericPhrases = [
      'create an app',
      'make me something',
      'manage my',
      'organize my',
      'organize life',
      'build something',
      'i need an app',
      'an application',
      'a tool',
      'something for',
      'help me',
    ];
    for (final phrase in genericPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  /// Extract entity name from the objective.
  ///
  /// This is purely structural — it looks for nouns after "list of" or
  /// "collection of". It does NOT contain domain-specific knowledge.
  /// Returns null when extraction is uncertain.
  String? _extractEntityName(String objective) {
    // Stop words that should not become entity names
    const stopWords = {
      'a',
      'an',
      'the',
      'my',
      'your',
      'our',
      'its',
      'list',
      'app',
      'application',
      'tool',
      'thing',
      'something',
      'stuff',
      'items',
      'records',
      'collection',
    };

    // Only extract from clear collection patterns
    final patterns = [
      RegExp(r'list of (\w+)', caseSensitive: false),
      RegExp(r'collection of (\w+)', caseSensitive: false),
      RegExp(r'(\w+) list', caseSensitive: false),
      RegExp(r'(\w+) collection', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(objective);
      if (match != null) {
        final name = match.group(1)!;
        final lower = name.toLowerCase();
        if (stopWords.contains(lower)) continue;
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
    if (_containsWord(lower, 'list')) tags.add('list');
    if (_containsWord(lower, 'collection')) tags.add('collection');

    return tags;
  }

  /// Check if text contains a whole word (not as substring of another word).
  bool _containsWord(String text, String word) {
    return RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(text);
  }
}
