/// Runtime contract for Anything v2.
///
/// The Runtime is the high-performance execution engine that hosts
/// experiences and manages the event bus. It executes plans produced
/// by the Kernel and provides the runtime environment for capabilities.
///
/// The Runtime does NOT depend on screen implementations or Flutter
/// widget code. It operates at the capability and event level.
library;

import 'dart:async';

import 'capability.dart';
import 'experience.dart';

/// The Runtime contract.
///
/// The Runtime is responsible for:
/// - Hosting active experiences
/// - Managing the event bus
/// - Coordinating capability execution
/// - Handling background tasks
/// - Providing the execution environment
abstract class AnythingRuntime {
  /// Start the runtime.
  Future<void> start();

  /// Stop the runtime gracefully.
  Future<void> stop();

  /// Whether the runtime is currently running.
  bool get isRunning;

  /// Execute a capability request.
  Future<CapabilityResult> executeCapability(CapabilityRequest request);

  /// Open an experience in the runtime.
  Future<void> openExperience(ExperienceId id);

  /// Close an experience.
  Future<void> closeExperience(ExperienceId id);

  /// Get the currently active experience.
  ExperienceId? get activeExperienceId;

  /// Subscribe to runtime events.
  Stream<RuntimeEvent> get events;
}

/// Events emitted by the Runtime.
sealed class RuntimeEvent {
  final DateTime timestamp;

  const RuntimeEvent({required this.timestamp});
}

/// A capability started executing.
class CapabilityExecutionStarted extends RuntimeEvent {
  final CapabilityId capabilityId;

  const CapabilityExecutionStarted({
    required this.capabilityId,
    required super.timestamp,
  });
}

/// A capability completed execution.
class CapabilityExecutionCompleted extends RuntimeEvent {
  final CapabilityId capabilityId;
  final CapabilityResult result;

  const CapabilityExecutionCompleted({
    required this.capabilityId,
    required this.result,
    required super.timestamp,
  });
}

/// An experience was opened.
class ExperienceOpened extends RuntimeEvent {
  final ExperienceId experienceId;

  const ExperienceOpened({
    required this.experienceId,
    required super.timestamp,
  });
}

/// An experience was closed.
class ExperienceClosed extends RuntimeEvent {
  final ExperienceId experienceId;

  const ExperienceClosed({
    required this.experienceId,
    required super.timestamp,
  });
}

/// Runtime encountered an error.
class RuntimeError extends RuntimeEvent {
  final String message;
  final Object? error;

  const RuntimeError({
    required this.message,
    this.error,
    required super.timestamp,
  });
}
