# Intent Pipeline Architecture

## Overview

The Intent Pipeline is the primary interaction mechanism in Anything. It transforms user input into typed domain objects that flow through the Kernel boundary.

## Flow

```
User Input (text/voice)
    ↓
AnythingIntentField (visual component)
    ↓
IntentComposer (state management)
    ↓
Intent domain object
    ↓
MinimalKernel (validation + provider check)
    ↓
KernelResult (acceptance/rejection)
    ↓
[Future: Full Kernel → Planning → Experience Creation]
```

## Components

### AnythingIntentField
Visual input component. Supports text input, voice toggle, and submit.

### IntentComposer
State manager that separates visual input from business logic:
- Text input state
- Voice capture state
- Attachment state
- Intent construction
- Submission
- History (future)

### Intent Domain Model
Typed, immutable value object:
- `id`: Unique identifier
- `expression`: User's raw expression
- `description`: Structured description
- `category`: Classification
- `suggestedExperienceType`: Experience type
- `modality`: InputModality (text/voice/mixed/image/file/url)
- `status`: IntentStatus (draft/submitted/awaitingProvider/accepted/failed/cancelled)
- `attachments`: List of IntentAttachment
- `context`: Additional context
- `createdAt`/`updatedAt`: Timestamps

### MinimalKernel
Stage 3 kernel that:
- Validates intent
- Checks provider availability
- Returns typed KernelResult
- Does NOT create Experiences yet

## Privacy

- No API keys in Intent records
- No voice audio stored
- Attachments reference local resources only
- Provider requests go directly to user-selected provider
