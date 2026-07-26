# Behavior Runtime

## Overview

BehaviorInterpreter executes declarative BehaviorGraph nodes.

## Supported Node Types

- event: Entry point
- stateRead/Write: State operations
- calculation: Arithmetic
- validation: Input validation
- transform: Data transformation
- branch: Conditional logic
- dataQuery/Mutation: Data operations
- serviceInvocation: Service calls
- capabilityInvocation: Capability calls
- navigation: Screen navigation
- errorHandling: Error handling
- return: Output

## Execution Budget

Maximum nodes per event: 100
Cycle prevention: visited set tracking

## No Arbitrary Eval

BehaviorInterpreter only executes known node types. Unknown types are skipped.
No eval, no dynamic code execution, no shell commands.
