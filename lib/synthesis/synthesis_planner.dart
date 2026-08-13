/// Synthesis Planner — converts IntentUnderstanding into an AppBlueprint.
///
/// The planner uses an ApplicationReasoner to get structured semantic
/// information, then converts it to an AppBlueprint using generic patterns.
///
/// This planner does NOT contain domain-specific knowledge.
/// Domain knowledge comes from the reasoner (model or deterministic).
library;

import '../kernel/understanding/intent_understanding.dart';
import 'app_archetype.dart';
import 'app_blueprint.dart';
import 'application_reasoner.dart';

/// Result of synthesis planning.
class SynthesisResult {
  const SynthesisResult({required this.blueprint, this.notes = const []});

  final AppBlueprint blueprint;
  final List<String> notes;
}

/// The Synthesis Planner converts IntentUnderstanding into AppBlueprints.
///
/// It delegates semantic reasoning to an ApplicationReasoner, then
/// converts the semantic result into a technology-independent AppBlueprint.
class SynthesisPlanner {
  final ApplicationReasoner _reasoner;

  SynthesisPlanner(this._reasoner);

  /// Plan an AppBlueprint from an IntentUnderstanding.
  ///
  /// The planner:
  /// 1. Asks the reasoner for structured semantic information
  /// 2. Converts semantic information to AppBlueprint
  /// 3. Validates and normalizes the blueprint
  /// 4. Returns the result
  Future<SynthesisResult> plan(ApplicationReasoningContext context) async {
    final result = await _reasoner.reason(context);

    return switch (result) {
      ReasoningReady() => SynthesisResult(
        blueprint: convertToBlueprint(result.semanticApp),
        notes: ['Reasoning completed by ${_reasoner.runtimeType}'],
      ),
      ReasoningClarificationRequired() => SynthesisResult(
        blueprint: _createMinimalBlueprint(context.understanding),
        notes: ['Clarification needed: ${result.question}'],
      ),
      ReasoningProviderRequired() => SynthesisResult(
        blueprint: _createMinimalBlueprint(context.understanding),
        notes: ['Provider required for complex reasoning'],
      ),
      ReasoningKnowledgeRequired() => SynthesisResult(
        blueprint: _createMinimalBlueprint(context.understanding),
        notes: [
          'External knowledge needed: ${result.requirements.map((r) => r.purpose).join(", ")}',
        ],
      ),
      ReasoningFailed() => SynthesisResult(
        blueprint: _createMinimalBlueprint(context.understanding),
        notes: ['Reasoning failed: ${result.error}'],
      ),
      ReasoningUnsupported() => SynthesisResult(
        blueprint: _createMinimalBlueprint(context.understanding),
        notes: ['Unsupported: ${result.reason}'],
      ),
    };
  }

  /// Convert a SemanticApp to an AppBlueprint.
  ///
  /// This is the core conversion from semantic domain to technology-independent
  /// blueprint. Used by the Kernel after reasoning completes.
  AppBlueprint convertToBlueprint(SemanticApp semantic) {
    final entities = semantic.entities.map((se) {
      return BlueprintEntity(
        id: se.id,
        name: se.name,
        description: se.description,
        fields: se.fields.map(_convertField).toList(),
        displayField: se.displayField,
      );
    }).toList();

    final views = semantic.views.map((sv) {
      return BlueprintView(
        id: sv.id,
        name: sv.name,
        purpose: sv.purpose,
        sourceEntityId: sv.sourceEntityId,
        viewType: sv.viewType,
        sections: sv.sections.map(_convertSection).toList(),
        isDefault: sv.isDefault,
      );
    }).toList();

    final actions = semantic.actions.map((sa) {
      return BlueprintAction(
        id: sa.id,
        name: sa.name,
        targetEntityId: sa.targetEntityId,
        actionType: sa.actionType,
        fields: sa.fields,
        derivedEffect: sa.derivedEffect,
      );
    }).toList();

    // Completeness guarantee: every entity must be user-creatable. Otherwise a
    // required reference to it (e.g. a booking's train_id / passenger_id) is a
    // dead end — the dropdown has nothing to select and the record can never be
    // created. If the model modelled an entity but gave it no create action
    // (it did this for Train/Passenger in a booking app), synthesize one plus a
    // form view so the entity gets an "Add" surface. Purely additive: entities
    // that already have a create action are untouched.
    final creatable = actions
        .where((a) => a.actionType == BlueprintActionType.create)
        .map((a) => a.targetEntityId)
        .toSet();
    for (final e in entities) {
      if (creatable.contains(e.id)) continue;
      actions.add(
        BlueprintAction(
          id: 'create_${e.id}',
          name: 'Add ${e.name}',
          targetEntityId: e.id,
          actionType: BlueprintActionType.create,
        ),
      );
      // A LIST view gives the entity a navigable tab whose "Add" button reaches
      // the create action. Without it the create action has no reachable
      // surface (this run had no Train/Passenger tab, so their Add was
      // unreachable and the booking's required references stayed a dead end).
      final hasList = views.any(
        (v) =>
            v.sourceEntityId == e.id && v.viewType == BlueprintViewType.list,
      );
      if (!hasList) {
        views.add(
          BlueprintView(
            id: '${e.id}_list',
            name: '${e.name} List',
            purpose: 'All ${e.name}',
            sourceEntityId: e.id,
            viewType: BlueprintViewType.list,
          ),
        );
      }
      final hasForm = views.any(
        (v) =>
            v.sourceEntityId == e.id && v.viewType == BlueprintViewType.form,
      );
      if (!hasForm) {
        views.add(
          BlueprintView(
            id: '${e.id}_form',
            name: '${e.name} Form',
            purpose: 'Add ${e.name}',
            sourceEntityId: e.id,
            viewType: BlueprintViewType.form,
          ),
        );
      }
    }

    final derivedValues = semantic.derivedValues.map((sdv) {
      return BlueprintDerivedValue(
        id: sdv.id,
        name: sdv.name,
        sourceEntityId: sdv.sourceEntityId,
        operation: sdv.operation,
        fieldId: sdv.fieldId,
        description: sdv.description,
      );
    }).toList();

    // Derive archetypes from semantic information
    final archetypes = _deriveArchetypes(semantic);

    return AppBlueprint(
      id: _stableBlueprintId(semantic.name),
      name: semantic.name,
      description: semantic.purpose,
      archetypes: archetypes,
      tags: semantic.tags,
      entities: entities,
      views: views,
      actions: actions,
      derivedValues: derivedValues,
      offlinePolicy: _deriveOfflinePolicy(semantic),
      requiredCapabilities: semantic.requiredCapabilities,
      networkConfig: semantic.networkConfig,
    );
  }

  BlueprintField _convertField(SemanticField sf) {
    return BlueprintField(
      id: sf.id,
      name: sf.name,
      type: sf.type,
      required: sf.required,
      defaultValue: sf.defaultValue,
      minimum: sf.minimum,
      maximum: sf.maximum,
      minLength: sf.minLength,
      maxLength: sf.maxLength,
      allowedValues: sf.allowedValues,
      referenceEntityId: sf.referenceEntityId,
      description: sf.description,
    );
  }

  BlueprintViewSection _convertSection(SemanticViewSection svs) {
    return BlueprintViewSection(
      id: svs.id,
      purpose: svs.purpose,
      sourceEntityId: svs.sourceEntityId,
      filter: svs.filter,
      limit: svs.limit,
      sectionType: svs.sectionType,
    );
  }

  /// Derive archetypes from semantic structure (not domain keywords).
  List<AppArchetype> _deriveArchetypes(SemanticApp semantic) {
    final archetypes = <AppArchetype>{};

    // Use explicitly provided archetypes if available
    for (final archName in semantic.archetypes) {
      final match = AppArchetype.values.where((a) => a.name == archName);
      if (match.isNotEmpty) archetypes.add(match.first);
    }

    // If no archetypes provided, derive from structure
    if (archetypes.isEmpty) {
      // Has entities with CRUD actions -> collection
      if (semantic.entities.isNotEmpty &&
          semantic.actions.any(
            (a) => a.actionType == BlueprintActionType.create,
          )) {
        archetypes.add(AppArchetype.collection);
      }

      // Has date-based completion events -> tracker
      if (semantic.entities.any(
        (e) => e.fields.any(
          (f) =>
              f.type == BlueprintFieldType.date &&
              f.name.toLowerCase().contains('complet'),
        ),
      )) {
        archetypes.add(AppArchetype.tracker);
      }

      // Has due dates/status -> planner
      if (semantic.entities.any(
        (e) => e.fields.any(
          (f) =>
              f.name.toLowerCase().contains('due') ||
              f.name.toLowerCase().contains('status'),
        ),
      )) {
        archetypes.add(AppArchetype.planner);
      }

      // Has summary/aggregate views -> dashboard
      if (semantic.views.any(
        (v) => v.viewType == BlueprintViewType.dashboard,
      )) {
        archetypes.add(AppArchetype.dashboard);
      }

      // Has network config -> reference
      if (semantic.networkConfig != null) {
        archetypes.add(AppArchetype.reference);
      }

      // Fallback
      if (archetypes.isEmpty) {
        archetypes.add(AppArchetype.collection);
      }
    }

    return archetypes.toList();
  }

  OfflinePolicy _deriveOfflinePolicy(SemanticApp semantic) {
    if (semantic.networkConfig != null) {
      return OfflinePolicy.networkRequired;
    }
    return OfflinePolicy.full;
  }

  String _stableBlueprintId(String name) {
    final sanitized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'bp_$sanitized';
  }

  AppBlueprint _createMinimalBlueprint(IntentUnderstanding understanding) {
    return AppBlueprint(
      id: 'bp_${DateTime.now().millisecondsSinceEpoch}',
      name: understanding.objective,
      description: understanding.objective,
      archetypes: [AppArchetype.collection],
      offlinePolicy: OfflinePolicy.full,
    );
  }
}
