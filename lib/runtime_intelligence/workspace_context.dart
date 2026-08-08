/// WorkspaceContext — aggregates across every Experience observed so
/// far, built at query time from ObservationMemory (there is no
/// persisted "workspace" concept in this codebase — this is honestly an
/// in-memory aggregation, not a stored entity).
library;

class WorkspaceContext {
  final List<String> experienceIds;
  final int totalSessions;

  const WorkspaceContext({
    required this.experienceIds,
    required this.totalSessions,
  });
}
