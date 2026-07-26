/// Canonical representation of a user's intent within Anything.
///
/// An [Intent] is the parsed, structured form of what the user wants.
/// It is produced by the composer from raw user input and drives all
/// downstream orchestration.
///
/// This type is implementation-independent — it does not reference
/// any specific AI provider, UI framework, or storage mechanism.
library;

import 'package:uuid/uuid.dart';

/// Unique identifier for an [Intent].
typedef IntentId = String;

/// Input modality for an intent.
enum InputModality { text, voice, mixed, image, file, url }

/// Status of an intent through its lifecycle.
enum IntentStatus {
  /// Intent has been composed but not yet submitted.
  draft,

  /// Intent has been submitted to the Kernel.
  submitted,

  /// Waiting for a provider to become available.
  awaitingProvider,

  /// Kernel has accepted the intent.
  accepted,

  /// Intent processing failed.
  failed,

  /// Intent was cancelled by the user.
  cancelled,
}

/// An attachment reference associated with an intent.
///
/// Attachments reference local resources without storing binary blobs
/// directly in the intent record.
class IntentAttachment {
  final String id;
  final String name;
  final AttachmentType type;
  final String localPath;
  final int? sizeBytes;
  final String? mimeType;
  final DateTime createdAt;

  const IntentAttachment({
    required this.id,
    required this.name,
    required this.type,
    required this.localPath,
    this.sizeBytes,
    this.mimeType,
    required this.createdAt,
  });

  factory IntentAttachment.create({
    required String name,
    required AttachmentType type,
    required String localPath,
    int? sizeBytes,
    String? mimeType,
  }) {
    return IntentAttachment(
      id: const Uuid().v4(),
      name: name,
      type: type,
      localPath: localPath,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      createdAt: DateTime.now(),
    );
  }
}

/// Types of attachments.
enum AttachmentType { file, image, document, audio, url }

/// Represents a parsed user intent.
///
/// Immutable value object. Created by the Intent Composer
/// and consumed by the Kernel.
class Intent {
  /// Unique identifier for this intent.
  final IntentId id;

  /// The user's raw expression (what they typed or spoke).
  final String expression;

  /// Structured description of what the user wants.
  final String description;

  /// Category classification (e.g., "productivity", "creation", "query").
  final String category;

  /// Suggested experience type for fulfilling this intent.
  final ExperienceType suggestedExperienceType;

  /// How the user provided this intent.
  final InputModality modality;

  /// Current status of this intent.
  final IntentStatus status;

  /// Attachments associated with this intent.
  final List<IntentAttachment> attachments;

  /// Context references (e.g., selected text, clipboard content).
  final Map<String, dynamic> context;

  /// Timestamp when this intent was created.
  final DateTime createdAt;

  /// Timestamp when this intent was last updated.
  final DateTime updatedAt;

  const Intent({
    required this.id,
    required this.expression,
    required this.description,
    required this.category,
    required this.suggestedExperienceType,
    required this.modality,
    required this.status,
    this.attachments = const [],
    this.context = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates an [Intent] with a generated UUID.
  factory Intent.create({
    required String expression,
    String? description,
    String? category,
    ExperienceType? suggestedExperienceType,
    InputModality modality = InputModality.text,
    List<IntentAttachment> attachments = const [],
    Map<String, dynamic> context = const {},
  }) {
    final now = DateTime.now();
    return Intent(
      id: const Uuid().v4(),
      expression: expression,
      description: description ?? expression,
      category: category ?? 'general',
      suggestedExperienceType:
          suggestedExperienceType ?? ExperienceType.unknown,
      modality: modality,
      status: IntentStatus.draft,
      attachments: attachments,
      context: context,
      createdAt: now,
      updatedAt: now,
    );
  }

  Intent copyWith({
    IntentId? id,
    String? expression,
    String? description,
    String? category,
    ExperienceType? suggestedExperienceType,
    InputModality? modality,
    IntentStatus? status,
    List<IntentAttachment>? attachments,
    Map<String, dynamic>? context,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Intent(
      id: id ?? this.id,
      expression: expression ?? this.expression,
      description: description ?? this.description,
      category: category ?? this.category,
      suggestedExperienceType:
          suggestedExperienceType ?? this.suggestedExperienceType,
      modality: modality ?? this.modality,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      context: context ?? this.context,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Whether this intent has any attachments.
  bool get hasAttachments => attachments.isNotEmpty;

  /// Whether this intent can be submitted.
  bool get canSubmit =>
      expression.trim().isNotEmpty && status == IntentStatus.draft;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Intent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          expression == other.expression &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, expression, status);
}

/// Types of experiences that can be created from an intent.
enum ExperienceType {
  generativeUi,
  application,
  workspace,
  dashboard,
  form,
  chat,
  canvas,
  reference,
  tool,
  unknown,
}
