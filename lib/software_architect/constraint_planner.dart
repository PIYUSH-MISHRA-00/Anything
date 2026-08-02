/// Constraint Planner — checks a RequirementGraph against Anything's real
/// trusted platform limits (RuntimeSecurityLimits /
/// RuntimeComponentRegistry) before any architecture is even planned, so
/// an oversized/pathological request is flagged at the earliest possible
/// stage rather than only failing much later at package validation.
library;

import '../runtime/component_registry.dart';
import '../security/runtime_security_limits.dart';
import 'confidence.dart';
import 'requirement_graph.dart';

class ConstraintPlanner {
  const ConstraintPlanner();

  List<ArchitectureDecision> plan(RequirementGraph graph) {
    final decisions = <ArchitectureDecision>[];
    final entityCount = graph.nodesOfType(RequirementNodeType.entity).length;
    final viewCount = graph.nodesOfType(RequirementNodeType.view).length;
    final capabilityCount = graph
        .nodesOfType(RequirementNodeType.capability)
        .length;

    decisions.add(
      ArchitectureDecision(
        id: 'constraint:screen-count',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'screens',
        decision: viewCount <= RuntimeSecurityLimits.maxScreensPerPackage
            ? 'Within trusted screen budget'
            : 'Exceeds trusted screen budget',
        rationale:
            '$viewCount view(s) requested; trusted maximum is '
            '${RuntimeSecurityLimits.maxScreensPerPackage} '
            '(RuntimeSecurityLimits.maxScreensPerPackage).',
        confidence: Confidence(
          score: viewCount <= RuntimeSecurityLimits.maxScreensPerPackage
              ? 1.0
              : 0.0,
          reason: 'Directly computed from a fixed platform limit.',
          risk: viewCount <= RuntimeSecurityLimits.maxScreensPerPackage
              ? RiskLevel.none
              : RiskLevel.high,
        ),
      ),
    );

    decisions.add(
      ArchitectureDecision(
        id: 'constraint:entity-count',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'entities',
        decision: 'Entity count is $entityCount',
        rationale:
            'No dedicated entity-count platform limit exists; component '
            'and screen budgets (RuntimeSecurityLimits) bound the '
            'generated UI regardless of entity count.',
        confidence: const Confidence(
          score: 1.0,
          reason: 'Directly computed from the requirement graph.',
        ),
      ),
    );

    decisions.add(
      ArchitectureDecision(
        id: 'constraint:component-depth',
        category: ArchitectureDecisionCategory.data,
        subjectId: 'component-tree',
        decision:
            'Generated component trees are bounded to depth '
            '${RuntimeComponentRegistry.maxDepth}',
        rationale:
            'ComponentTreeValidator enforces this at package-validation '
            'time regardless of what architecture is planned here — '
            'recorded as a known downstream constraint.',
        confidence: Confidence.full,
      ),
    );

    if (capabilityCount > 0) {
      decisions.add(
        ArchitectureDecision(
          id: 'constraint:capability-count',
          category: ArchitectureDecisionCategory.capability,
          subjectId: 'capabilities',
          decision:
              '$capabilityCount capabilit${capabilityCount == 1 ? 'y' : 'ies'} requested',
          rationale:
              'Each capability is independently declaration- and '
              'budget-enforced at runtime by CapabilityPlatform '
              '(see docs/security/CAPABILITY_SECURITY_MATRIX.md); no '
              'additional cross-capability limit applies here.',
          confidence: Confidence.full,
        ),
      );
    }

    return decisions;
  }
}
