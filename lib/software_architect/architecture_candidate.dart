/// Architecture Candidate — the complete, typed output of the ASAE
/// planning pipeline for one application, before/after self-critique and
/// refinement.
library;

import 'architecture_types.dart';
import 'confidence.dart' show Confidence, ArchitectureDecision;

class ArchitectureCandidate {
  final String id;
  final String appName;
  final int iteration;
  final List<EntityDecision> entities;
  final List<FieldDecision> fields;
  final List<RelationshipDecision> relationships;
  final List<StateDecision> states;
  final NavigationGraph navigation;
  final List<InteractionDecision> interactions;
  final List<CapabilityDecision> capabilities;
  final List<PermissionDecision> permissions;
  final SecurityDecision security;
  final OfflineDecision offline;
  final SynchronizationDecision synchronization;
  final List<ValidationRule> validations;
  final Confidence overallConfidence;

  const ArchitectureCandidate({
    required this.id,
    required this.appName,
    this.iteration = 0,
    this.entities = const [],
    this.fields = const [],
    this.relationships = const [],
    this.states = const [],
    required this.navigation,
    this.interactions = const [],
    this.capabilities = const [],
    this.permissions = const [],
    required this.security,
    required this.offline,
    required this.synchronization,
    this.validations = const [],
    required this.overallConfidence,
  });

  /// Every ArchitectureDecision this candidate is built from, flattened —
  /// used by ConfidenceAnalyzer/SelfCritic to inspect the whole candidate
  /// without threading through every nested list individually.
  List<ArchitectureDecision> get allDecisions => [
    ...entities.map((e) => e.storageDecision),
    ...fields.map((f) => f.validationDecision),
    ...relationships.map((r) => r.decision),
    ...states.map((s) => s.decision),
    navigation.decision,
    ...interactions.map((i) => i.decision),
    ...capabilities.map((c) => c.decision),
    ...permissions.map((p) => p.decision),
    security.decision,
    offline.decision,
    synchronization.decision,
  ];

  ArchitectureCandidate copyWith({
    int? iteration,
    List<EntityDecision>? entities,
    List<FieldDecision>? fields,
    List<RelationshipDecision>? relationships,
    List<StateDecision>? states,
    NavigationGraph? navigation,
    List<InteractionDecision>? interactions,
    List<CapabilityDecision>? capabilities,
    List<PermissionDecision>? permissions,
    SecurityDecision? security,
    OfflineDecision? offline,
    SynchronizationDecision? synchronization,
    List<ValidationRule>? validations,
    Confidence? overallConfidence,
  }) {
    return ArchitectureCandidate(
      id: id,
      appName: appName,
      iteration: iteration ?? this.iteration,
      entities: entities ?? this.entities,
      fields: fields ?? this.fields,
      relationships: relationships ?? this.relationships,
      states: states ?? this.states,
      navigation: navigation ?? this.navigation,
      interactions: interactions ?? this.interactions,
      capabilities: capabilities ?? this.capabilities,
      permissions: permissions ?? this.permissions,
      security: security ?? this.security,
      offline: offline ?? this.offline,
      synchronization: synchronization ?? this.synchronization,
      validations: validations ?? this.validations,
      overallConfidence: overallConfidence ?? this.overallConfidence,
    );
  }
}
