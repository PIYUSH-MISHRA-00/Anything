/// CanonicalImplementationModel (de)serialization — Implementation
/// Milestone R9. Same convention as `backend_engineering_serialization.dart`
/// (R8): hand-written `toJson()`/`fromJson()`, full fidelity, every field
/// round-trips, deterministic ordering (list order preserved, never
/// re-sorted).
library;

import '../application_engineering/engineering_types.dart' show GenericState;
import 'canonical_implementation_model.dart';

Map<String, dynamic> _fieldToJson(ImplementationField f) => {'id': f.id, 'name': f.name, 'type': f.type.name, 'required': f.required};

ImplementationField _fieldFromJson(Map<String, dynamic> j) =>
    ImplementationField(id: j['id'] as String, name: j['name'] as String, type: ImplementationDataType.values.byName(j['type'] as String), required: j['required'] as bool);

extension CanonicalImplementationModelJson on CanonicalImplementationModel {
  Map<String, dynamic> toJson() => {
    'entities': entities.map((e) => {'id': e.id, 'name': e.name, 'fields': e.fields.map(_fieldToJson).toList()}).toList(),
    'repositories': repositories
        .map((r) => {'id': r.id, 'entityId': r.entityId, 'supportedOperations': r.supportedOperations.map((o) => o.name).toList()})
        .toList(),
    'controllers': controllers
        .map(
          (c) => {
            'id': c.id,
            'entityId': c.entityId,
            'operations': c.operations
                .map((o) => {'id': o.id, 'kind': o.kind.name, 'requestFieldNames': o.requestFieldNames})
                .toList(),
          },
        )
        .toList(),
    'dtos': dtos.map((d) => {'id': d.id, 'entityId': d.entityId, 'fields': d.fields.map(_fieldToJson).toList()}).toList(),
    'validators': validators
        .map(
          (v) => {
            'id': v.id,
            'entityId': v.entityId,
            'rules': v.rules.map((r) => {'fieldId': r.fieldId, 'required': r.required, 'type': r.type.name}).toList(),
          },
        )
        .toList(),
    'services': services.map((s) => {'id': s.id, 'entityId': s.entityId, 'repositoryId': s.repositoryId, 'controllerId': s.controllerId}).toList(),
    'dependencies': dependencies.map((d) => {'fromId': d.fromId, 'toId': d.toId, 'kind': d.kind.name}).toList(),
    'stateContainers': stateContainers
        .map(
          (s) => {
            'entityId': s.entityId,
            'initial': s.initial.name,
            'transitions': s.transitions.map((t) => {'triggerId': t.triggerId, 'from': t.from.name, 'to': t.to.name}).toList(),
          },
        )
        .toList(),
    'navigation': {
      'routes': navigation.routes
          .map((r) => {'fromRouteId': r.fromRouteId, 'toRouteId': r.toRouteId, 'triggerId': r.triggerId, 'isOverlay': r.isOverlay})
          .toList(),
      'deepLinkableRouteIds': navigation.deepLinkableRouteIds,
    },
    'capabilityAdapters': capabilityAdapters.map((c) => {'capabilityId': c.capabilityId, 'category': c.category}).toList(),
    'authentication': {'requiresCredentials': authentication.requiresCredentials, 'providerIndependent': authentication.providerIndependent},
    'storageAdapters': storageAdapters.map((s) => {'entityId': s.entityId, 'isFileStorage': s.isFileStorage}).toList(),
    'backgroundWorker': {'requiresBackgroundSync': backgroundWorker.requiresBackgroundSync},
  };
}

CanonicalImplementationModel canonicalImplementationModelFromJson(Map<String, dynamic> json) {
  return CanonicalImplementationModel(
    entities: (json['entities'] as List)
        .map((e) {
          final ej = e as Map<String, dynamic>;
          return ImplementationEntity(id: ej['id'] as String, name: ej['name'] as String, fields: (ej['fields'] as List).map((f) => _fieldFromJson(f as Map<String, dynamic>)).toList());
        })
        .toList(),
    repositories: (json['repositories'] as List)
        .map((r) {
          final rj = r as Map<String, dynamic>;
          return ImplementationRepository(
            id: rj['id'] as String,
            entityId: rj['entityId'] as String,
            supportedOperations: (rj['supportedOperations'] as List).map((o) => ImplementationOperationKind.values.byName(o as String)).toList(),
          );
        })
        .toList(),
    controllers: (json['controllers'] as List)
        .map((c) {
          final cj = c as Map<String, dynamic>;
          return ImplementationController(
            id: cj['id'] as String,
            entityId: cj['entityId'] as String,
            operations: (cj['operations'] as List).map((o) {
              final oj = o as Map<String, dynamic>;
              return ImplementationOperation(
                id: oj['id'] as String,
                kind: ImplementationOperationKind.values.byName(oj['kind'] as String),
                requestFieldNames: (oj['requestFieldNames'] as List).cast<String>(),
              );
            }).toList(),
          );
        })
        .toList(),
    dtos: (json['dtos'] as List)
        .map((d) {
          final dj = d as Map<String, dynamic>;
          return ImplementationDto(id: dj['id'] as String, entityId: dj['entityId'] as String, fields: (dj['fields'] as List).map((f) => _fieldFromJson(f as Map<String, dynamic>)).toList());
        })
        .toList(),
    validators: (json['validators'] as List)
        .map((v) {
          final vj = v as Map<String, dynamic>;
          return ImplementationValidator(
            id: vj['id'] as String,
            entityId: vj['entityId'] as String,
            rules: (vj['rules'] as List).map((r) {
              final rj = r as Map<String, dynamic>;
              return ImplementationValidationRule(fieldId: rj['fieldId'] as String, required: rj['required'] as bool, type: ImplementationDataType.values.byName(rj['type'] as String));
            }).toList(),
          );
        })
        .toList(),
    services: (json['services'] as List)
        .map((s) {
          final sj = s as Map<String, dynamic>;
          return ImplementationService(id: sj['id'] as String, entityId: sj['entityId'] as String, repositoryId: sj['repositoryId'] as String, controllerId: sj['controllerId'] as String);
        })
        .toList(),
    dependencies: (json['dependencies'] as List)
        .map((d) {
          final dj = d as Map<String, dynamic>;
          return ImplementationDependency(fromId: dj['fromId'] as String, toId: dj['toId'] as String, kind: DependencyKind.values.byName(dj['kind'] as String));
        })
        .toList(),
    stateContainers: (json['stateContainers'] as List)
        .map((s) {
          final sj = s as Map<String, dynamic>;
          return StateContainerSpec(
            entityId: sj['entityId'] as String,
            initial: GenericState.values.byName(sj['initial'] as String),
            transitions: (sj['transitions'] as List).map((t) {
              final tj = t as Map<String, dynamic>;
              return StateTransitionSpec(triggerId: tj['triggerId'] as String, from: GenericState.values.byName(tj['from'] as String), to: GenericState.values.byName(tj['to'] as String));
            }).toList(),
          );
        })
        .toList(),
    navigation: NavigationHandlerSpec(
      routes: ((json['navigation'] as Map<String, dynamic>)['routes'] as List).map((r) {
        final rj = r as Map<String, dynamic>;
        return NavigationRouteSpec(fromRouteId: rj['fromRouteId'] as String, toRouteId: rj['toRouteId'] as String, triggerId: rj['triggerId'] as String, isOverlay: rj['isOverlay'] as bool);
      }).toList(),
      deepLinkableRouteIds: ((json['navigation'] as Map<String, dynamic>)['deepLinkableRouteIds'] as List).cast<String>(),
    ),
    capabilityAdapters: (json['capabilityAdapters'] as List)
        .map((c) {
          final cj = c as Map<String, dynamic>;
          return CapabilityAdapterSpec(capabilityId: cj['capabilityId'] as String, category: cj['category'] as String);
        })
        .toList(),
    authentication: AuthenticationAdapterSpec(
      requiresCredentials: (json['authentication'] as Map<String, dynamic>)['requiresCredentials'] as bool,
      providerIndependent: (json['authentication'] as Map<String, dynamic>)['providerIndependent'] as bool,
    ),
    storageAdapters: (json['storageAdapters'] as List)
        .map((s) {
          final sj = s as Map<String, dynamic>;
          return StorageAdapterSpec(entityId: sj['entityId'] as String, isFileStorage: sj['isFileStorage'] as bool);
        })
        .toList(),
    backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: (json['backgroundWorker'] as Map<String, dynamic>)['requiresBackgroundSync'] as bool),
  );
}
