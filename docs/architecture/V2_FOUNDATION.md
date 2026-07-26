# Anything v2 Architecture Foundation

## 1. Vision

Anything is an AI Operating System that replaces the fragmented "app" model with a unified Experience Model. Users express intent through natural language, and Anything creates, assembles, and manages usable experiences — from simple generated UI to full-stack applications.

The long-term product vision is an intent-driven AI operating environment capable of creating and running usable applications/experiences inside Anything.

## 2. Intent → Plan → Experience

The core flow:

```
User Input (text/voice)
    ↓
Intent (parsed, structured)
    ↓
ExecutionPlan (ordered capability invocations)
    ↓
Experience (persistent, reusable, openable)
```

The Kernel analyzes intent, creates plans, and orchestrates execution. The Runtime hosts experiences and manages the event bus. Capabilities are the building blocks.

## 3. Experience vs Workspace

**Experience**: A persistent, usable creation. Survives after generation. Can be reopened from the library. May contain UI, logic, storage, services, and more.

**Workspace**: The contextual working environment inside an Experience — the active view, its state, and its current context.

One Experience can have multiple Workspaces.

## 4. Kernel Responsibility

The Kernel is the central orchestrator:

- Analyzes user intents
- Creates execution plans
- Orchestrates capability invocation
- Manages experience lifecycle
- Coordinates with the Runtime

The Kernel does NOT depend on Flutter widgets or UI implementations.

## 5. Runtime Responsibility

The Runtime is the execution engine:

- Hosts active experiences
- Manages the event bus
- Coordinates capability execution
- Handles background tasks
- Provides the execution environment

The Runtime does NOT depend on screen implementations.

## 6. Capability Architecture

Capabilities are composable abilities available to the Kernel:

- **UI Capabilities**: Generate or render UI (e.g., GenerativeUiCapability)
- **Computation Capabilities**: Execute logic
- **Data Capabilities**: Access or manage storage
- **Integration Capabilities**: Interact with external services
- **Security Capabilities**: Kaalka protection
- **Knowledge Capabilities**: WebWeaveX information retrieval
- **Multimodal Capabilities**: Voice and other input/output

Capabilities are registered with the Runtime and invoked through CapabilityRequest objects.

## 7. Model Provider Abstraction

Business logic never requires a specific AI provider:

```
Kernel → ModelProvider → Provider Adapter → [Groq | OpenAI | Gemini | ...]
```

- ModelProvider: abstract interface
- ModelProviderRegistry: manages multiple providers
- Provider implementations depend on contracts
- Contracts do not depend on provider implementations

## 8. WebWeaveX Boundary

WebWeaveX is the knowledge and extraction foundation. It will support acquisition of documentation, implementation patterns, repositories, code, APIs, package information, technical references, and web knowledge.

The KnowledgeProvider contract is the boundary. WebWeaveX will become an adapter behind this contract.

UI widgets must NEVER import WebWeaveX directly.

## 9. Kaalka Boundary

Kaalka is the protection engine using time-based encryption. The ProtectionProvider contract is the boundary.

Future UX requirements:
- Use Current Time (default)
- Choose Custom Date/Time

The algorithm is not changed in Stage 1.

## 10. Storage Boundary

Anything v2 is local-first. Repository boundaries ensure the rest of v2 does not depend directly on SQLite.

Repositories:
- ExperienceRepository
- WorkspaceRepository
- IntentRepository
- PreferencesRepository

## 11. Generative UI's New Role

The existing ui_engine (AUIL) becomes one capability — GenerativeUiCapability — used by the Runtime. It is NOT the architectural center of v2.

The architecture must support generation of complete runnable Experiences, not only Flutter widget trees.

## 12. Developer Mode Boundary

Technical users may inspect generated code, execution plans, capabilities, events, runtime state, and diagnostics. This is secondary to the consumer experience.

Developer Mode is a UI concern, not an architectural concern. It reads from the same event bus and capability registry.

## 13. Local-First Principle

Anything v2 remains local-first:

- Data and execution happen locally by default
- No cloud infrastructure required for core functionality
- Privacy by default
- Sync may be added later but is not part of Stage 1

## 14. Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                   Presentation Plane                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │   Home   │ │Experience│ │Workspace │ │ Settings│ │
│  │  Screen  │ │  Screen  │ │  Screen  │ │ Screen │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ │
│       │             │            │            │      │
│  ┌────┴─────────────┴────────────┴────────────┴────┐ │
│  │              Design System (tokens/components)  │ │
│  └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│                  Orchestration Plane                  │
│  ┌───────────────────────────────────────────────┐  │
│  │                   Kernel                       │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │  │
│  │  │  Intent   │ │  Plan    │ │  Capability  │  │  │
│  │  │ Analyzer  │ │ Creator  │ │  Orchestrator│  │  │
│  │  └──────────┘ └──────────┘ └──────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│                   Execution Plane                    │
│  ┌───────────────────────────────────────────────┐  │
│  │                  Runtime                       │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │  │
│  │  │  Event   │ │Capability│ │ Experience   │  │  │
│  │  │   Bus    │ │ Executor │ │   Host       │  │  │
│  │  └──────────┘ └──────────┘ └──────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│                    Capabilities                      │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────────┐ │
│  │Genera- │ │  Data  │ │  Web   │ │   Kaalka     │ │
│  │tive UI │ │Access  │ │WeaveX  │ │  Protection  │ │
│  └────────┘ └────────┘ └────────┘ └──────────────┘ │
├─────────────────────────────────────────────────────┤
│                    Data Plane                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────┐ │
│  │Experience│ │Workspace │ │     Preferences      │ │
│  │   Repo   │ │   Repo   │ │        Repo          │ │
│  └──────────┘ └──────────┘ └──────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## 15. Migration Plan from Legacy Anything

### Phase 1: Foundation (Stage 1 - Current)
- Define all contracts
- Create v2 directory structure
- Organize design references
- Document architecture
- Establish provider abstraction boundary

### Phase 2: Bridge (Stage 2)
- Create adapter wrapping legacy GroqService behind ModelProvider
- Create adapter wrapping legacy EncryptionManager behind ProtectionProvider
- Create adapter wrapping legacy MemoryManager behind repositories
- Preserve legacy ui_engine as GenerativeUiCapability
- Migrate screens to v2 feature structure

### Phase 3: Replace (Stage 3+)
- Implement Kernel with real intent analysis
- Implement Runtime with real capability execution
- Replace legacy adapters with clean implementations
- Add new capabilities (WebWeaveX, etc.)
- Build new screens using design system

### What Gets Preserved
- AUIL schema model and parser → becomes part of GenerativeUiCapability
- Component registry → becomes part of GenerativeUiCapability
- Layout engine → becomes part of GenerativeUiCapability
- Kaalka service → wrapped by ProtectionProvider adapter
- Encryption manager → wrapped by ProtectionProvider adapter
- SQLite service → wrapped by repository adapters
- Memory manager → replaced by repository implementations
- Groq service → wrapped by ModelProvider adapter
- Voice service → preserved as multimodal capability
- File context service → preserved as data capability

### What Gets Deprecated
- Direct Groq coupling in business logic
- Direct SQLite usage outside storage layer
- Direct Kaalka usage outside security layer
- Monolithic workspace screen
- Hardcoded workspaces
- Template screen (replaced by experience library)
