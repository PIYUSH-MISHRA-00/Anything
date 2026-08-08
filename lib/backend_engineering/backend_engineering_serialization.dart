/// BackendEngineeringPlan (de)serialization — Implementation Milestone
/// R8. Same convention as `architecture_candidate_serialization.dart`
/// (R5): hand-written `toJson()`/`fromJson()`, full fidelity, every
/// field round-trips.
library;

import '../software_architect/architecture_types.dart'
    show StorageKind, SyncStrategy;
import 'api_specification.dart';
import 'authentication_model.dart';
import 'background_jobs_model.dart';
import 'backend_engineering_plan.dart';
import 'database_schema.dart';
import 'deployment_specification.dart';
import 'storage_model.dart';

extension BackendEngineeringPlanJson on BackendEngineeringPlan {
  Map<String, dynamic> toJson() => {
    'database': {
      'tables': database.tables
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'columns': t.columns
                  .map(
                    (c) => {
                      'id': c.id,
                      'name': c.name,
                      'type': c.type.name,
                      'required': c.required,
                      'isPrimaryKey': c.isPrimaryKey,
                    },
                  )
                  .toList(),
              'foreignKeys': t.foreignKeys
                  .map(
                    (f) => {
                      'columnId': f.columnId,
                      'referencesTableId': f.referencesTableId,
                      'onDelete': f.onDelete,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    },
    'api': {
      'endpoints': api.endpoints
          .map(
            (e) => {
              'id': e.id,
              'path': e.path,
              'method': e.method.name,
              'operation': e.operation.name,
              'entityId': e.entityId,
              'requestFields': e.requestFields
                  .map((f) => {'name': f.name, 'required': f.required})
                  .toList(),
            },
          )
          .toList(),
    },
    'authentication': {
      'requiresCredentials': authentication.requiresCredentials,
      'providerIndependent': authentication.providerIndependent,
    },
    'storage': {
      'requirements': storage.requirements
          .map((r) => {'entityId': r.entityId, 'kind': r.kind.name})
          .toList(),
    },
    'backgroundJobs': {
      'requiresBackgroundSync': backgroundJobs.requiresBackgroundSync,
      'sourceStrategy': backgroundJobs.sourceStrategy.name,
    },
    'deployment': {
      'requiresBackend': deployment.requiresBackend,
      'secretReferences': deployment.secretReferences
          .map((s) => s.name)
          .toList(),
    },
  };
}

BackendEngineeringPlan backendEngineeringPlanFromJson(
  Map<String, dynamic> json,
) {
  final databaseJson = json['database'] as Map<String, dynamic>;
  final apiJson = json['api'] as Map<String, dynamic>;
  final authJson = json['authentication'] as Map<String, dynamic>;
  final storageJson = json['storage'] as Map<String, dynamic>;
  final bgJson = json['backgroundJobs'] as Map<String, dynamic>;
  final deployJson = json['deployment'] as Map<String, dynamic>;

  return BackendEngineeringPlan(
    database: DatabaseSchemaModel(
      tables: (databaseJson['tables'] as List).map((t) {
        final tj = t as Map<String, dynamic>;
        return DatabaseTable(
          id: tj['id'] as String,
          name: tj['name'] as String,
          columns: (tj['columns'] as List).map((c) {
            final cj = c as Map<String, dynamic>;
            return DatabaseColumn(
              id: cj['id'] as String,
              name: cj['name'] as String,
              type: DatabaseColumnType.values.byName(cj['type'] as String),
              required: cj['required'] as bool,
              isPrimaryKey: cj['isPrimaryKey'] as bool,
            );
          }).toList(),
          foreignKeys: (tj['foreignKeys'] as List).map((f) {
            final fj = f as Map<String, dynamic>;
            return ForeignKeyConstraint(
              columnId: fj['columnId'] as String,
              referencesTableId: fj['referencesTableId'] as String,
              onDelete: fj['onDelete'] as String,
            );
          }).toList(),
        );
      }).toList(),
    ),
    api: ApiSpecificationModel(
      endpoints: (apiJson['endpoints'] as List).map((e) {
        final ej = e as Map<String, dynamic>;
        return ApiEndpoint(
          id: ej['id'] as String,
          path: ej['path'] as String,
          method: HttpMethod.values.byName(ej['method'] as String),
          operation: ApiOperation.values.byName(ej['operation'] as String),
          entityId: ej['entityId'] as String,
          requestFields: (ej['requestFields'] as List).map((f) {
            final fj = f as Map<String, dynamic>;
            return ApiRequestField(
              name: fj['name'] as String,
              required: fj['required'] as bool,
            );
          }).toList(),
        );
      }).toList(),
    ),
    authentication: AuthenticationModel(
      requiresCredentials: authJson['requiresCredentials'] as bool,
      providerIndependent: authJson['providerIndependent'] as bool,
    ),
    storage: BackendStorageModel(
      requirements: (storageJson['requirements'] as List).map((r) {
        final rj = r as Map<String, dynamic>;
        return StorageRequirement(
          entityId: rj['entityId'] as String,
          kind: StorageKind.values.byName(rj['kind'] as String),
        );
      }).toList(),
    ),
    backgroundJobs: BackgroundJobsModel(
      requiresBackgroundSync: bgJson['requiresBackgroundSync'] as bool,
      sourceStrategy: SyncStrategy.values.byName(
        bgJson['sourceStrategy'] as String,
      ),
    ),
    deployment: DeploymentSpecificationModel(
      requiresBackend: deployJson['requiresBackend'] as bool,
      secretReferences: (deployJson['secretReferences'] as List)
          .map((s) => SecretReference(s as String))
          .toList(),
    ),
  );
}
