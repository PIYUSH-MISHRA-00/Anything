# Legacy Component Audit — Anything v1

## Classification Legend

| Class | Meaning |
|-------|---------|
| **KEEP** | Code is useful as-is for v2, no changes needed |
| **REFACTOR** | Code has value but needs restructuring for v2 architecture |
| **ADAPT** | Code needs a boundary/adapter to fit v2 contracts |
| **DEPRECATE** | Code is no longer needed in v2 or will be replaced |
| **UNKNOWN** | Insufficient information to classify |

---

## lib/main.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Entry point is functional but needs to be restructured to use v2 dependency injection and routing. The HomeWidget deep linking and ProviderScope are useful. The hardcoded dark theme should be replaced with the v2 design system theme. |

## lib/core/

### core/intent_engine.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Functional intent analysis via Groq. Must be wrapped behind the Kernel contract. The Groq-specific coupling will be replaced by the ModelProvider abstraction. The prompt engineering and analysis logic may be preserved. |

### core/reasoning_engine.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Central AI pipeline. Must be integrated into the Kernel's planning process. The Groq coupling will be replaced by ModelProvider. The AUIL generation logic becomes part of GenerativeUiCapability. |

### core/context_engine.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Context compilation is useful but tightly coupled to MemoryManager. Will be adapted to use the repository contracts. The logic for compiling personal context is valuable. |

### core/error_handler.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Clean, standalone error classification and widget building. No internal coupling. Useful as-is or with minor updates for v2 error types. |

## lib/ui_engine/

### ui_engine/auil_parser.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP (as capability component) |
| **Reason** | Clean JSON parser for AUIL. No external coupling. Becomes part of GenerativeUiCapability. |

### ui_engine/component_registry.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | 16+ reusable UI components. Valuable widget implementations but tightly coupled to AUIL model. Should be migrated to design_system/components/ with AUIL integration as a capability. |

### ui_engine/generative_ui_renderer.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Top-level entry point for generative UI. Will become the main widget of GenerativeUiCapability. Needs decoupling from direct AUIL dependency. |

### ui_engine/layout_engine.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP (as capability component) |
| **Reason** | Layout selection logic. Clean, reusable. Becomes part of GenerativeUiCapability. |

## lib/services/

### services/groq_service.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Core AI service with Groq-specific coupling. Must be wrapped behind ModelProvider contract. The API key management, connection testing, and response generation logic is valuable. Will become GroqAdapter implementing ModelProvider. |

### services/voice_service.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Voice recording and transcription. Tightly coupled to Groq's Whisper API. Will be adapted to use ModelProvider for transcription. Becomes a multimodal capability. |

### services/file_context_service.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | File picker service with no internal coupling. Useful as-is. Can become a data capability. |

### services/web_search_service.dart

| Field | Value |
|-------|-------|
| **Classification** | DEPRECATE |
| **Reason** | Simulated search results via Groq. Not real web search. Will be replaced by WebWeaveX knowledge capabilities. |

### services/analytics_service.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Stub analytics. No coupling. Useful placeholder for future implementation. |

### services/latency_manager.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Perceived-latency utilities. No coupling. Useful for performance optimization. |

## lib/screens/

### screens/splash_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Animated splash with routing logic. Will be restructured for v2 navigation. The animation concepts are useful. |

### screens/onboarding_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | 4-page onboarding. Functional but should be updated for v2 design system and experience model. |

### screens/app_shell.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Main navigation shell with bottom tabs. Will be restructured for v2's home/experience/workspace navigation model. |

### screens/workspace_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Central workspace screen. Tightly coupled to reasoning engine, tool router, workflow engine, and generative UI. Must be decomposed for v2 architecture. |

### screens/workspaces_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | DEPRECATE |
| **Reason** | Hardcoded workspace cards (Startup, Coding, Study). Will be replaced by experience library. |

### screens/templates_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | DEPRECATE |
| **Reason** | Static template gallery. Will be replaced by experience creation flow. |

### screens/memory_dashboard_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Displays conversation memories. Will be restructured to use repository contracts. Useful functionality. |

### screens/ai_settings_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Settings hub. Will be restructured for v2 preferences feature. |

### screens/groq_settings_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Groq-specific settings. Will be generalized to support multiple providers via ModelProvider. |

### screens/groq_webview_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | WebView for Groq console. Useful as-is if Groq remains a provider option. |

### screens/kaalka_security_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Kaalka-specific settings. Will be adapted to use ProtectionProvider contract. |

### screens/personal_context_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Personal context settings. Will be restructured for v2 preferences. |

### screens/skills_marketplace_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | DEPRECATE |
| **Reason** | Static skill marketplace. Will be replaced by dynamic capability discovery. |

## lib/models/

### models/auil_schema_model.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Clean AUIL data model. No coupling. Useful as-is for GenerativeUiCapability. |

### models/intent_model.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Functional intent model. Will be replaced by the v2 Intent contract but the structure is informative. |

### models/workspace_model.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Workspace model. Will be replaced by the v2 Workspace contract but the structure is informative. |

## lib/memory/

### memory/memory_manager.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Central memory layer with encryption. Will be adapted to use repository contracts. The encryption integration with Kaalka is valuable. |

### memory/sqlite_service.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | SQLite initialization. Will be adapted behind repository implementations. The schema is informative for v2 storage design. |

## lib/security/

### security/kaalka_service.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Kaalka wrapper. Will be adapted behind ProtectionProvider contract. The seed generation logic is valuable. |

### security/encryption_manager.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Encryption manager. Will be adapted behind ProtectionProvider contract. Has compile errors (missing async/await) that need fixing. |

## lib/agents/

### agents/agent_manager.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Multi-agent pipeline orchestrator. The pipeline concept is valuable but tightly coupled to Groq. Will be adapted to use ModelProvider. |

### agents/planner_agent.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Plan creation via Groq. Will be adapted to use ModelProvider. The prompt engineering is valuable. |

### agents/researcher_agent.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Research via Groq. Will be adapted to use ModelProvider. |

### agents/analyst_agent.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Analysis via Groq. Will be adapted to use ModelProvider. |

### agents/builder_agent.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | AUIL generation via Groq. Will be adapted to use ModelProvider. The prompt engineering for AUIL generation is valuable. |

## lib/tools/

### tools/tool_registry.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Clean tool abstraction with registry. Useful pattern for capabilities. |

### tools/tool_router.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Tool execution routing. Useful pattern for capability orchestration. |

### tools/calculator_tool.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Functional calculator tool. No coupling. Useful as a capability. |

### tools/crypto_tool.dart

| Field | Value |
|-------|-------|
| **Classification** | DEPRECATE |
| **Reason** | Stub with hardcoded mock data. Not functional. |

### tools/file_analysis_tool.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Functional file analysis. No coupling. Useful as a capability. |

### tools/web_search_tool.dart

| Field | Value |
|-------|-------|
| **Classification** | DEPRECATE |
| **Reason** | Delegates to simulated web search. Will be replaced by WebWeaveX. |

## lib/workflow/

### workflow/workflow_engine.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Workflow orchestration. Will be adapted to become part of the Kernel's planning process. |

### workflow/workflow_executor.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Step logging utility. Clean, no coupling. Useful for execution tracking. |

### workflow/workflow_memory.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Workflow persistence. Will be adapted to use repository contracts. |

## lib/widgets/

### widgets/ai_command_bar.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Primary input bar with voice and file support. Will be restructured for v2 design system. The functionality is valuable. |

### widgets/ai_loading_screen.dart

| Field | Value |
|-------|-------|
| **Classification** | REFACTOR |
| **Reason** | Loading animation. Will be updated for v2 design system. The stage-based approach is useful. |

### widgets/analogue_clock_picker.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Custom clock picker for Kaalka time seed. No coupling. Useful as-is. |

### widgets/custom_hub_logo.dart

| Field | Value |
|-------|-------|
| **Classification** | KEEP |
| **Reason** | Custom painted logo. No coupling. Useful as-is. |

### widgets/workspace_container.dart

| Field | Value |
|-------|-------|
| **Classification** | ADAPT |
| **Reason** | Workspace container wrapping GenerativeUIRenderer. Will be adapted for v2 experience hosting. |

---

## Summary

| Classification | Count | Files |
|---------------|-------|-------|
| **KEEP** | 14 | error_handler, auil_parser, layout_engine, file_context_service, analytics_service, latency_manager, auil_schema_model, tool_registry, tool_router, calculator_tool, file_analysis_tool, workflow_executor, analogue_clock_picker, custom_hub_logo |
| **REFACTOR** | 10 | main, component_registry, splash_screen, onboarding_screen, app_shell, workspace_screen, memory_dashboard_screen, ai_settings_screen, ai_command_bar, ai_loading_screen |
| **ADAPT** | 16 | intent_engine, reasoning_engine, context_engine, groq_service, voice_service, generative_ui_renderer, kaalka_service, encryption_manager, agent_manager, planner_agent, researcher_agent, analyst_agent, builder_agent, workflow_engine, workspace_container, memory_manager, sqlite_service, intent_model, workspace_model |
| **DEPRECATE** | 5 | web_search_service, workspaces_screen, templates_screen, skills_marketplace_screen, crypto_tool, web_search_tool |

## Pre-existing Failures

| Issue | Severity | Details |
|-------|----------|---------|
| Flutter SDK not installed | BLOCKER | Cannot run flutter commands on this machine |
| encryption_manager.dart compile errors | HIGH | Missing async/await in encryptData/decryptData |
| kaalka_service.dart compile error | HIGH | Undefined named parameter `secretKey` |
| groq_service.dart compile error | HIGH | Undefined `secureStorageProvider` (resolved in current code) |
| widget_test.dart wrong class name | HIGH | References `MyApp` instead of `AnythingApp` |
| Deprecation warnings | LOW | 12x `withOpacity`, 3x `activeColor` |
