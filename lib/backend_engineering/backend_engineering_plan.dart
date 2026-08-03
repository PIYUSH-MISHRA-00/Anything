/// Backend Engineering Plan — Implementation Milestone R8's complete,
/// typed output: the deterministic engineering pipeline's extension from
/// frontend-only Experience engineering into full-stack specification.
/// Composed of real, independently-derived sub-models — never generated
/// source code, SQL, or a deployment config, purely typed specification
/// data (see this milestone's own mandatory constraint).
library;

import 'api_specification.dart';
import 'authentication_model.dart';
import 'background_jobs_model.dart';
import 'database_schema.dart';
import 'deployment_specification.dart';
import 'storage_model.dart';

class BackendEngineeringPlan {
  final DatabaseSchemaModel database;
  final ApiSpecificationModel api;
  final AuthenticationModel authentication;
  final BackendStorageModel storage;
  final BackgroundJobsModel backgroundJobs;
  final DeploymentSpecificationModel deployment;

  const BackendEngineeringPlan({
    required this.database,
    required this.api,
    required this.authentication,
    required this.storage,
    required this.backgroundJobs,
    required this.deployment,
  });

  bool get isEmpty => database.isEmpty && api.isEmpty;
}
