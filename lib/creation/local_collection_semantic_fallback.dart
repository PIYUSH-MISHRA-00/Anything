/// Deterministic SemanticApp for local collection intents when model knowledge
/// acquisition cannot complete at plan time (IS-P10).
///
/// Capability-based generic records — never branches on product domain names.
library;

import '../kernel/understanding/intent_understanding.dart';
import '../synthesis/app_blueprint.dart';
import '../synthesis/application_reasoner.dart';
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

    return SemanticApp(
      name: name,
      purpose: purpose,
      entities: const [
        SemanticEntity(
          id: 'entry',
          name: 'Entry',
          displayField: 'title',
          fields: [
            SemanticField(
              id: 'title',
              name: 'Title',
              type: BlueprintFieldType.text,
              required: true,
            ),
            SemanticField(
              id: 'details',
              name: 'Details',
              type: BlueprintFieldType.multilineText,
            ),
            SemanticField(
              id: 'amount',
              name: 'Amount',
              type: BlueprintFieldType.decimal,
            ),
            SemanticField(
              id: 'category',
              name: 'Category',
              type: BlueprintFieldType.text,
            ),
          ],
        ),
      ],
      actions: const [
        SemanticAction(
          id: 'add_entry',
          name: 'Add Entry',
          targetEntityId: 'entry',
          actionType: BlueprintActionType.create,
        ),
        SemanticAction(
          id: 'edit_entry',
          name: 'Edit Entry',
          targetEntityId: 'entry',
          actionType: BlueprintActionType.update,
        ),
        SemanticAction(
          id: 'delete_entry',
          name: 'Delete Entry',
          targetEntityId: 'entry',
          actionType: BlueprintActionType.delete,
        ),
      ],
      views: const [
        SemanticView(
          id: 'entries_list',
          name: 'Entries',
          purpose: 'list',
          sourceEntityId: 'entry',
          viewType: BlueprintViewType.list,
          isDefault: true,
        ),
        SemanticView(
          id: 'entry_form',
          name: 'Entry Form',
          purpose: 'form',
          sourceEntityId: 'entry',
          viewType: BlueprintViewType.form,
        ),
      ],
      tags: const ['collection', 'local'],
      archetypes: const ['collection'],
      requiredCapabilities: const [
        AppCapabilityIds.crud,
        AppCapabilityIds.collection,
        AppCapabilityIds.persistence,
        AppCapabilityIds.form,
        AppCapabilityIds.input,
      ],
    );
  }
}
