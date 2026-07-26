# Generated Experience Security

## Principle

All generated packages begin as untrusted/generated content. Validation makes them structurally acceptable but does not make arbitrary code trusted.

## Trust Model

v1 packages use trusted declarative primitives. The Runtime interprets only supported operations.

## Allowed Operations

Only registered behavior node types are permitted:
- event, stateRead, stateWrite, calculation, validation, transform
- branch, capabilityInvocation, serviceInvocation, navigation
- dataQuery, dataMutation, errorHandling, return

## Forbidden Operations

- Arbitrary Dart eval
- JavaScript eval
- Dynamic downloaded code
- Shell commands
- Process execution
- Runtime compilation
- Path traversal
- Absolute filesystem access

## Capability Mediation

Every privileged operation maps to a registered capability. Unknown capabilities are rejected.

## Network Mediation

Network access is declared and controlled. No arbitrary unrestricted access.

## Permission Mediation

Permissions are declared. Runtime mediates actual permission requests.
