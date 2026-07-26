/// Experience and Workspace identity types for Anything v2.
///
/// An [Experience] is a persistent, usable creation — something the user
/// can open, interact with, and return to. It may be as simple as a
/// generated UI view or as complex as a full application with state,
/// storage, and services.
///
/// A [Workspace] is the contextual working environment inside an
/// Experience — the active view, its state, and its current context.
library;

import 'capability.dart';
import 'intent.dart';

/// Unique identifier for an Experience.
typedef ExperienceId = String;

/// Unique identifier for a Workspace.
typedef WorkspaceId = String;

/// The runtime classification of an Experience.
enum ExperienceRuntimeType {
  /// A UI-only experience rendered from AUIL or similar schema.
  auil,

  /// A Flutter widget-based experience.
  flutter,

  /// A web-based experience (WebView or embedded browser).
  web,

  /// A hybrid experience combining multiple runtime types.
  hybrid,

  /// Runtime type not yet determined.
  unknown,
}

/// The current lifecycle state of an Experience.
enum ExperienceStatus {
  /// Being created by the Kernel.
  creating,

  /// Ready for use.
  active,

  /// Temporarily suspended (e.g., background).
  suspended,

  /// Archived but restorable.
  archived,

  /// Permanently deleted.
  deleted,
}

/// A persistent, usable creation within Anything.
///
/// Experiences survive after creation and can be reopened from the
/// user's library. They may contain UI artifacts, executable behavior,
/// local storage, backend requirements, and more.
///
/// This model is deliberately broad — it must support everything from
/// a simple generated chart to a full expense tracker application.
class Experience {
  /// Unique identifier.
  final ExperienceId id;

  /// Human-readable title.
  final String title;

  /// Optional description of what this experience provides.
  final String? description;

  /// The runtime type classification.
  final ExperienceRuntimeType runtimeCategory;

  /// Current lifecycle status.
  final ExperienceStatus status;

  /// The original intent that created this experience, if any.
  final IntentId? sourceIntentId;

  /// Runtime metadata (UI schema, executable config, etc.).
  final ExperienceMetadata metadata;

  /// Capabilities required by this experience.
  final List<CapabilityId> requiredCapabilities;

  /// Storage requirements for this experience.
  final ExperienceStorageRequirements storageRequirements;

  /// Network requirements for this experience.
  final ExperienceNetworkRequirements networkRequirements;

  /// Permissions required by this experience.
  final List<String> requiredPermissions;

  /// Version number (semantic versioning).
  final String version;

  /// Protection metadata (Kaalka encryption settings, etc.).
  final ProtectionMetadata? protection;

  /// When this experience was created.
  final DateTime createdAt;

  /// When this experience was last modified.
  final DateTime updatedAt;

  /// When this experience was last opened.
  final DateTime? lastOpenedAt;

  const Experience({
    required this.id,
    required this.title,
    this.description,
    required this.runtimeCategory,
    required this.status,
    this.sourceIntentId,
    required this.metadata,
    this.requiredCapabilities = const [],
    required this.storageRequirements,
    required this.networkRequirements,
    this.requiredPermissions = const [],
    this.version = '1.0.0',
    this.protection,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });

  Experience copyWith({
    ExperienceId? id,
    String? title,
    String? description,
    ExperienceRuntimeType? runtimeCategory,
    ExperienceStatus? status,
    IntentId? sourceIntentId,
    ExperienceMetadata? metadata,
    List<CapabilityId>? requiredCapabilities,
    ExperienceStorageRequirements? storageRequirements,
    ExperienceNetworkRequirements? networkRequirements,
    List<String>? requiredPermissions,
    String? version,
    ProtectionMetadata? protection,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
  }) {
    return Experience(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      runtimeCategory: runtimeCategory ?? this.runtimeCategory,
      status: status ?? this.status,
      sourceIntentId: sourceIntentId ?? this.sourceIntentId,
      metadata: metadata ?? this.metadata,
      requiredCapabilities: requiredCapabilities ?? this.requiredCapabilities,
      storageRequirements: storageRequirements ?? this.storageRequirements,
      networkRequirements: networkRequirements ?? this.networkRequirements,
      requiredPermissions: requiredPermissions ?? this.requiredPermissions,
      version: version ?? this.version,
      protection: protection ?? this.protection,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Experience &&
          id == other.id &&
          title == other.title &&
          runtimeCategory == other.runtimeCategory &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, title, runtimeCategory, status);
}

/// Runtime metadata for an Experience.
///
/// This is intentionally flexible — different runtime types
/// will store different metadata shapes.
class ExperienceMetadata {
  /// The runtime type determines how to interpret [data].
  final ExperienceRuntimeType runtimeCategory;

  /// Runtime-specific data (AUIL JSON, widget config, web URL, etc.).
  final Map<String, dynamic> data;

  const ExperienceMetadata({
    required this.runtimeCategory,
    this.data = const {},
  });
}

/// Storage requirements declared by an Experience.
class ExperienceStorageRequirements {
  /// Whether this experience needs local database access.
  final bool requiresLocalDatabase;

  /// Whether this experience needs file system access.
  final bool requiresFileSystem;

  /// Estimated storage size in bytes (for UI display).
  final int? estimatedSizeBytes;

  const ExperienceStorageRequirements({
    this.requiresLocalDatabase = false,
    this.requiresFileSystem = false,
    this.estimatedSizeBytes,
  });
}

/// Network requirements declared by an Experience.
class ExperienceNetworkRequirements {
  /// Whether this experience requires network access.
  final bool requiresNetwork;

  /// Specific endpoints this experience needs (for permission display).
  final List<String> endpoints;

  const ExperienceNetworkRequirements({
    this.requiresNetwork = false,
    this.endpoints = const [],
  });
}

/// Protection metadata for Kaalka encryption.
class ProtectionMetadata {
  /// Whether this experience's data is encrypted.
  final bool isEncrypted;

  /// Time seed mode: "live" uses current time, "custom" uses a fixed seed.
  final ProtectionTimeSeedMode timeSeedMode;

  /// Custom time seed values (hours, minutes, seconds) if timeSeedMode is custom.
  final ProtectionTimeSeed? customTimeSeed;

  const ProtectionMetadata({
    this.isEncrypted = false,
    this.timeSeedMode = ProtectionTimeSeedMode.live,
    this.customTimeSeed,
  });
}

/// Mode for Kaalka time seed generation.
enum ProtectionTimeSeedMode {
  /// Use current system time (default).
  live,

  /// Use a user-specified custom time.
  custom,
}

/// Custom time seed values for Kaalka encryption.
class ProtectionTimeSeed {
  final int hours;
  final int minutes;
  final int seconds;

  const ProtectionTimeSeed({
    required this.hours,
    required this.minutes,
    required this.seconds,
  });
}

/// A contextual working environment within an Experience.
class Workspace {
  /// Unique identifier.
  final WorkspaceId id;

  /// Parent experience ID.
  final ExperienceId experienceId;

  /// Human-readable workspace name.
  final String name;

  /// Current view state.
  final Map<String, dynamic> viewState;

  /// Active context (tools, data, etc.).
  final Map<String, dynamic> context;

  /// When this workspace was created.
  final DateTime createdAt;

  /// When this workspace was last modified.
  final DateTime updatedAt;

  const Workspace({
    required this.id,
    required this.experienceId,
    required this.name,
    this.viewState = const {},
    this.context = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Workspace copyWith({
    WorkspaceId? id,
    ExperienceId? experienceId,
    String? name,
    Map<String, dynamic>? viewState,
    Map<String, dynamic>? context,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id ?? this.id,
      experienceId: experienceId ?? this.experienceId,
      name: name ?? this.name,
      viewState: viewState ?? this.viewState,
      context: context ?? this.context,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
