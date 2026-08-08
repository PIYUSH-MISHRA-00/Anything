/// Backend Engineering Planner — Implementation Milestone R8. Real,
/// deterministic derivation from the SAME already-computed
/// `ArchitectureCandidate`/`SemanticApp` frontend Engineering already
/// consumes (`EngineeringContext`, Vision Milestone V3) — zero new AI
/// call, zero new upstream dependency. Mirrors `EngineeringPlanner`'s
/// own one-module-per-concern assembly shape.
///
/// Depth is deliberately uneven and stated honestly (see
/// `docs/architecture/BACKEND_ENGINEERING.md`): Database Schema and API
/// Specification are derived with real, complete-feeling depth, since
/// `SemanticEntity`/`SemanticField`/`InteractionDecision` genuinely carry
/// enough real, typed data to support it. Authentication/Storage/
/// Background-Jobs/Deployment stay intentionally minimal — real, never
/// fabricated, but limited to exactly what upstream architecture
/// decisions actually provide a signal for.
library;

import '../software_architect/architecture_types.dart';
import '../synthesis/app_blueprint.dart' show BlueprintFieldType;
import 'api_specification.dart';
import 'authentication_model.dart';
import 'background_jobs_model.dart';
import 'backend_engineering_context.dart';
import 'backend_engineering_plan.dart';
import 'database_schema.dart';
import 'deployment_specification.dart';
import 'storage_model.dart';

DatabaseColumnType _columnTypeFor(BlueprintFieldType type) => switch (type) {
  BlueprintFieldType.text ||
  BlueprintFieldType.multilineText ||
  BlueprintFieldType.category ||
  BlueprintFieldType.url => DatabaseColumnType.text,
  BlueprintFieldType.integer => DatabaseColumnType.integer,
  BlueprintFieldType.decimal => DatabaseColumnType.decimal,
  BlueprintFieldType.boolean => DatabaseColumnType.boolean,
  BlueprintFieldType.date ||
  BlueprintFieldType.dateTime ||
  BlueprintFieldType.time => DatabaseColumnType.dateTime,
  BlueprintFieldType.reference => DatabaseColumnType.reference,
  // A derived value is computed, never stored — DataEngineering (V3)
  // already treats these as aggregations, not columns; mirrored here.
  BlueprintFieldType.derived => DatabaseColumnType.text,
};

class BackendEngineeringPlanner {
  const BackendEngineeringPlanner();

  BackendEngineeringPlan plan(BackendEngineeringContext context) {
    return BackendEngineeringPlan(
      database: _planDatabase(context),
      api: _planApi(context),
      authentication: _planAuthentication(context),
      storage: _planStorage(context),
      backgroundJobs: _planBackgroundJobs(context),
      deployment: _planDeployment(context),
    );
  }

  DatabaseSchemaModel _planDatabase(BackendEngineeringContext context) {
    final relationshipsByField = {
      for (final r in context.architecture.relationships)
        '${r.fromEntityId}.${r.fieldId}': r,
    };

    final tables = context.app.entities.map((entity) {
      final columns = <DatabaseColumn>[
        DatabaseColumn(
          id: '${entity.id}.id',
          name: 'id',
          type: DatabaseColumnType.text,
          required: true,
          isPrimaryKey: true,
        ),
        for (final field in entity.fields)
          if (field.type != BlueprintFieldType.derived)
            DatabaseColumn(
              id: '${entity.id}.${field.id}',
              name: field.name,
              type: _columnTypeFor(field.type),
              required: field.required,
            ),
      ];

      final foreignKeys = <ForeignKeyConstraint>[
        for (final field in entity.fields)
          if (field.referenceEntityId != null)
            ForeignKeyConstraint(
              columnId: '${entity.id}.${field.id}',
              referencesTableId: field.referenceEntityId!,
              onDelete:
                  relationshipsByField['${entity.id}.${field.id}']
                      ?.deletePolicy
                      .name ??
                  RelationshipDeletePolicy.setNull.name,
            ),
      ];

      return DatabaseTable(
        id: entity.id,
        name: entity.name,
        columns: columns,
        foreignKeys: foreignKeys,
      );
    }).toList();

    return DatabaseSchemaModel(tables: tables);
  }

  ApiSpecificationModel _planApi(BackendEngineeringContext context) {
    final interactionByEntity = {
      for (final i in context.architecture.interactions) i.entityId: i,
    };
    final endpoints = <ApiEndpoint>[];

    for (final entity in context.app.entities) {
      final interaction = interactionByEntity[entity.id];
      if (interaction == null) continue;

      final requestFields = [
        for (final field in entity.fields)
          if (field.type != BlueprintFieldType.derived)
            ApiRequestField(name: field.name, required: field.required),
      ];

      if (interaction.canRead) {
        endpoints.add(
          ApiEndpoint(
            id: '${entity.id}.list',
            path: '/${entity.id}',
            method: HttpMethod.get,
            operation: ApiOperation.list,
            entityId: entity.id,
          ),
        );
        endpoints.add(
          ApiEndpoint(
            id: '${entity.id}.get',
            path: '/${entity.id}/{id}',
            method: HttpMethod.get,
            operation: ApiOperation.get,
            entityId: entity.id,
          ),
        );
      }
      if (interaction.canCreate) {
        endpoints.add(
          ApiEndpoint(
            id: '${entity.id}.create',
            path: '/${entity.id}',
            method: HttpMethod.post,
            operation: ApiOperation.create,
            entityId: entity.id,
            requestFields: requestFields,
          ),
        );
      }
      if (interaction.canUpdate) {
        endpoints.add(
          ApiEndpoint(
            id: '${entity.id}.update',
            path: '/${entity.id}/{id}',
            method: HttpMethod.put,
            operation: ApiOperation.update,
            entityId: entity.id,
            requestFields: requestFields,
          ),
        );
      }
      if (interaction.canDelete) {
        endpoints.add(
          ApiEndpoint(
            id: '${entity.id}.delete',
            path: '/${entity.id}/{id}',
            method: HttpMethod.delete,
            operation: ApiOperation.delete,
            entityId: entity.id,
          ),
        );
      }
      if (interaction.supportsSearch) {
        endpoints.add(
          ApiEndpoint(
            id: '${entity.id}.search',
            path: '/${entity.id}/search',
            method: HttpMethod.get,
            operation: ApiOperation.search,
            entityId: entity.id,
          ),
        );
      }
    }

    return ApiSpecificationModel(endpoints: endpoints);
  }

  AuthenticationModel _planAuthentication(BackendEngineeringContext context) =>
      AuthenticationModel(
        requiresCredentials:
            context.architecture.security.requiresCredentialVault,
      );

  BackendStorageModel _planStorage(BackendEngineeringContext context) =>
      BackendStorageModel(
        requirements: [
          for (final e in context.architecture.entities)
            StorageRequirement(entityId: e.entityId, kind: e.storage),
        ],
      );

  BackgroundJobsModel _planBackgroundJobs(BackendEngineeringContext context) {
    final strategy = context.architecture.synchronization.strategy;
    return BackgroundJobsModel(
      requiresBackgroundSync:
          strategy == SyncStrategy.cacheFirst ||
          strategy == SyncStrategy.networkFirst,
      sourceStrategy: strategy,
    );
  }

  DeploymentSpecificationModel _planDeployment(
    BackendEngineeringContext context,
  ) {
    final requiresBackend =
        context.architecture.offline.capability !=
            OfflineCapability.fullyOffline ||
        context.architecture.security.networkMode != NetworkMode.none;
    return DeploymentSpecificationModel(
      requiresBackend: requiresBackend,
      secretReferences: context.architecture.security.requiresCredentialVault
          ? const [SecretReference('BACKEND_API_CREDENTIALS')]
          : const [],
    );
  }
}
