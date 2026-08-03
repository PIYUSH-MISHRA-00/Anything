/// Canonical Implementation Model — Implementation Milestone R9. A real,
/// typed, LANGUAGE-INDEPENDENT representation of software implementation
/// concepts, unifying frontend Engineering (`EngineeringCandidate`, Vision
/// Milestone V3 — shaped for this codebase's own closed Flutter/Dart
/// runtime vocabulary) and backend Engineering (`BackendEngineeringPlan`,
/// Implementation Milestone R8 — real but domain-specific: a `DatabaseTable`
/// is an engineering DECISION, not yet a generic implementation CONCEPT)
/// into one common vocabulary a future language generator could target.
///
/// Every type here is deliberately free of Flutter/Dart/Java/Kotlin/Swift/
/// TypeScript/Python/Go/Node-specific constructs — verified by a dedicated
/// test (`test/r9_canonical_implementation_model_test.dart`) that inspects
/// every type/field/enum-value name for exactly this. `GenericState`
/// (`application_engineering/engineering_types.dart`, Vision Milestone V3)
/// is reused directly for state names since it was ALREADY a generic,
/// language-neutral vocabulary (idle/loading/editing/saving/...) — not
/// duplicated here.
///
/// Depth is deliberately uneven and stated honestly (see
/// `docs/architecture/CANONICAL_IMPLEMENTATION_MODEL.md`): Entity/
/// Repository/Controller/DTO/Validator/Service (from `BackendEngineeringPlan`)
/// and StateContainer/NavigationHandler/CapabilityAdapter (from
/// `EngineeringCandidate`/`CapabilityRegistry`) get real, complete-feeling
/// depth. AuthenticationAdapter/StorageAdapter/BackgroundWorker are thin,
/// real wrappers over R8's own already-honest-and-minimal models.
/// Realtime Channel/Configuration/Serialization/Error-Handling/Logging/
/// Monitoring are NOT modeled — no real upstream signal exists anywhere in
/// this codebase's engineering models to derive them from without
/// fabricating data (Rule 5/7: never fabricate).
library;

import '../application_engineering/engineering_types.dart' show GenericState;

// ── Shared vocabulary ───────────────────────────────────────────────────

/// A column/field's logical type — storage- and language-agnostic,
/// mirrors `DatabaseColumnType` (R8) exactly (reused values, not a
/// parallel taxonomy).
enum ImplementationDataType { text, integer, decimal, boolean, dateTime, reference }

enum ImplementationOperationKind { list, get, create, update, delete, search }

class ImplementationField {
  final String id;
  final String name;
  final ImplementationDataType type;
  final bool required;

  const ImplementationField({required this.id, required this.name, required this.type, this.required = false});
}

// ── Entity / Repository / Controller / DTO / Validator / Service (real depth, from BackendEngineeringPlan) ──

class ImplementationEntity {
  final String id;
  final String name;
  final List<ImplementationField> fields;

  const ImplementationEntity({required this.id, required this.name, this.fields = const []});
}

class ImplementationRepository {
  final String id;
  final String entityId;
  final List<ImplementationOperationKind> supportedOperations;

  const ImplementationRepository({required this.id, required this.entityId, this.supportedOperations = const []});
}

class ImplementationOperation {
  final String id;
  final ImplementationOperationKind kind;
  final List<String> requestFieldNames;

  const ImplementationOperation({required this.id, required this.kind, this.requestFieldNames = const []});
}

class ImplementationController {
  final String id;
  final String entityId;
  final List<ImplementationOperation> operations;

  const ImplementationController({required this.id, required this.entityId, this.operations = const []});
}

class ImplementationDto {
  final String id;
  final String entityId;
  final List<ImplementationField> fields;

  const ImplementationDto({required this.id, required this.entityId, this.fields = const []});
}

class ImplementationValidationRule {
  final String fieldId;
  final bool required;
  final ImplementationDataType type;

  const ImplementationValidationRule({required this.fieldId, required this.required, required this.type});
}

class ImplementationValidator {
  final String id;
  final String entityId;
  final List<ImplementationValidationRule> rules;

  const ImplementationValidator({required this.id, required this.entityId, this.rules = const []});
}

/// A real, structural aggregation — "the repository + controller for one
/// entity" — never fabricated business logic, just a real grouping of two
/// already-derived concepts.
class ImplementationService {
  final String id;
  final String entityId;
  final String repositoryId;
  final String controllerId;

  const ImplementationService({
    required this.id,
    required this.entityId,
    required this.repositoryId,
    required this.controllerId,
  });
}

enum DependencyKind { entityReference, capability }

/// Real: derived from `ForeignKeyConstraint` (entity-to-entity) and
/// resolved `CapabilityDescriptor` ids (entity-to-capability) — never a
/// guessed relationship.
class ImplementationDependency {
  final String fromId;
  final String toId;
  final DependencyKind kind;

  const ImplementationDependency({required this.fromId, required this.toId, required this.kind});
}

// ── StateContainer / NavigationHandler / CapabilityAdapter (real depth, from EngineeringCandidate/CapabilityRegistry) ──

class StateTransitionSpec {
  final String triggerId;
  final GenericState from;
  final GenericState to;

  const StateTransitionSpec({required this.triggerId, required this.from, required this.to});
}

class StateContainerSpec {
  final String entityId;
  final GenericState initial;
  final List<StateTransitionSpec> transitions;

  const StateContainerSpec({required this.entityId, required this.initial, this.transitions = const []});
}

class NavigationRouteSpec {
  final String fromRouteId;
  final String toRouteId;
  final String triggerId;
  final bool isOverlay;

  const NavigationRouteSpec({
    required this.fromRouteId,
    required this.toRouteId,
    required this.triggerId,
    this.isOverlay = false,
  });
}

class NavigationHandlerSpec {
  final List<NavigationRouteSpec> routes;
  final List<String> deepLinkableRouteIds;

  const NavigationHandlerSpec({this.routes = const [], this.deepLinkableRouteIds = const []});
}

/// One resolved capability, restated in generic adapter vocabulary —
/// reuses `CapabilityRegistry`'s real, existing id/category, never a
/// parallel capability taxonomy.
class CapabilityAdapterSpec {
  final String capabilityId;
  final String category;

  const CapabilityAdapterSpec({required this.capabilityId, required this.category});
}

// ── Authentication / Storage / Background (thin, real wrappers over R8's own already-honest-and-minimal models) ──

class AuthenticationAdapterSpec {
  final bool requiresCredentials;
  final bool providerIndependent;

  const AuthenticationAdapterSpec({required this.requiresCredentials, this.providerIndependent = true});
}

class StorageAdapterSpec {
  final String entityId;
  final bool isFileStorage;

  const StorageAdapterSpec({required this.entityId, required this.isFileStorage});
}

class BackgroundWorkerSpec {
  final bool requiresBackgroundSync;

  const BackgroundWorkerSpec({required this.requiresBackgroundSync});
}

// ── The top-level composition ───────────────────────────────────────────

class CanonicalImplementationModel {
  final List<ImplementationEntity> entities;
  final List<ImplementationRepository> repositories;
  final List<ImplementationController> controllers;
  final List<ImplementationDto> dtos;
  final List<ImplementationValidator> validators;
  final List<ImplementationService> services;
  final List<ImplementationDependency> dependencies;
  final List<StateContainerSpec> stateContainers;
  final NavigationHandlerSpec navigation;
  final List<CapabilityAdapterSpec> capabilityAdapters;
  final AuthenticationAdapterSpec authentication;
  final List<StorageAdapterSpec> storageAdapters;
  final BackgroundWorkerSpec backgroundWorker;

  const CanonicalImplementationModel({
    this.entities = const [],
    this.repositories = const [],
    this.controllers = const [],
    this.dtos = const [],
    this.validators = const [],
    this.services = const [],
    this.dependencies = const [],
    this.stateContainers = const [],
    this.navigation = const NavigationHandlerSpec(),
    this.capabilityAdapters = const [],
    required this.authentication,
    this.storageAdapters = const [],
    required this.backgroundWorker,
  });

  bool get isEmpty => entities.isEmpty && controllers.isEmpty;
}
