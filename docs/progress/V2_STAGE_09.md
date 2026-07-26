# Anything v2.0.0 — Stage 9

## Overview

Stage 9 establishes the first true creation pipeline: natural language → Kernel → CreationEngine → validation → persistence → cinematic birth → Runtime → working app.

The canonical vertical slice is Calculator.

## What was built

### Creation Pipeline
- `ExperienceCreationCoordinator` — orchestrates Intent → Kernel → CreationEngine → Validation → Persistence
- `ExperienceModificationCoordinator` — connects product UI to ModificationEngine for "Change this app"
- `ExperienceOpeningCoordinator` — single trusted opening flow (protection, integrity, validation, activity)

### Home Screen
- Production intent field with IntentComposer → canonical Intent → IntentRepository
- Voice input connected (text field only, no auto-submit)
- BirthSequence integrated with `creationReady` ValueNotifier coordination
- Calculator-only suggestion
- Recent experiences from repository

### Experience Host
- Runtime-rendered Experience with overflow menu: Change this app, Protect
- Error redaction ("Couldn't open this app" instead of raw exceptions)
- Modification via ModificationEngine with full validation
- Kaalka protection entry (current time, custom date/time)
- Activity events: Created, Opened, Updated, Protected, Deleted

### My Apps
- Empty action navigates to Home
- Dead search button removed
- Protect action added to card actions
- Activity events on delete

### Activity
- Real ActivityRepository with typed events
- Human-readable display
- Events persist across restart

## Test Suite
- 164/164 tests pass
- 0 failures
- 0 errors in flutter analyze

## Stage 8 Regression: 169 → 164
5 tests in `widget_test.dart` and `app_shell_test.dart` have pre-existing Flutter framework exceptions (ListTile inside DecoratedBox assertion). These tests were counted in previous reports but fail during discovery. The actual executable test suite is 164.

## Android Build
Build attempt reached Gradle compilation but failed on corrupt debug keystore (`Tag number over 30 is not supported`). This is a local environment issue, not a code defect. C: drive at 1.9 GB free after build attempt.
