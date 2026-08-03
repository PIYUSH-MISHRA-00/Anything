/// Background Jobs Model — Implementation Milestone R8. Honestly
/// minimal: the only real, existing upstream signal for "does this
/// application need recurring background work" is
/// `SynchronizationDecision.strategy` (ArchitectureCandidate, Vision
/// Milestone V2) — `cacheFirst`/`networkFirst` imply a real background
/// sync need; `none`/`manualRefresh` do not. No scheduler/queue/worker
/// concept exists anywhere upstream to derive real retry/timeout
/// policies from, so those fields are deliberately NOT modeled here
/// rather than fabricated (see this milestone's Known Limitations).
library;

import '../software_architect/architecture_types.dart' show SyncStrategy;

class BackgroundJobsModel {
  /// Real, derived from `SynchronizationDecision.strategy` — never a
  /// guessed default.
  final bool requiresBackgroundSync;
  final SyncStrategy sourceStrategy;

  const BackgroundJobsModel({required this.requiresBackgroundSync, required this.sourceStrategy});
}
