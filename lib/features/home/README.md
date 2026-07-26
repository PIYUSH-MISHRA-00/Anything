# features/home/

Universal Intent Surface: the home screen and primary interaction surface.

## What belongs here

- Home screen widget and layout
- Intent capture UI (voice, text, gesture)
- Quick action surfaces
- Intent input parsing UI

## What does NOT belong here

- Intent parsing logic (use `kernel/`)
- Activity timeline (use `features/activity/`)
- Experience management (use `features/experiences/`)

## Key interfaces

- `HomeScreen`
- `IntentCaptureWidget`
- `QuickActionsPanel`
