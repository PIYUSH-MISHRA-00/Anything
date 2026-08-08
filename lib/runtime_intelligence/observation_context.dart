/// ObservationContext — identifies the runtime session ObservationEngine
/// is attached to. Carries no content, only structural identifiers.
library;

class ObservationContext {
  final String sessionId;
  final String? experienceId;
  final DateTime startedAt;

  const ObservationContext({
    required this.sessionId,
    this.experienceId,
    required this.startedAt,
  });
}
