/// Solution Explorer — the top-level Multi-Solution Reasoning & Architecture
/// Selection orchestrator: Architecture Exploration (reusing the certified
/// ArchitecturePlanner + RefinementPlanner unchanged) -> Multi-Solution
/// Generation -> Tradeoff Analysis -> Solution Review -> Solution
/// Refinement -> Solution Selection.
library;

import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_planner.dart';
import '../software_architect/architecture_review.dart' show RefinementOutcome;
import '../software_architect/architecture_types.dart'
    show OfflineCapability, SyncStrategy;
import '../software_architect/refinement_planner.dart';
import '../synthesis/application_reasoner.dart';
import 'solution_comparison.dart';
import 'solution_decision.dart';
import 'solution_exploration_context.dart';
import 'solution_generator.dart';
import 'solution_history.dart';
import 'solution_refinement.dart';
import 'solution_scorer.dart';
import 'solution_selector.dart';
import 'solution_variation_types.dart';

class SolutionExplorer {
  final ArchitecturePlanner _architecturePlanner;
  final RefinementPlanner _refinementPlanner;
  final SolutionGenerator _generator;
  final SolutionScorer _scorer;
  final SolutionRefinement _refinement;
  final SolutionComparison _comparison;
  final SolutionSelector _selector;

  const SolutionExplorer({
    ArchitecturePlanner architecturePlanner = const ArchitecturePlanner(),
    RefinementPlanner refinementPlanner = const RefinementPlanner(),
    SolutionGenerator generator = const SolutionGenerator(),
    SolutionScorer scorer = const SolutionScorer(),
    SolutionRefinement refinement = const SolutionRefinement(),
    SolutionComparison comparison = const SolutionComparison(),
    SolutionSelector selector = const SolutionSelector(),
  }) : _architecturePlanner = architecturePlanner,
       _refinementPlanner = refinementPlanner,
       _generator = generator,
       _scorer = scorer,
       _refinement = refinement,
       _comparison = comparison,
       _selector = selector;

  ({SolutionDecision? decision, SolutionHistory? history, String? error})
  explore({
    required SemanticApp app,
    required SolutionExplorationContext context,
  }) {
    // Architecture Exploration — reuses ASAE unchanged.
    final initial = _architecturePlanner.plan(app);
    final report = _refinementPlanner.refine(initial);
    if (report.outcome == RefinementOutcome.budgetExhausted &&
        report.finalReview.hasCriticalIssues) {
      return (
        decision: null,
        history: null,
        error:
            'Unable to produce a sound application design after refinement — '
            'please try rephrasing or simplifying the request.',
      );
    }
    final baseline = report.finalCandidate;

    // Multi-Solution Generation — never exactly one.
    final variations = _generateVariations(baseline);
    final candidates = variations
        .map(
          (v) => _generator.build(
            baseline: baseline,
            variation: v,
            context: context,
          ),
        )
        .toList();

    // Tradeoff Analysis + Solution Scoring.
    final scored = candidates
        .map(
          (c) => c.copyWith(
            score: _scorer.score(c),
            tradeoffs: _scorer.tradeoffs(c),
          ),
        )
        .toList();

    // Solution Review + Solution Refinement.
    final history = _refinement.refine(scored);
    if (history.outcome == SolutionRefinementOutcome.noViableSolution ||
        (history.outcome == SolutionRefinementOutcome.budgetExhausted &&
            history.finalReview.hasCriticalIssues)) {
      return (
        decision: null,
        history: history,
        error:
            'Unable to produce a sound solution after multi-solution review — '
            'please try rephrasing or simplifying the request.',
      );
    }

    // Solution Selection — never "first candidate wins."
    final comparisonResult = _comparison.compare(history.finalCandidates);
    final decision = _selector.select(
      history.finalCandidates,
      comparisonResult.graph,
    );

    return (decision: decision, history: history, error: null);
  }

  /// Always proposes at least two candidates (Balanced + Minimal); adds
  /// Flat Navigation when there are enough screens for topology to matter,
  /// and Offline First when the baseline architecture assumes network use.
  List<ArchitectureVariation> _generateVariations(
    ArchitectureCandidate baseline,
  ) {
    final baselineOffline = baseline.offline.capability;
    final baselineSync = baseline.synchronization.strategy;

    final variations = <ArchitectureVariation>[
      ArchitectureVariation(
        label: 'Balanced',
        navigationTopology: NavigationTopology.hierarchical,
        capabilityRichness: CapabilityRichness.full,
        offlineStrategy: baselineOffline,
        synchronizationStrategy: baselineSync,
        rationale:
            'The architecture as planned: full interaction richness, hierarchical navigation, '
            'and the offline posture derived from declared capabilities.',
      ),
      ArchitectureVariation(
        label: 'Minimal',
        navigationTopology: NavigationTopology.hierarchical,
        capabilityRichness: CapabilityRichness.minimal,
        offlineStrategy: baselineOffline,
        synchronizationStrategy: baselineSync,
        rationale:
            'A leaner first version: search/filter/sort deliberately deferred to reduce '
            'complexity and time-to-ship.',
      ),
    ];

    if (baseline.navigation.screenIds.length >= 3) {
      variations.add(
        ArchitectureVariation(
          label: 'Flat Navigation',
          navigationTopology: NavigationTopology.flat,
          capabilityRichness: CapabilityRichness.full,
          offlineStrategy: baselineOffline,
          synchronizationStrategy: baselineSync,
          rationale:
              'Every screen reachable directly from the entry screen — fewer navigation '
              'hops when there are only a handful of views.',
        ),
      );
    }

    if (baselineOffline != OfflineCapability.fullyOffline) {
      variations.add(
        ArchitectureVariation(
          label: 'Offline First',
          navigationTopology: NavigationTopology.hierarchical,
          capabilityRichness: CapabilityRichness.full,
          offlineStrategy: OfflineCapability.fullyOffline,
          synchronizationStrategy: SyncStrategy.none,
          rationale:
              'A more conservative, offline-first posture that treats network capabilities '
              'as best-effort enrichment rather than a hard dependency.',
        ),
      );
    }

    return variations;
  }
}
