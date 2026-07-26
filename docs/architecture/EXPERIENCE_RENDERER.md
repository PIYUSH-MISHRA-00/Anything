# Experience Renderer

## Overview

ExperienceRenderer converts declarative InterfaceDefinition nodes into Flutter widgets.

## Supported Component Types

- text: Display text with state binding
- button: Action button with event binding
- input: Text input with state binding
- column: Vertical layout
- row: Horizontal layout
- card: Container with padding
- switch: Toggle with state binding
- divider: Visual separator
- spacer: Vertical space
- icon: Approved icon mapping

## Unknown Components

Unsupported types render a controlled error boundary. Package validation should reject unknown types before session start.

## State Bindings

UI properties bind to Runtime state:
- text.content ← state variable
- input.value ↔ state variable
- switch.value ← state variable

## Event Bindings

UI events map to BehaviorGraph events:
- button.onPressed → event ID
- input.onChanged → event ID
- switch.onChanged → event ID
