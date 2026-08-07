# Repository Dependency Graph — IS-R57

## 1. Construction graph (production, after R57)

```
AppComposition.production()
  |
  +-- SqliteExperienceRepository ......... ONE, shared
  |     +-- WorldModelRepository(experienceRepository:)
  |     +-- EngineeringMemoryRepository(experienceRepository:)
  |     +-- ExperienceCommitFramework(repository:)   <- the ONLY writer (R55)
  |     |     +-- RepositoryTransactionCoordinator
  |     +-- ExperienceProtectionService(repository:, commitFramework:)
  |     +-- ExperienceInstallationFramework(repository:, commitFramework:)
  |           +-- ExperienceDistributionFramework(installer:)
  |
  +-- ActivityRepository ................. ONE, shared   (R57)
  |     +-- ExperienceCreationCoordinator(activity:)
  |     +-- IntentSessionManager(activity:)
  |     +-- ExperienceWorkspaceManager(activity:)
  |     +-- ExperienceOpeningCoordinator(activity:)      (composition + HomeScreen)
  |     +-- ExperiencesScreen        (reads composition.activityRepository)
  |     +-- ExperienceHostScreen     (optional widget param)
  |     +-- ActivityScreen           (optional widget param)
  |
  +-- IntentRepository ................... ONE, shared   (R57)
  |     +-- HomeScreen (reads composition.intentRepository)
  |
  +-- KnowledgeRepository ................ ONE, shared
  +-- CredentialVault .................... ONE, shared

DataRuntime (per Experience session)
  +-- ExperienceDatabase(experienceId)  ... per Experience, by design

DurableCollectionStore ................... stateless const value (R56)
  ^-- ActivityRepository, IntentRepository, RealNotificationService
```

## 2. Write graph

```
creation \ modification \ evolution \ protection \ installation \ removal
                            |
                ExperienceCommitFramework          (R55, certified I-69)
                            |
                 SqliteExperienceRepository

RealNotificationService \ ActivityRepository \ IntentRepository
                            |
                 DurableCollectionStore            (R56, certified I-75/76)
                            |
                    SharedPreferences

ThemeProvider ------------------------------------> SharedPreferences
                                          (one scalar key, PINNED, G-39)
```

## 3. Cycles

**None.** Verified: no repository imports a coordinator, a capability, a
screen or the composition. The dependency direction is strictly

```
composition -> coordinators/screens -> frameworks -> repositories -> backends
```

Certified for the Experience repository by R55's I-74 (it may not name the
commit framework), and by R56's I-76 for the durable collections.

## 4. Layer violations found

| Violation | Status |
|---|---|
| UI constructing repositories (`activity_screen`, `experiences_screen`, `experience_host_screen`, `home_screen` ×2) | **FIXED** (R57) — all now injected or composition-sourced |
| A capability constructing a repository | **none found**; forbidden and mutation-proven (probe E) |
| A runtime file constructing a repository | `experience_host_screen` was one — **FIXED**; mutation-proven (probe C) |
| A repository reaching upward | **none found** |
