# Behavior Graph Architecture

## Overview

BehaviorGraph is a declarative representation of application logic. It describes WHAT the application does without specifying HOW it is implemented.

## Nodes

Typed behavior operations:
- event: User interaction trigger
- stateRead: Read state variable
- stateWrite: Write state variable
- calculation: Arithmetic/computation
- validation: Input validation
- transform: Data transformation
- branch: Conditional logic
- capabilityInvocation: Use a registered capability
- serviceInvocation: Use a declared service
- navigation: Screen navigation
- dataQuery: Query data store
- dataMutation: Modify data store
- errorHandling: Handle errors
- return: Output result

## Edges

Connect nodes with optional conditions.

## Validation

- Known node types only
- Valid edges
- No dangling references
- Bounded loops
- No forbidden operations
- No arbitrary eval
