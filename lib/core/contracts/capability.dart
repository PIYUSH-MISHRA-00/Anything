/// Capability abstraction for Anything v2.
///
/// A [Capability] is a composable ability available to the Kernel.
/// Capabilities are the building blocks that the Kernel uses to
/// fulfill intents — they can generate UI, execute logic, access
/// storage, or interact with external services.
///
/// Capabilities are registered with the Runtime and invoked
/// through [CapabilityRequest] objects. Results come back as
/// [CapabilityResult] objects.
library;

import 'dart:async';

import 'experience.dart';

/// Unique identifier for a Capability.
typedef CapabilityId = String;

/// The category of a capability.
enum CapabilityCategory {
  /// Generates or renders UI.
  ui,

  /// Executes computation or business logic.
  computation,

  /// Accesses or manages data/storage.
  data,

  /// Interacts with external services or APIs.
  integration,

  /// Provides security or protection features.
  security,

  /// Provides knowledge or information retrieval.
  knowledge,

  /// Manages voice or multimodal input/output.
  multimodal,
}

/// A composable ability available to the Kernel.
///
/// Capabilities are registered with the Runtime and can be
/// invoked to fulfill user intents. Each capability declares
/// its input/output types and required permissions.
abstract class Capability {
  /// Unique identifier for this capability.
  CapabilityId get id;

  /// Human-readable name.
  String get name;

  /// Description of what this capability does.
  String get description;

  /// The category of this capability.
  CapabilityCategory get category;

  /// Whether this capability is currently available.
  bool get isAvailable;

  /// Permissions required by this capability.
  List<String> get requiredPermissions;

  /// Execute this capability with the given request.
  Future<CapabilityResult> execute(CapabilityRequest request);
}

/// A request to invoke a capability.
class CapabilityRequest {
  /// The capability to invoke.
  final CapabilityId capabilityId;

  /// Input parameters for the capability.
  final Map<String, dynamic> parameters;

  /// The workspace context, if available.
  final WorkspaceId? workspaceId;

  /// The experience context, if available.
  final ExperienceId? experienceId;

  /// Timeout for this specific request.
  final Duration? timeout;

  const CapabilityRequest({
    required this.capabilityId,
    this.parameters = const {},
    this.workspaceId,
    this.experienceId,
    this.timeout,
  });
}

/// The result of a capability execution.
class CapabilityResult {
  /// Whether the execution was successful.
  final bool success;

  /// Output data from the capability.
  final Map<String, dynamic> data;

  /// Error message if the execution failed.
  final String? error;

  /// Metadata about the execution (timing, etc.).
  final Map<String, dynamic> metadata;

  const CapabilityResult({
    required this.success,
    this.data = const {},
    this.error,
    this.metadata = const {},
  });

  /// Creates a successful result.
  factory CapabilityResult.success({
    Map<String, dynamic> data = const {},
    Map<String, dynamic> metadata = const {},
  }) {
    return CapabilityResult(success: true, data: data, metadata: metadata);
  }

  /// Creates a failure result.
  factory CapabilityResult.failure(String error) {
    return CapabilityResult(success: false, error: error);
  }
}
