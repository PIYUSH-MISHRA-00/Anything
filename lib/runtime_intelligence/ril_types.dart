/// Runtime Intelligence Layer (RIL) — Vision Milestone V8 — shared typed
/// vocabulary. Mirrors the established pattern from Evolution (V7) and
/// Design Review (V6): no Maps, no dynamic, no JSON blobs in the public
/// data model, every finding self-explaining via a real typed confidence.
library;

/// A structural graph-node kind shared by every RIL graph
/// (InteractionGraph/UsageGraph/CollaborationGraph/
/// ExperienceRelationshipGraph) — mirrors DependencyGraph (V4) /
/// EvolutionGraph (V7)'s node/edge shape exactly.
enum RilNodeKind { screen, entity, capability, experience }

/// The one shared node shape every RIL graph reuses — never a bespoke
/// node type per graph.
class RilNode {
  final String id;
  final RilNodeKind kind;
  final String label;

  const RilNode({required this.id, required this.kind, required this.label});
}

/// What kind of structural signal an [ObservationRecord] captures.
/// Deliberately never carries the underlying content — only the fact
/// that something structural happened, never what was typed/searched/
/// stored.
enum ObservationCategory {
  navigation,
  search,
  filter,
  capabilityUsage,
  offlineUsage,
  failure,
  performance,
  storageGrowth,
  memoryPressure,
  featureUsage,
}

enum PatternKind { sequentialWorkflow, frequentFeaturePair, frequentCapability, navigationLoop }

enum RecommendationKind {
  newFeature,
  optimization,
  automation,
  capability,
  workflow,
  shortcut,
  performanceImprovement,
  accessibilityImprovement,
  securityImprovement,
}

enum RecommendationDecisionKind { accepted, rejected, deferred }

enum ScheduleFrequency { once, daily, weekly, monthly, conditional }

enum AutomationConstraintKind { capabilityAvailability, networkAvailability, batteryNotLow }

enum AutomationStepEligibility { eligible, blockedMissingCapability, blockedConstraint }

enum ExperienceRelationshipKind { sharesCapability, sharesDataShape, complementaryWorkflow }

enum PredictionKind { nextAction, nextExperience, automationOpportunity }
