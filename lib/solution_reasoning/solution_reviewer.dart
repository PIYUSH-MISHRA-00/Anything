/// Solution Review — inspects the full candidate list for real,
/// structural defects: duplicate/equivalent/impossible/contradictory/
/// weak/over-engineered/incomplete solutions.
library;

import '../software_architect/architecture_types.dart' show NetworkMode, OfflineCapability;
import 'solution_types.dart';

enum SolutionIssueCategory { duplicate, equivalent, impossible, contradictory, weak, overEngineered, incomplete }

enum SolutionIssueSeverity { info, warning, critical }

class SolutionIssue {
  final SolutionIssueCategory category;
  final SolutionIssueSeverity severity;
  final String subjectId;
  final String message;
  final bool autoFixable;

  const SolutionIssue({
    required this.category,
    required this.severity,
    required this.subjectId,
    required this.message,
    this.autoFixable = false,
  });
}

class SolutionReviewResult {
  final int iteration;
  final List<SolutionIssue> issues;

  const SolutionReviewResult({required this.iteration, this.issues = const []});

  bool get passed => issues.isEmpty;
  bool get hasCriticalIssues => issues.any((i) => i.severity == SolutionIssueSeverity.critical);
  List<SolutionIssue> get autoFixableIssues => issues.where((i) => i.autoFixable).toList();
}

class SolutionReviewer {
  const SolutionReviewer({this.iteration = 0});

  final int iteration;

  static const Set<String> _networkOrientedCapabilities = {'http', 'ai', 'knowledge'};

  SolutionReviewResult review(List<SolutionCandidate> candidates) {
    final issues = <SolutionIssue>[];

    _checkDuplicates(candidates, issues);
    _checkEquivalents(candidates, issues);
    _checkImpossible(candidates, issues);
    _checkContradictory(candidates, issues);
    _checkWeak(candidates, issues);
    _checkOverEngineered(candidates, issues);
    _checkIncomplete(candidates, issues);

    return SolutionReviewResult(iteration: iteration, issues: issues);
  }

  void _checkDuplicates(List<SolutionCandidate> candidates, List<SolutionIssue> issues) {
    final seen = <String, SolutionCandidate>{};
    for (final c in candidates) {
      final v = c.architectureVariation;
      final key = '${v.navigationTopology.name}|${v.capabilityRichness.name}|${v.offlineStrategy.name}|${v.synchronizationStrategy.name}';
      final existing = seen[key];
      if (existing != null) {
        issues.add(
          SolutionIssue(
            category: SolutionIssueCategory.duplicate,
            severity: SolutionIssueSeverity.critical,
            subjectId: c.id,
            message: 'Solution "${c.label}" is structurally identical to ${existing.id}',
            autoFixable: true,
          ),
        );
      } else {
        seen[key] = c;
      }
    }
  }

  void _checkEquivalents(List<SolutionCandidate> candidates, List<SolutionIssue> issues) {
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final a = candidates[i];
        final b = candidates[j];
        if (a.score == null || b.score == null) continue;
        final diff = (a.score!.overall.score - b.score!.overall.score).abs();
        if (diff < 0.01 && a.id != b.id) {
          issues.add(
            SolutionIssue(
              category: SolutionIssueCategory.equivalent,
              severity: SolutionIssueSeverity.info,
              subjectId: '${a.id}~${b.id}',
              message: '"${a.label}" and "${b.label}" score equivalently despite different tradeoffs',
            ),
          );
        }
      }
    }
  }

  void _checkImpossible(List<SolutionCandidate> candidates, List<SolutionIssue> issues) {
    for (final c in candidates) {
      if (c.architectureVariation.offlineStrategy != OfflineCapability.onlineRequired) continue;
      final hasNetworkCapability = c.capabilities.any((cap) => _networkOrientedCapabilities.contains(cap.capabilityId));
      final hasNetworkSecurity = c.architecture.security.networkMode != NetworkMode.none;
      if (!hasNetworkCapability && !hasNetworkSecurity) {
        issues.add(
          SolutionIssue(
            category: SolutionIssueCategory.impossible,
            severity: SolutionIssueSeverity.critical,
            subjectId: c.id,
            message: '"${c.label}" requires network but no network-oriented capability was requested',
            autoFixable: true,
          ),
        );
      }
    }
  }

  void _checkContradictory(List<SolutionCandidate> candidates, List<SolutionIssue> issues) {
    for (final c in candidates) {
      if (c.capabilityVariation.richness.name != 'full') continue;
      if (c.architecture.interactions.isEmpty) continue;
      // With no views declared at all, NavigationPlanner falls back to a
      // single synthetic 'home' screen (decision id 'navigation:default')
      // and InteractionPlanner legitimately never sets any rich flag
      // regardless of richness — a structural reality, not a defect.
      if (c.architecture.navigation.decision.id == 'navigation:default') continue;
      final anyRich = c.architecture.interactions.any((i) => i.supportsSearch || i.supportsFilter || i.supportsSort);
      if (!anyRich) {
        issues.add(
          SolutionIssue(
            category: SolutionIssueCategory.contradictory,
            severity: SolutionIssueSeverity.critical,
            subjectId: c.id,
            message: '"${c.label}" claims full capability richness but no interaction supports search/filter/sort',
            autoFixable: true,
          ),
        );
      }
    }
  }

  void _checkWeak(List<SolutionCandidate> candidates, List<SolutionIssue> issues) {
    for (final c in candidates) {
      final score = c.score?.overall.score;
      if (score != null && score < 0.4) {
        issues.add(
          SolutionIssue(
            category: SolutionIssueCategory.weak,
            severity: SolutionIssueSeverity.warning,
            subjectId: c.id,
            message: '"${c.label}" scores ${score.toStringAsFixed(2)}, below the 0.4 acceptance threshold',
          ),
        );
      }
    }
  }

  void _checkOverEngineered(List<SolutionCandidate> candidates, List<SolutionIssue> issues) {
    final scored = candidates.where((c) => c.score != null).toList();
    if (scored.isEmpty) return;
    final bestScore = scored.map((c) => c.score!.overall.score).reduce((a, b) => a > b ? a : b);
    for (final c in scored) {
      final isHighComplexity = c.complexity.engineering.name == 'high';
      final isBest = c.score!.overall.score >= bestScore - 0.001;
      if (isHighComplexity && !isBest) {
        issues.add(
          SolutionIssue(
            category: SolutionIssueCategory.overEngineered,
            severity: SolutionIssueSeverity.warning,
            subjectId: c.id,
            message: '"${c.label}" carries high engineering complexity without the best overall score',
          ),
        );
      }
    }
  }

  void _checkIncomplete(List<SolutionCandidate> candidates, List<SolutionIssue> issues) {
    for (final c in candidates) {
      if (c.architecture.entities.isEmpty) {
        issues.add(
          SolutionIssue(
            category: SolutionIssueCategory.incomplete,
            severity: SolutionIssueSeverity.critical,
            subjectId: c.id,
            message: '"${c.label}" has no entities at all',
            autoFixable: true,
          ),
        );
      }
    }
  }
}
