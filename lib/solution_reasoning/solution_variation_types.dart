/// Multi-Solution Reasoning & Architecture Selection Engine (MSRA) —
/// typed variation axes. Every SolutionCandidate is the SAME real,
/// self-critiqued ArchitectureCandidate (from the existing, certified
/// ArchitecturePlanner/RefinementPlanner) with a small number of honest,
/// structurally-real overrides applied — never a fabricated alternative
/// implementation.
library;

import '../application_engineering/engineering_plan.dart';
import '../software_architect/architecture_types.dart' show OfflineCapability, SyncStrategy;

/// How screens link to each other. `hierarchical` (list -> detail/form,
/// the real edge shape NavigationPlanner already infers) is the default;
/// `flat` (every list view also gets a direct entry from the home/entry
/// screen) is a genuine, always-realizable alternative via the same
/// NavigationGraph/ExperienceRouter — no new runtime primitive.
enum NavigationTopology { hierarchical, flat }

/// Whether search/filter/sort are engineered for list views. `full`
/// matches what InteractionPlanner already detects as structurally
/// supportable; `minimal` is a genuine, lower-complexity alternative that
/// deliberately declines that support for a leaner first version.
enum CapabilityRichness { minimal, full }

class ArchitectureVariation {
  final String label;
  final NavigationTopology navigationTopology;
  final CapabilityRichness capabilityRichness;
  final OfflineCapability offlineStrategy;
  final SyncStrategy synchronizationStrategy;
  final String rationale;

  const ArchitectureVariation({
    required this.label,
    required this.navigationTopology,
    required this.capabilityRichness,
    required this.offlineStrategy,
    required this.synchronizationStrategy,
    required this.rationale,
  });
}

/// Wraps this candidate's own real, approved Application Engineering
/// Engine output (Vision Milestone V3/V4) — computed once per candidate,
/// reused (not recomputed) after selection.
class EngineeringVariation {
  final EngineeringPlan plan;
  const EngineeringVariation({required this.plan});
}

class CapabilityVariation {
  final CapabilityRichness richness;
  final String rationale;
  const CapabilityVariation({required this.richness, required this.rationale});
}

/// Storage is intentionally single-valued today: every entity with fields
/// gets real SQLite storage via the one production storage backend
/// (ExperienceDatabase); no second real storage engine exists to choose
/// between. Recorded honestly rather than fabricating a second option.
class StorageVariation {
  final String description;
  final String rationale;
  const StorageVariation({required this.description, required this.rationale});
}

class NavigationVariation {
  final NavigationTopology topology;
  final String rationale;
  const NavigationVariation({required this.topology, required this.rationale});
}

/// State is intentionally single-valued today: StatePlanner deterministically
/// assigns reactive/computed/persistent state from the app's own
/// entity/derived-value shape — this is a correct-by-construction decision,
/// not a preference a solution could meaningfully second-guess.
class StateVariation {
  final String description;
  final String rationale;
  const StateVariation({required this.description, required this.rationale});
}

class OfflineVariation {
  final OfflineCapability strategy;
  final String rationale;
  const OfflineVariation({required this.strategy, required this.rationale});
}

class SynchronizationVariation {
  final SyncStrategy strategy;
  final String rationale;
  const SynchronizationVariation({required this.strategy, required this.rationale});
}
