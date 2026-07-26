/// Storage repository boundaries for Anything v2.
///
/// These abstractions ensure that the rest of v2 does not
/// depend directly on SQLite or any specific storage mechanism.
///
/// Anything v2 is local-first. Cloud sync may be added later
/// but is not part of Stage 1.
library;

import 'experience.dart';
import 'intent.dart';

/// Abstract repository for persisting Experiences.
abstract class ExperienceRepository {
  /// Save an experience.
  Future<void> save(Experience experience);

  /// Get an experience by ID.
  Future<Experience?> getById(ExperienceId id);

  /// List all experiences, optionally filtered by status.
  Future<List<Experience>> list({
    ExperienceStatus? status,
    int? limit,
    int? offset,
  });

  /// Delete an experience by ID.
  Future<void> delete(ExperienceId id);

  /// Update an experience.
  Future<void> update(Experience experience);

  /// Search experiences by title or description.
  Future<List<Experience>> search(String query);
}

/// Abstract repository for persisting Workspaces.
abstract class WorkspaceRepository {
  /// Save a workspace.
  Future<void> save(Workspace workspace);

  /// Get a workspace by ID.
  Future<Workspace?> getById(WorkspaceId id);

  /// List workspaces for an experience.
  Future<List<Workspace>> listByExperience(ExperienceId experienceId);

  /// Delete a workspace by ID.
  Future<void> delete(WorkspaceId id);

  /// Update a workspace.
  Future<void> update(Workspace workspace);
}

/// Abstract repository for persisting Intents (for history/learning).
abstract class IntentRepository {
  /// Save an intent.
  Future<void> save(Intent intent);

  /// Get recent intents.
  Future<List<Intent>> getRecent({int limit = 50});

  /// Get intents by category.
  Future<List<Intent>> getByCategory(String category);
}

/// Abstract repository for persisting user preferences.
abstract class PreferencesRepository {
  /// Save a preference value.
  Future<void> save(String key, String value);

  /// Get a preference value.
  Future<String?> get(String key);

  /// Delete a preference.
  Future<void> delete(String key);

  /// List all preferences.
  Future<Map<String, String>> listAll();
}
