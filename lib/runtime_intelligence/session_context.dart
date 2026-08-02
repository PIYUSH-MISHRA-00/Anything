/// SessionContext — one observed runtime session's identity. Distinct
/// from `lib/runtime/runtime_context.dart`'s `RuntimeComponentContext`
/// (a single component's rendering context) — this is RIL's own,
/// higher-level session identity used to scope Observation/Learning.
library;

class SessionContext {
  final String sessionId;
  final String? experienceId;
  final DateTime startedAt;
  final DateTime? endedAt;

  const SessionContext({required this.sessionId, this.experienceId, required this.startedAt, this.endedAt});

  bool get isActive => endedAt == null;
}
