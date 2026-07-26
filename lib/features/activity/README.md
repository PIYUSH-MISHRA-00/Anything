# features/activity/

Activity timeline: chronological view of actions and events.

## What belongs here

- Activity timeline screen and widgets
- Activity item display and formatting
- Activity filtering and search
- Timeline rendering

## What does NOT belong here

- Event system implementation (use `core/events/`)
- Event bus (use `runtime/`)
- Feature-specific screens (use respective `features/` folders)

## Key interfaces

- `ActivityTimelineScreen`
- `ActivityItemWidget`
- `ActivityFilterBar`
