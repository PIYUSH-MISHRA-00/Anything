/// App Archetype — high-level classification of synthesized application structures.
///
/// Different user requests produce structurally different apps.
/// The archetype system allows the synthesis engine to recognize
/// structural classes and select appropriate patterns.
library;

/// High-level structural classification of synthesized applications.
enum AppArchetype {
  /// Pure utility — no persistence, no network (e.g. Calculator).
  utility,

  /// Manages a collection of records (e.g. Notes, Reading List).
  collection,

  /// Tracks periodic/daily state (e.g. Habit Tracker).
  tracker,

  /// Tasks with dates and status (e.g. Study Planner).
  planner,

  /// Summary-first with aggregation (e.g. Expense Tracker).
  dashboard,

  /// Reference information lookup (e.g. Weather Dashboard).
  reference,

  /// Multi-step process with flow (e.g. Workflow).
  workflow,

  /// Combines multiple archetypes (e.g. Expense = collection + dashboard).
  hybrid,
}

/// Domain classification for semantic understanding.
enum AppDomain {
  notes,
  habits,
  finances,
  education,
  reading,
  weather,
  health,
  productivity,
  reference,
  entertainment,
  custom,
}

/// Persistence classification for offline behavior.
enum OfflinePolicy {
  /// Works entirely without internet.
  full,

  /// Mostly offline, can enhance with network.
  partial,

  /// Requires network to function.
  networkRequired,
}
