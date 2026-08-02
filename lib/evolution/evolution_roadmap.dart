/// EvolutionRoadmap — Current -> Immediate -> Next -> Later -> Future ->
/// Experimental. Every Experience Design Review approves now also owns a
/// roadmap: the real, reviewed, ranked proposals EvolutionPlanner placed
/// into each phase. Never auto-executed — a roadmap is a plan to show and
/// discuss, not a queue of pending changes.
library;

import 'evolution_candidate.dart';
import 'evolution_types.dart';

class EvolutionMilestone {
  final EvolutionPhase phase;
  final List<EvolutionProposal> proposals;

  const EvolutionMilestone({required this.phase, this.proposals = const []});
}

class EvolutionRoadmap {
  final String fingerprint;
  final List<EvolutionMilestone> milestones;
  final DateTime generatedAt;

  const EvolutionRoadmap({required this.fingerprint, required this.milestones, required this.generatedAt});

  List<EvolutionProposal> proposalsFor(EvolutionPhase phase) =>
      milestones.where((m) => m.phase == phase).expand((m) => m.proposals).toList();

  List<EvolutionProposal> get allProposals => milestones.expand((m) => m.proposals).toList();
}
