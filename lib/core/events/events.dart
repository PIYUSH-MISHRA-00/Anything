/// Typed event system for Anything v2.
///
/// All communication within Anything occurs through events.
/// This provides a minimal, typed event abstraction for
/// the local event bus.
library;

import 'dart:async';

/// Base class for all Anything events.
///
/// Events are immutable value objects that represent something
/// that happened within the system.
sealed class AnythingEvent {
  /// Unique identifier for this event.
  final String id;

  /// Timestamp when this event occurred.
  final DateTime timestamp;

  /// The source component that emitted this event.
  final String source;

  const AnythingEvent({
    required this.id,
    required this.timestamp,
    required this.source,
  });
}

// --- Intent Events ---

/// User submitted a new intent.
class IntentSubmitted extends AnythingEvent {
  final String rawInput;

  const IntentSubmitted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.rawInput,
  });
}

/// Intent analysis completed.
class IntentAnalyzed extends AnythingEvent {
  final String intentId;
  final String category;
  final double confidence;

  const IntentAnalyzed({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.intentId,
    required this.category,
    required this.confidence,
  });
}

// --- Experience Events ---

/// A new experience was created.
class ExperienceCreated extends AnythingEvent {
  final String experienceId;
  final String title;

  const ExperienceCreated({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
    required this.title,
  });
}

/// An experience was opened.
class ExperienceOpenedEvent extends AnythingEvent {
  final String experienceId;

  const ExperienceOpenedEvent({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
  });
}

/// An experience was updated.
class ExperienceUpdated extends AnythingEvent {
  final String experienceId;

  const ExperienceUpdated({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
  });
}

/// An experience was deleted.
class ExperienceDeleted extends AnythingEvent {
  final String experienceId;

  const ExperienceDeleted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.experienceId,
  });
}

// --- Execution Events ---

/// Execution of a plan started.
class ExecutionStarted extends AnythingEvent {
  final String planId;

  const ExecutionStarted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.planId,
  });
}

/// Execution of a plan completed.
class ExecutionCompleted extends AnythingEvent {
  final String planId;

  const ExecutionCompleted({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.planId,
  });
}

/// Execution of a plan failed.
class ExecutionFailed extends AnythingEvent {
  final String planId;
  final String error;

  const ExecutionFailed({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.planId,
    required this.error,
  });
}

// --- Knowledge Events ---

/// Knowledge was retrieved.
class KnowledgeRetrieved extends AnythingEvent {
  final String query;
  final int resultCount;

  const KnowledgeRetrieved({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.query,
    required this.resultCount,
  });
}

// --- Protection Events ---

/// Protection was applied to data.
class ProtectionApplied extends AnythingEvent {
  final String targetId;

  const ProtectionApplied({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.targetId,
  });
}

/// A simple local event bus for Anything.
///
/// Events are published and subscribed to within the same process.
/// This is not a distributed event system.
class EventBus {
  final _controllers = <Type, StreamController<AnythingEvent>>{};

  /// Subscribe to events of a specific type.
  Stream<T> on<T extends AnythingEvent>() {
    final controller = StreamController<T>.broadcast();
    _controllers[T] = controller as StreamController<AnythingEvent>;
    return controller.stream;
  }

  /// Publish an event.
  void publish(AnythingEvent event) {
    // Notify all listeners of the exact type
    final exactController = _controllers[event.runtimeType];
    exactController?.add(event);

    // Also notify listeners of the base AnythingEvent type
    final baseController = _controllers[AnythingEvent];
    baseController?.add(event);
  }

  /// Dispose all streams.
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
