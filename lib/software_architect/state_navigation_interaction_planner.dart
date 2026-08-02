/// State / Navigation / Interaction planners — derive real, structural
/// decisions from a SemanticApp's entities, views, and actions. None of
/// this reasons about *what* an entity/view/action is named; only about
/// its type/shape.
library;

import '../synthesis/app_blueprint.dart'
    show BlueprintViewType, BlueprintActionType;
import '../synthesis/application_reasoner.dart';
import 'architecture_types.dart';
import 'confidence.dart';

class StatePlanner {
  const StatePlanner();

  List<StateDecision> plan(SemanticApp app) {
    final decisions = <StateDecision>[];

    for (final entity in app.entities) {
      decisions.add(
        StateDecision(
          stateId: 'state:${entity.id}',
          kind: StateKind.reactive,
          decision: ArchitectureDecision(
            id: 'state:${entity.id}',
            category: ArchitectureDecisionCategory.state,
            subjectId: entity.id,
            decision: '${entity.name} list is reactive state',
            rationale:
                'Backed by ExperienceQueryController, which streams query '
                'results — every generated list view re-renders when the '
                'underlying entity data changes, regardless of domain.',
            confidence: Confidence.full,
          ),
        ),
      );
    }

    for (final derived in app.derivedValues) {
      decisions.add(
        StateDecision(
          stateId: 'state:derived:${derived.id}',
          kind: StateKind.computed,
          decision: ArchitectureDecision(
            id: 'state:derived:${derived.id}',
            category: ArchitectureDecisionCategory.state,
            subjectId: derived.id,
            decision: '${derived.name} is computed state',
            rationale:
                'Derived via a ${derived.operation.name} aggregate over '
                '${derived.sourceEntityId} — recomputed from source data, '
                'never stored independently.',
            confidence: Confidence.full,
          ),
        ),
      );
    }

    if (app.networkConfig != null) {
      decisions.add(
        StateDecision(
          stateId: 'state:network-cache',
          kind: StateKind.persistent,
          decision: ArchitectureDecision(
            id: 'state:network-cache',
            category: ArchitectureDecisionCategory.state,
            subjectId: 'network-cache',
            decision: 'Network-sourced data is cached persistently',
            rationale:
                'A declared network purpose (${app.networkConfig!.purpose}) '
                'implies the app should not lose fetched data across '
                'restarts.',
            confidence: const Confidence(
              score: 0.8,
              reason:
                  'Reasonable default for any network-backed app; not '
                  'independently confirmed for this specific request.',
              risk: RiskLevel.low,
            ),
          ),
        ),
      );
    }

    return decisions;
  }
}

class NavigationPlanner {
  const NavigationPlanner();

  NavigationGraph plan(SemanticApp app) {
    if (app.views.isEmpty) {
      return NavigationGraph(
        entryScreenId: 'home',
        screenIds: const ['home'],
        edges: const [],
        decision: const ArchitectureDecision(
          id: 'navigation:default',
          category: ArchitectureDecisionCategory.navigation,
          subjectId: 'home',
          decision: 'Single default screen',
          rationale:
              'No views declared; a single entry screen is the '
              'minimal valid navigation graph.',
          confidence: Confidence(
            score: 0.5,
            reason: 'No view information to plan real navigation from.',
            risk: RiskLevel.medium,
            missingKnowledge: ['at least one declared view'],
          ),
        ),
      );
    }

    final entry = app.views.firstWhere(
      (v) => v.isDefault,
      orElse: () => app.views.first,
    );
    final screenIds = app.views.map((v) => v.id).toList();
    final edges = <NavigationEdge>[];

    for (final list in app.views.where(
      (v) => v.viewType == BlueprintViewType.list,
    )) {
      final sameEntity = app.views.where(
        (v) => v.id != list.id && v.sourceEntityId == list.sourceEntityId,
      );
      for (final target in sameEntity) {
        final trigger = switch (target.viewType) {
          BlueprintViewType.form => 'add',
          BlueprintViewType.detail => 'select',
          _ => 'open',
        };
        edges.add(
          NavigationEdge(
            fromScreenId: list.id,
            toScreenId: target.id,
            trigger: trigger,
            isModal: target.viewType == BlueprintViewType.form,
          ),
        );
      }
    }

    for (final detail in app.views.where(
      (v) => v.viewType == BlueprintViewType.detail,
    )) {
      final editForm = app.views.where(
        (v) =>
            v.viewType == BlueprintViewType.form &&
            v.sourceEntityId == detail.sourceEntityId,
      );
      for (final form in editForm) {
        edges.add(
          NavigationEdge(
            fromScreenId: detail.id,
            toScreenId: form.id,
            trigger: 'edit',
            isModal: true,
          ),
        );
      }
    }

    return NavigationGraph(
      entryScreenId: entry.id,
      screenIds: screenIds,
      edges: edges,
      decision: ArchitectureDecision(
        id: 'navigation:graph',
        category: ArchitectureDecisionCategory.navigation,
        subjectId: entry.id,
        decision:
            '${screenIds.length} screen(s), ${edges.length} navigation edge(s)',
        rationale:
            'Edges inferred structurally from view type + shared '
            'sourceEntityId (list -> detail/form, detail -> edit form); '
            'entry screen is the declared default view.',
        confidence: Confidence(
          score: edges.isEmpty && app.views.length > 1 ? 0.4 : 0.9,
          reason: edges.isEmpty && app.views.length > 1
              ? 'Multiple views declared but none share a sourceEntityId — '
                    'no navigation relationship could be inferred between them.'
              : 'Navigation edges inferred directly from declared view '
                    'types and shared entities.',
          risk: edges.isEmpty && app.views.length > 1
              ? RiskLevel.medium
              : RiskLevel.none,
        ),
      ),
    );
  }
}

class InteractionPlanner {
  const InteractionPlanner();

  List<InteractionDecision> plan(SemanticApp app) {
    return app.entities.map((entity) {
      final actionsForEntity = app.actions.where(
        (a) => a.targetEntityId == entity.id,
      );
      final canCreate = actionsForEntity.any(
        (a) => a.actionType == BlueprintActionType.create,
      );
      final canUpdate = actionsForEntity.any(
        (a) =>
            a.actionType == BlueprintActionType.update ||
            a.actionType == BlueprintActionType.toggle ||
            a.actionType == BlueprintActionType.setValue,
      );
      final canDelete = actionsForEntity.any(
        (a) => a.actionType == BlueprintActionType.delete,
      );
      final hasListView = app.views.any(
        (v) =>
            v.sourceEntityId == entity.id &&
            v.viewType == BlueprintViewType.list,
      );

      return InteractionDecision(
        entityId: entity.id,
        canCreate: canCreate,
        canRead: true,
        canUpdate: canUpdate,
        canDelete: canDelete,
        supportsSearch: hasListView,
        supportsFilter: hasListView,
        supportsSort: hasListView,
        supportsPagination: hasListView,
        decision: ArchitectureDecision(
          id: 'interaction:${entity.id}',
          category: ArchitectureDecisionCategory.interaction,
          subjectId: entity.id,
          decision:
              'CRUD: create=$canCreate, update=$canUpdate, delete=$canDelete; '
              'list features: ${hasListView ? "search/filter/sort/pagination" : "none (no list view declared)"}',
          rationale:
              'CRUD flags derived from declared actions targeting this '
              'entity; list features derived from whether a list view '
              'exists for it (search/filter/sort/pagination are wired '
              'generically for every generated list, per '
              'ExperienceQueryController).',
          confidence: Confidence.full,
        ),
      );
    }).toList();
  }
}
