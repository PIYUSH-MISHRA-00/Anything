/// Binding Engineering — produces a typed BindingGraph using exactly the
/// stable identifier conventions the real, existing runtime already uses
/// (`form_<fieldId>` form state, `searchTerm` search state — see
/// lib/runtime/experience_renderer.dart) rather than inventing a parallel
/// naming scheme.
library;

import '../software_architect/architecture_candidate.dart';
import '../software_architect/confidence.dart';
import 'engineering_types.dart';

class BindingEngineering {
  const BindingEngineering();

  ({BindingGraph graph, EngineeringDecision decision}) plan(
    ArchitectureCandidate candidate,
  ) {
    final edges = <BindingEdge>[];

    for (final field in candidate.fields) {
      edges.add(
        BindingEdge(
          kind: BindingKind.viewToState,
          fromId: '${field.entityId}.${field.fieldId}',
          toId: 'form_${field.fieldId}',
        ),
      );
    }

    for (final interaction in candidate.interactions) {
      if (interaction.supportsSearch) {
        edges.add(
          BindingEdge(
            kind: BindingKind.viewToState,
            fromId: interaction.entityId,
            toId: 'searchTerm',
          ),
        );
      }
    }

    for (final entity in candidate.entities) {
      edges.add(
        BindingEdge(
          kind: BindingKind.stateToData,
          fromId: 'state:${entity.entityId}',
          toId: entity.entityId,
        ),
      );
      edges.add(
        BindingEdge(
          kind: BindingKind.dataToRuntime,
          fromId: entity.entityId,
          toId: 'ExperienceDataRuntime',
        ),
      );
    }

    for (final capability in candidate.capabilities) {
      edges.add(
        BindingEdge(
          kind: BindingKind.capabilityToRuntime,
          fromId: capability.capabilityId,
          toId: 'CapabilityPlatform',
        ),
      );
    }

    final graph = BindingGraph(edges: edges);
    final decision = EngineeringDecision(
      id: 'binding:graph',
      category: EngineeringDecisionCategory.binding,
      subjectId: 'bindings',
      decision: '${edges.length} typed binding edge(s)',
      rationale:
          'Every binding uses the same stable identifiers the real '
          'ExperienceRenderer/ExperienceFormController/ExperienceDataRuntime '
          'already bind by (form_<fieldId>, searchTerm, entity id) — no '
          'new runtime lookup mechanism, no string-keyed Map resolution '
          'introduced.',
      confidence: Confidence.full,
    );

    return (graph: graph, decision: decision);
  }
}
