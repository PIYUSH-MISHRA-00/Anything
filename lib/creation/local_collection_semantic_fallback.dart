/// Deterministic SemanticApp for local collection intents when model knowledge
/// acquisition cannot complete at plan time (IS-P10 / P16).
///
/// Capability-based generic records — never branches on product domain names.
library;

import '../kernel/understanding/intent_understanding.dart';
import '../synthesis/app_blueprint.dart';
import '../synthesis/application_reasoner.dart';
import '../synthesis/structural_entity_extractor.dart';
import '../synthesis/structural_field_inferrer.dart';
import 'app_capabilities.dart';
import 'display_naming.dart';

/// Builds a durable collection SemanticApp the CreationEngine already knows
/// how to materialize into list/form/CRUD Experiences.
class LocalCollectionSemanticFallback {
  const LocalCollectionSemanticFallback();

  SemanticApp fromUnderstanding(IntentUnderstanding understanding) {
    final name = experienceDisplayName(
      generatedName: '',
      userIntent: understanding.objective,
    );
    final purpose = understanding.desiredOutcome.isNotEmpty
        ? understanding.desiredOutcome
        : understanding.objective;

    final extracted = StructuralEntityExtractor.extract(
      understanding.objective,
    );
    final entities = extracted.isNotEmpty
        ? extracted
        : [const StructuralEntityName(id: 'entry', name: 'Entry')];

    final objective = understanding.objective;
    return SemanticApp(
      name: name,
      purpose: purpose,
      entities: [
        for (final e in entities)
          SemanticEntity(
            id: e.id,
            name: e.name,
            displayField: 'name',
            fields: StructuralFieldInferrer.fieldsFor(
              e,
              objective: objective,
              peers: entities,
            ),
          ),
      ],
      actions: [
        for (final e in entities) ...[
          SemanticAction(
            id: 'add_${e.id}',
            name: 'Add ${e.name}',
            targetEntityId: e.id,
            actionType: BlueprintActionType.create,
          ),
          SemanticAction(
            id: 'edit_${e.id}',
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
        ],
      ],
      views: [
        for (var i = 0; i < entities.length; i++) ...[
          SemanticView(
            id: '${entities[i].id}_list',
            name: '${entities[i].name}s',
            purpose: 'list',
            sourceEntityId: entities[i].id,
            viewType: BlueprintViewType.list,
            isDefault: i == 0,
          ),
          SemanticView(
            id: '${entities[i].id}_form',
            name: '${entities[i].name} Form',
            purpose: 'form',
            sourceEntityId: entities[i].id,
            viewType: BlueprintViewType.form,
          ),
        ],
      ],
      tags: const ['collection', 'local'],
      archetypes: const ['collection'],
      requiredCapabilities: const [
        AppCapabilityIds.crud,
        AppCapabilityIds.collection,
        AppCapabilityIds.persistence,
        AppCapabilityIds.form,
        AppCapabilityIds.input,
        AppCapabilityIds.search,
      ],
    );
  }
}
