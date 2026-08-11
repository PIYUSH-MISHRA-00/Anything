/// Deterministic Application Reasoner — handles structural requests without AI.
///
/// Works from generic semantic information in the user's intent. Does not
/// contain domain-specific application factories.
library;

import '../creation/app_capabilities.dart';
import '../creation/intent_preservation.dart';
import 'app_blueprint.dart';
import 'application_reasoner.dart';
import 'structural_entity_extractor.dart';
import 'structural_field_inferrer.dart';

/// Deterministic application reasoner.
class DeterministicReasoner implements ApplicationReasoner {
  const DeterministicReasoner();

  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    final understanding = context.understanding;
    final objective = understanding.objective;

    final managed = _tryManagedRecordsReasoning(objective);
    if (managed != null) {
      return ReasoningReady(semanticApp: managed);
    }

    final collectionResult = _tryCollectionReasoning(objective);
    if (collectionResult != null) {
      return ReasoningReady(semanticApp: collectionResult);
    }

    // Capability shells (timing/calc/weather/news) — not domain factories.
    // Without this, stopwatch/calculator falsely require an AI provider on device.
    final shell = _tryCapabilityShellReasoning(objective);
    if (shell != null) {
      return ReasoningReady(semanticApp: shell);
    }

    return const ReasoningProviderRequired();
  }

  /// Build a capability-declared SemanticApp for utility/network shells.
  ///
  /// Uses [IntentPreservationValidator] purpose vocabulary (validation-side
  /// linguistics) to select capability IDs. CreationEngine + interface
  /// factories materialize the UI — no named application templates here.
  SemanticApp? _tryCapabilityShellReasoning(String objective) {
    final purpose = const IntentPreservationValidator().purposeFromPrompt(
      objective,
    );
    final lower = objective.toLowerCase();
    final caps = <String>{};
    final archetypes = <String>['utility'];
    final tags = <String>['utility', 'capability-shell'];

    switch (purpose) {
      case IntentPurpose.timing:
        caps.addAll({
          AppCapabilityIds.timers,
          AppCapabilityIds.input,
          AppCapabilityIds.resultDisplay,
        });
      case IntentPurpose.calculation:
        caps.addAll({
          AppCapabilityIds.calculation,
          AppCapabilityIds.input,
          AppCapabilityIds.resultDisplay,
        });
        if (lower.contains('scientific') ||
            lower.contains('trig') ||
            lower.contains('engineering')) {
          caps.add(AppCapabilityIds.scientificCalculation);
        }
      case IntentPurpose.weather:
        caps.addAll({
          AppCapabilityIds.weatherData,
          AppCapabilityIds.input,
          AppCapabilityIds.refresh,
          AppCapabilityIds.loadingState,
          AppCapabilityIds.errorState,
          AppCapabilityIds.resultDisplay,
        });
        tags.add('weatherData');
      case IntentPurpose.news:
        caps.addAll({
          AppCapabilityIds.newsData,
          AppCapabilityIds.input,
          AppCapabilityIds.refresh,
          AppCapabilityIds.loadingState,
          AppCapabilityIds.errorState,
          AppCapabilityIds.resultDisplay,
        });
        tags.add('newsData');
      case IntentPurpose.networkReference:
        // Still escalate to model/knowledge when only generic network is asked —
        // avoid forcing a Wikipedia shell from this path.
        return null;
      case IntentPurpose.collection:
      case IntentPurpose.unknown:
        return null;
    }

    if (caps.isEmpty) return null;
    return SemanticApp(
      name: _deriveName(objective),
      purpose: objective,
      entities: const [],
      actions: const [],
      views: const [],
      archetypes: List<String>.from(archetypes),
      tags: List<String>.from(tags),
      requiredCapabilities: caps.toList(growable: false),
    );
  }

  /// Durable managed-record apps from structural noun lists (manage / bullets)
  /// or a single structural manager/tracker head noun.
  ///
  /// Multi-entity lists (≥2) remain preferred. Single-entity manager/tracker
  /// prompts (e.g. "task manager", "expense tracker") are handled here so
  /// device creation does not falsely require an AI provider. Vague prompts
  /// without a derivable entity still escalate (Stage 10 contract).
  SemanticApp? _tryManagedRecordsReasoning(String objective) {
    // Prefer the head noun of "... manager/tracker/planner/log" when present.
    // A trailing "with A and B" clause must not erase that primary record type
    // (and must not win via accidental substring matches like track⊂tracker).
    final head = _extractManagerEntity(objective);
    var entities = StructuralEntityExtractor.extract(objective);
    if (head != null) {
      final extras = [
        for (final e in entities)
          if (e.id != head.id) e,
      ];
      entities = [head, ...extras];
    } else if (entities.length < 2) {
      return null;
    }

    final semanticEntities = <SemanticEntity>[
      for (final e in entities)
        _entityFromStructural(e, objective: objective, peers: entities),
    ];
    final actions = <SemanticAction>[
      for (final e in entities) ..._crudActions(e),
    ];
    final views = <SemanticView>[
      for (var i = 0; i < entities.length; i++) ..._views(entities[i], i == 0),
    ];

    final caps = <String>{
      AppCapabilityIds.crud,
      AppCapabilityIds.collection,
      AppCapabilityIds.persistence,
      AppCapabilityIds.form,
      AppCapabilityIds.input,
      AppCapabilityIds.search,
    };
    final lower = objective.toLowerCase();
    if (lower.contains('filter')) caps.add(AppCapabilityIds.filter);
    if (lower.contains('sort')) caps.add(AppCapabilityIds.sort);

    return SemanticApp(
      name: _deriveName(objective),
      purpose: objective,
      entities: semanticEntities,
      actions: actions,
      views: views,
      archetypes: const ['collection', 'tracker'],
      tags: const ['collection', 'local', 'managed-records'],
      requiredCapabilities: caps.toList(growable: false),
    );
  }

  /// Simple "list of X" collection.
  SemanticApp? _tryCollectionReasoning(String objective) {
    final lower = objective.toLowerCase();

    if (!lower.contains('list') && !lower.contains('collection')) {
      return null;
    }

    final extracted = StructuralEntityExtractor.extract(objective);
    final entityName = extracted.isNotEmpty
        ? extracted.first.name
        : _extractEntityNameLegacy(objective);
    if (entityName == null) return null;
    if (_isTooGeneric(lower) && extracted.isEmpty) return null;

    final entity = StructuralEntityName(
      id: _toEntityId(entityName),
      name: entityName,
    );

    return SemanticApp(
      name: _deriveName(objective),
      purpose: objective,
      entities: [
        _entityFromStructural(entity, objective: objective, peers: [entity]),
      ],
      actions: _crudActions(entity),
      views: _views(entity, true),
      archetypes: const ['collection'],
      tags: const ['list', 'collection'],
      requiredCapabilities: const [
        AppCapabilityIds.crud,
        AppCapabilityIds.collection,
        AppCapabilityIds.persistence,
        AppCapabilityIds.form,
        AppCapabilityIds.input,
      ],
    );
  }

  SemanticEntity _entityFromStructural(
    StructuralEntityName e, {
    required String objective,
    required List<StructuralEntityName> peers,
  }) {
    return SemanticEntity(
      id: e.id,
      name: e.name,
      displayField: 'name',
      fields: StructuralFieldInferrer.fieldsFor(
        e,
        objective: objective,
        peers: peers,
      ),
    );
  }

  List<SemanticAction> _crudActions(StructuralEntityName e) => [
    SemanticAction(
      id: 'create_${e.id}',
      name: 'Add ${e.name}',
      targetEntityId: e.id,
      actionType: BlueprintActionType.create,
    ),
    SemanticAction(
      id: 'update_${e.id}',
      name: 'Edit ${e.name}',
      targetEntityId: e.id,
      actionType: BlueprintActionType.update,
    ),
    SemanticAction(
      id: 'delete_${e.id}',
      name: 'Delete ${e.name}',
      targetEntityId: e.id,
      actionType: BlueprintActionType.delete,
    ),
  ];

  List<SemanticView> _views(StructuralEntityName e, bool isDefault) => [
    SemanticView(
      id: '${e.id}_list',
      name: '${e.name} List',
      purpose: 'list',
      sourceEntityId: e.id,
      viewType: BlueprintViewType.list,
      isDefault: isDefault,
    ),
    SemanticView(
      id: '${e.id}_form',
      name: '${e.name} Form',
      purpose: 'form',
      sourceEntityId: e.id,
      viewType: BlueprintViewType.form,
    ),
  ];

  bool _isTooGeneric(String lower) {
    const genericPhrases = [
      'create an app',
      'make me something',
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

  String? _extractEntityNameLegacy(String objective) {
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
        if (stopWords.contains(name.toLowerCase())) continue;
        return name[0].toUpperCase() + name.substring(1);
      }
    }
    return null;
  }

  /// Head noun before manager/tracker/planner/log — structural, not domain-coded.
  StructuralEntityName? _extractManagerEntity(String objective) {
    if (!StructuralEntityExtractor.looksLikeManagedRecords(objective)) {
      return null;
    }
    final m = RegExp(
      r'\b(?:a|an|the|my|our|your|professional|personal|simple)?\s*'
      r'([A-Za-z][\w-]{1,40}(?:\s+[A-Za-z][\w-]{1,40}){0,3})\s+'
      r'(?:manager|tracker|planner|log)\b',
      caseSensitive: false,
    ).firstMatch(objective);
    if (m == null) return null;
    final raw = m.group(1)!.trim();
    const stop = {
      'a',
      'an',
      'the',
      'my',
      'our',
      'your',
      'professional',
      'personal',
      'simple',
      'app',
      'application',
    };
    final words = raw
        .split(RegExp(r'\s+'))
        .where((w) => !stop.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return null;
    final name = words.map((w) {
      final lower = w.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
    if (name.length < 2) return null;
    return StructuralEntityName(id: _toEntityId(name), name: name);
  }

  String _deriveName(String objective) {
    final firstLine = objective.split(RegExp(r'[\r\n]+')).first.trim();
    if (firstLine.isEmpty) return 'Untitled';
    final cleaned = firstLine
        .replaceAll(
          RegExp(
            r'^(create|build|make)\s+(a|an|me\s+a|me\s+an)?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final base = cleaned.isEmpty ? firstLine : cleaned;
    final clipped = base.length > 48 ? '${base.substring(0, 45)}…' : base;
    return clipped[0].toUpperCase() + clipped.substring(1);
  }

  String _toEntityId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
