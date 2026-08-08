/// EvolutionApprover — promotes reviewed, accepted candidates into
/// roadmap-eligible proposals. This is "approved to appear on the
/// roadmap", never "approved for automatic execution" — every
/// EvolutionProposal.approvedForExecution starts false and only ever
/// becomes true in response to a separate, explicit request (see
/// EvolutionExecutor). Rejected candidates never become proposals.
library;

import 'evolution_candidate.dart';
import 'evolution_types.dart';

class EvolutionApprover {
  const EvolutionApprover();

  List<EvolutionProposal> approveForRoadmap(
    List<EvolutionCandidate> candidates,
    List<EvolutionDecision> decisions,
  ) {
    final decisionsById = {for (final d in decisions) d.subjectId: d};
    return candidates
        .where(
          (c) => decisionsById[c.id]?.kind == EvolutionDecisionKind.accepted,
        )
        .map(
          (c) => EvolutionProposal(
            candidate: c,
            phase: EvolutionPhase.experimental,
            reviewDecision: decisionsById[c.id]!,
          ),
        )
        .toList();
  }
}
