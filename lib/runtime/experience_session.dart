/// Experience Session — represents a running Experience instance.
library;

import '../creation/experience_package.dart';

/// Session lifecycle status.
enum SessionStatus { initializing, running, paused, failed, closing, closed }

/// A running Experience session.
class ExperienceSession {
  final String id;
  final String experienceId;
  final ExperiencePackage package;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime lastActiveAt;
  final String? error;

  const ExperienceSession({
    required this.id,
    required this.experienceId,
    required this.package,
    required this.status,
    required this.startedAt,
    required this.lastActiveAt,
    this.error,
  });

  /// Create an error session.
  factory ExperienceSession.error({
    required String experienceId,
    required String error,
  }) {
    return ExperienceSession(
      id: 'error-${DateTime.now().millisecondsSinceEpoch}',
      experienceId: experienceId,
      package: ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: experienceId,
          name: 'Error',
          description: 'Failed to load',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        interface: const InterfaceDefinition(),
        behavior: const BehaviorGraph(),
        state: const StateSchema(),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime.now(),
        ),
      ),
      status: SessionStatus.failed,
      startedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      error: error,
    );
  }

  ExperienceSession copyWith({
    SessionStatus? status,
    DateTime? lastActiveAt,
    String? error,
  }) {
    return ExperienceSession(
      id: id,
      experienceId: experienceId,
      package: package,
      status: status ?? this.status,
      startedAt: startedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      error: error ?? this.error,
    );
  }

  bool get isRunning => status == SessionStatus.running;
  bool get isPaused => status == SessionStatus.paused;
  bool get hasError => status == SessionStatus.failed;
}
