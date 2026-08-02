/// Requirement Extractor — Intent (via reasoning's SemanticApp output) ->
/// RequirementGraph.
///
/// Structural by construction: every node/relation below is derived from
/// the *shape* of the SemanticApp (its entities, fields, actions, views,
/// capabilities) and from IntentUnderstanding's own structured signals
/// (networkNeed, creationNeed, modificationNeed) — never from a name or
/// domain check. A brand-new, never-seen domain produces exactly the same
/// kind of graph as a familiar one.
library;

import '../kernel/understanding/intent_understanding.dart';
import '../kernel/specification/experience_spec.dart' show NetworkNeed;
import '../synthesis/application_reasoner.dart';
import 'requirement_graph.dart';

class RequirementExtractor {
  const RequirementExtractor();

  RequirementGraph extract({
    required SemanticApp app,
    required IntentUnderstanding understanding,
  }) {
    final nodes = <RequirementNode>[];
    final relations = <RequirementRelation>[];

    for (final entity in app.entities) {
      nodes.add(
        RequirementNode(
          id: 'entity:${entity.id}',
          type: RequirementNodeType.entity,
          label: entity.name,
          description: entity.description,
          source: RequirementSource.explicit,
        ),
      );

      for (final field in entity.fields) {
        final fieldNodeId = 'field:${entity.id}.${field.id}';
        nodes.add(
          RequirementNode(
            id: fieldNodeId,
            type: RequirementNodeType.field,
            label: field.name,
            description: field.description,
            source: RequirementSource.explicit,
          ),
        );
        relations.add(
          RequirementRelation(
            fromId: fieldNodeId,
            toId: 'entity:${entity.id}',
            type: RequirementRelationType.belongsTo,
          ),
        );

        if (field.referenceEntityId != null) {
          nodes.add(
            RequirementNode(
              id: 'relationship:${entity.id}.${field.id}',
              type: RequirementNodeType.relationship,
              label:
                  '${entity.name}.${field.name} -> ${field.referenceEntityId}',
              source: RequirementSource.explicit,
            ),
          );
          relations.add(
            RequirementRelation(
              fromId: 'relationship:${entity.id}.${field.id}',
              toId: 'entity:${field.referenceEntityId}',
              type: RequirementRelationType.references,
            ),
          );
        }

        // Implicit requirement: every bounded field is also a constraint.
        if (field.required ||
            field.minimum != null ||
            field.maximum != null ||
            field.minLength != null ||
            field.maxLength != null ||
            field.allowedValues.isNotEmpty) {
          final constraintId = 'constraint:${entity.id}.${field.id}';
          nodes.add(
            RequirementNode(
              id: constraintId,
              type: RequirementNodeType.constraint,
              label: '${field.name} constraint',
              source: RequirementSource.inferred,
            ),
          );
          relations.add(
            RequirementRelation(
              fromId: constraintId,
              toId: fieldNodeId,
              type: RequirementRelationType.constrains,
            ),
          );
        }
      }

      // Implicit requirement: every entity needs persistent storage.
      final storageId = 'storage:${entity.id}';
      nodes.add(
        RequirementNode(
          id: storageId,
          type: RequirementNodeType.storage,
          label: '${entity.name} storage',
          source: RequirementSource.defaulted,
        ),
      );
      relations.add(
        RequirementRelation(
          fromId: storageId,
          toId: 'entity:${entity.id}',
          type: RequirementRelationType.implements,
        ),
      );

      // Implicit requirement: every list of entities is state.
      final stateId = 'state:${entity.id}';
      nodes.add(
        RequirementNode(
          id: stateId,
          type: RequirementNodeType.state,
          label: '${entity.name} list state',
          source: RequirementSource.defaulted,
        ),
      );
      relations.add(
        RequirementRelation(
          fromId: stateId,
          toId: 'entity:${entity.id}',
          type: RequirementRelationType.implements,
        ),
      );
    }

    for (final view in app.views) {
      final viewId = 'view:${view.id}';
      nodes.add(
        RequirementNode(
          id: viewId,
          type: RequirementNodeType.view,
          label: view.name,
          description: view.purpose,
          source: RequirementSource.explicit,
        ),
      );
      if (view.sourceEntityId != null) {
        relations.add(
          RequirementRelation(
            fromId: viewId,
            toId: 'entity:${view.sourceEntityId}',
            type: RequirementRelationType.references,
          ),
        );
      }
      // Every view implies navigation.
      final navId = 'navigation:${view.id}';
      nodes.add(
        RequirementNode(
          id: navId,
          type: RequirementNodeType.navigation,
          label: '${view.name} navigation entry',
          source: RequirementSource.defaulted,
        ),
      );
      relations.add(
        RequirementRelation(
          fromId: navId,
          toId: viewId,
          type: RequirementRelationType.implements,
        ),
      );
    }

    for (final action in app.actions) {
      final actionId = 'action:${action.id}';
      nodes.add(
        RequirementNode(
          id: actionId,
          type: RequirementNodeType.action,
          label: action.name,
          source: RequirementSource.explicit,
        ),
      );
      relations.add(
        RequirementRelation(
          fromId: actionId,
          toId: 'entity:${action.targetEntityId}',
          type: RequirementRelationType.references,
        ),
      );
    }

    for (final capabilityId in app.requiredCapabilities) {
      final nodeId = 'capability:$capabilityId';
      nodes.add(
        RequirementNode(
          id: nodeId,
          type: RequirementNodeType.capability,
          label: capabilityId,
          source: RequirementSource.explicit,
        ),
      );
    }
    if (app.networkConfig != null &&
        !nodes.any((n) => n.id == 'capability:http')) {
      nodes.add(
        const RequirementNode(
          id: 'capability:http',
          type: RequirementNodeType.capability,
          label: 'http',
          source: RequirementSource.inferred,
        ),
      );
    }

    final nonFunctional = _extractNonFunctional(app, understanding);

    return RequirementGraph(
      nodes: nodes,
      relations: relations,
      nonFunctional: nonFunctional,
    );
  }

  List<NonFunctionalRequirement> _extractNonFunctional(
    SemanticApp app,
    IntentUnderstanding understanding,
  ) {
    final result = <NonFunctionalRequirement>[];

    result.add(
      NonFunctionalRequirement(
        category: NonFunctionalCategory.offline,
        description: app.networkConfig == null
            ? 'No network dependency declared — app must work fully offline.'
            : 'Network is used for a declared purpose; core data must '
                  'remain usable offline.',
        source: RequirementSource.inferred,
      ),
    );

    result.add(
      const NonFunctionalRequirement(
        category: NonFunctionalCategory.security,
        description:
            'Generated app content is untrusted; all runtime/capability '
            'boundaries apply regardless of domain.',
        source: RequirementSource.defaulted,
      ),
    );

    result.add(
      const NonFunctionalRequirement(
        category: NonFunctionalCategory.futureModification,
        description:
            'The app must remain modifiable after creation without losing '
            'existing data (see ModificationEngine).',
        source: RequirementSource.defaulted,
      ),
    );

    result.add(
      NonFunctionalRequirement(
        category: NonFunctionalCategory.lifecycle,
        description:
            'Data must survive app restart (create -> persist -> reopen).',
        source: understanding.networkNeed == NetworkNeed.none
            ? RequirementSource.inferred
            : RequirementSource.explicit,
      ),
    );

    return result;
  }
}
