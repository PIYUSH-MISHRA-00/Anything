/// Core contracts: abstract interfaces and type definitions for Anything v2.
///
/// Import this barrel file to access all contract types.
library;

export 'intent.dart';
export 'experience.dart';
export 'capability.dart';
export 'kernel.dart';
// `runtime.dart` was removed by IS-R47 Task 1 — a dead v1 `AnythingRuntime`
// contract that collided by name with the live
// `lib/runtime/anything_runtime.dart` while having an incompatible shape.
// Nothing implemented it and nothing used any of its symbols; this barrel
// re-export was its only remaining reference.
export 'model_provider.dart';
// `knowledge_provider.dart` was removed by IS-R58 Phase 7 — a dead abstract
// `KnowledgeProvider` contract with ZERO direct importers whose name collided
// with the live `lib/capabilities/builtin/knowledge_capability.dart`
// declaration. Both real implementors — `KnowledgeAcquisitionProviderAdapter`
// and `FakeKnowledgeProvider` — resolve the capability version. This barrel
// re-export was its only remaining reference, exactly as it had been for
// `runtime.dart` (IS-R47) and `repository.dart` (IS-R57). Third instance.
export 'protection_provider.dart';

// `repository.dart` was removed by IS-R57 Phase 4 — four abstract contracts
// (`ExperienceRepository`, `WorkspaceRepository`, `IntentRepository`,
// `PreferencesRepository`) with TWENTY methods, ZERO implementations and zero
// code references. `IntentRepository` collided by name with the live
// `lib/storage/intent_repository.dart`, so any file importing both this barrel
// and that repository would have failed with `ambiguous_import` — the same
// latent trap R54 hit with a duplicated constant. This barrel re-export was
// its only remaining reference, exactly as it had been for `runtime.dart`
// (removed by IS-R47).
