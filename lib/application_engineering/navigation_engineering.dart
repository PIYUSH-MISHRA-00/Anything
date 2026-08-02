/// Navigation Engineering — extends V2's NavigationGraph with modal/deep-
/// link/history/recovery decisions, grounded in the real, already-tested
/// ExperienceRouter behavior (rejects unknown screen IDs, maintains a
/// real history stack — see stage11_security_certification_test.dart
/// "Navigation Escape").
library;

import '../software_architect/architecture_types.dart';
import '../software_architect/confidence.dart';
import 'engineering_context.dart';
import 'engineering_types.dart';

class NavigationEngineeringResult {
  final List<NavigationEdge> modalEdges;
  final List<String> deepLinkableScreenIds;
  final EngineeringDecision historyDecision;
  final EngineeringDecision recoveryDecision;
  final EngineeringDecision decision;

  const NavigationEngineeringResult({
    this.modalEdges = const [],
    this.deepLinkableScreenIds = const [],
    required this.historyDecision,
    required this.recoveryDecision,
    required this.decision,
  });
}

class NavigationEngineering {
  const NavigationEngineering();

  NavigationEngineeringResult plan(EngineeringContext context) {
    final nav = context.architecture.navigation;
    final modalEdges = nav.edges.where((e) => e.isModal).toList();
    // Every screen is a valid deep-link target — ExperienceRouter
    // validates any target against the declared screen list and rejects
    // anything else (real, tested behavior), so declaring "all screens
    // deep-linkable" costs nothing extra and needs no new mechanism.
    final deepLinkable = List<String>.from(nav.screenIds);

    return NavigationEngineeringResult(
      modalEdges: modalEdges,
      deepLinkableScreenIds: deepLinkable,
      historyDecision: EngineeringDecision(
        id: 'navigation:history',
        category: EngineeringDecisionCategory.navigation,
        subjectId: 'history',
        decision: 'Back-stack history is maintained by ExperienceRouter',
        rationale:
            'ExperienceRouter already maintains a real navigation history '
            'and seeds it on first navigation (fixed in M1 — see '
            'docs/progress/V2_STAGE_11.md); no new history mechanism is '
            'introduced here.',
        confidence: Confidence.full,
      ),
      recoveryDecision: EngineeringDecision(
        id: 'navigation:recovery',
        category: EngineeringDecisionCategory.navigation,
        subjectId: 'recovery',
        decision: 'Invalid navigation targets are rejected, not crashed',
        rationale:
            'ExperienceRouter validates every navigation target against '
            'the declared screen set and silently rejects anything else '
            '(including path-traversal-shaped and "hostRoot" targets — '
            'verified in test/stage11/stage11_security_certification_test.dart '
            '"Navigation Escape"); recovery is "stay on the current '
            'screen," which is already the real, tested behavior.',
        confidence: Confidence.full,
      ),
      decision: EngineeringDecision(
        id: 'navigation:overview',
        category: EngineeringDecisionCategory.navigation,
        subjectId: 'navigation',
        decision:
            '${modalEdges.length} modal transition(s), '
            '${deepLinkable.length} deep-linkable screen(s)',
        rationale: 'Derived directly from the approved NavigationGraph.',
        confidence: nav.decision.confidence,
      ),
    );
  }
}
