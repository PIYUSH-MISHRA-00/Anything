# Provider Reachability Matrix — IS-R59 Phase 6

Every Riverpod provider and every `ChangeNotifier`/`ValueNotifier` in
`lib/`, with the runtime class of the file that declares it.

## Riverpod providers

| Provider | Kind | File | Runtime class |
|---|---|---|---|
| `agentManagerProvider` | Provider | `lib/agents/agent_manager.dart` | **EXPERIMENTAL** |
| `contextEngineProvider` | Provider | `lib/core/context_engine.dart` | **EXPERIMENTAL** |
| `encryptionManagerProvider` | Provider | `lib/security/encryption_manager.dart` | **EXPERIMENTAL** |
| `fileContextServiceProvider` | Provider | `lib/services/file_context_service.dart` | **EXPERIMENTAL** |
| `groqServiceProvider` | Provider | `lib/services/groq_service.dart` | **EXPERIMENTAL** |
| `intentEngineProvider` | Provider | `lib/core/intent_engine.dart` | **EXPERIMENTAL** |
| `kaalkaServiceProvider` | Provider | `lib/security/kaalka_service.dart` | **REACHABLE** |
| `memoryManagerProvider` | Provider | `lib/memory/memory_manager.dart` | **EXPERIMENTAL** |
| `reasoningEngineProvider` | Provider | `lib/core/reasoning_engine.dart` | **EXPERIMENTAL** |
| `secureStorageProvider` | Provider | `lib/services/groq_service.dart` | **EXPERIMENTAL** |
| `sqliteServiceProvider` | Provider | `lib/memory/sqlite_service.dart` | **EXPERIMENTAL** |
| `toolRegistryProvider` | Provider | `lib/tools/tool_registry.dart` | **EXPERIMENTAL** |
| `toolRouterProvider` | Provider | `lib/tools/tool_router.dart` | **EXPERIMENTAL** |
| `voiceServiceProvider` | Provider | `lib/services/voice_service.dart` | **REACHABLE** |
| `webSearchServiceProvider` | Provider | `lib/services/web_search_service.dart` | **EXPERIMENTAL** |
| `workflowEngineProvider` | Provider | `lib/workflow/workflow_engine.dart` | **EXPERIMENTAL** |
| `workflowMemoryProvider` | Provider | `lib/workflow/workflow_memory.dart` | **EXPERIMENTAL** |

**Every Riverpod provider below is UNREACHABLE.** A provider is
resolved only inside a `ProviderScope`, and no `ProviderScope` exists
anywhere in `lib/` or `test/` — certified by I-85. None of these can
be constructed at runtime today.

## ChangeNotifier / ValueNotifier holders

| Holder | Base | File | Runtime class |
|---|---|---|---|
| `AnythingThemeNotifier` | ChangeNotifier | `lib/design_system/theme/theme_provider.dart` | **REACHABLE** |
| `IntentComposer` | ChangeNotifier | `lib/features/home/intent_composer.dart` | **REACHABLE** |
| `VoiceInputService` | ChangeNotifier | `lib/services/voice_service.dart` | **REACHABLE** |

## Summary

| | Count |
|---|---|
| Riverpod providers | 17 |
| ChangeNotifier/ValueNotifier holders | 3 |
| Providers in REACHABLE files | 2 |

No `Bloc`, `Cubit` or `InheritedWidget` state management exists
(the `Bloc` grep matches are prose in documentation comments, not types).
