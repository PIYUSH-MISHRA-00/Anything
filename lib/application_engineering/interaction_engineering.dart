/// Interaction Engineering — extends V2's InteractionDecision with
/// selection/batch/undo-redo/confirmation/context-menu decisions.
///
/// Honesty discipline (matching CapabilityPlanner from V2): only patterns
/// actually implemented in ExperienceRenderer/BehaviorInterpreter today
/// are reported as available. Delete confirmation dialogs are real and
/// tested (stage11_user_path_certification_test.dart); batch
/// selection/undo/redo/context menus are not implemented yet and are
/// reported as such, never fabricated.
library;

import '../software_architect/confidence.dart';
import 'engineering_context.dart';
import 'engineering_types.dart';

enum InteractionPattern {
  singleSelection,
  batchSelection,
  confirmation,
  undo,
  redo,
  contextMenu,
  grouping,
}

class InteractionPatternDecision {
  final InteractionPattern pattern;
  final bool implemented;
  final EngineeringDecision decision;

  const InteractionPatternDecision({
    required this.pattern,
    required this.implemented,
    required this.decision,
  });
}

class InteractionEngineeringResult {
  final List<InteractionPatternDecision> patterns;
  const InteractionEngineeringResult({this.patterns = const []});
}

class InteractionEngineering {
  const InteractionEngineering();

  static const Map<InteractionPattern, ({bool implemented, String rationale})>
  _catalog = {
    InteractionPattern.singleSelection: (
      implemented: true,
      rationale:
          'Detail views select a single record by ID via referenceSelector/list navigation — real, existing.',
    ),
    InteractionPattern.confirmation: (
      implemented: true,
      rationale:
          'Delete actions show a confirmation dialog before executing (verified in stage11_user_path_certification_test.dart).',
    ),
    InteractionPattern.batchSelection: (
      implemented: false,
      rationale:
          'No multi-select/batch-action mechanism exists in ExperienceRenderer or component_registry today.',
    ),
    InteractionPattern.undo: (
      implemented: false,
      rationale:
          'No undo mechanism exists in BehaviorInterpreter today (mutations are immediate and final).',
    ),
    InteractionPattern.redo: (
      implemented: false,
      rationale:
          'No redo mechanism exists — depends on undo, which does not exist.',
    ),
    InteractionPattern.contextMenu: (
      implemented: false,
      rationale:
          'No context-menu component type is registered in RuntimeComponentRegistry.',
    ),
    InteractionPattern.grouping: (
      implemented: false,
      rationale:
          'DataQuery supports sort but not group-by; no grouped-list rendering exists.',
    ),
  };

  InteractionEngineeringResult plan(EngineeringContext context) {
    final patterns = _catalog.entries.map((entry) {
      final pattern = entry.key;
      final meta = entry.value;
      return InteractionPatternDecision(
        pattern: pattern,
        implemented: meta.implemented,
        decision: EngineeringDecision(
          id: 'interaction-pattern:${pattern.name}',
          category: EngineeringDecisionCategory.interaction,
          subjectId: pattern.name,
          decision: meta.implemented
              ? '${pattern.name} is available'
              : '${pattern.name} is not yet implemented',
          rationale: meta.rationale,
          confidence: Confidence(
            score: meta.implemented ? 1.0 : 0.0,
            reason: meta.implemented
                ? 'Matches real, tested runtime behavior.'
                : 'No implementation exists to plan against.',
            risk: meta.implemented ? RiskLevel.none : RiskLevel.low,
          ),
        ),
      );
    }).toList();

    return InteractionEngineeringResult(patterns: patterns);
  }
}
