# Dead Subsystem Report — IS-R59 Phase 8

Fifteen files deleted, each proven individually, in four validated commits.

## Proof standard applied

A file was deleted only with **all** of:

- unreachable from `lib/main.dart` by transitive import closure
- zero imports from any `lib/` file
- zero imports from any `test/` file
- zero references to **any type it declares**, by name, anywhere in `lib/` or `test/`

## Deleted

| # | File | Group | Notes |
|---|---|---|---|
| 1 | `lib/models/intent_model.dart` | A | |
| 2 | `lib/models/workspace_model.dart` | A | |
| 3 | `lib/services/analytics_service.dart` | A | |
| 4 | `lib/services/latency_manager.dart` | A | |
| 5 | `lib/world_model/world_reasoner.dart` | B | |
| 6 | `lib/software_cognition/software_knowledge_graph.dart` | B | |
| 7 | `lib/runtime_intelligence/runtime_context.dart` | B | |
| 8 | `lib/feature_discovery/feature_recommendation.dart` | B | |
| 9 | `lib/design_review/review_metrics.dart` | B | only external mention was a **doc comment**, verified as prose |
| 10 | `lib/core/result/result.dart` | C | |
| 11 | `lib/runtime/golden_paths/calculator_modification.dart` | C | |
| 12 | `lib/screens/splash_screen.dart` | C | |
| 13 | `lib/widgets/workspace_container.dart` | C | |
| 14 | `lib/workflow/workflow_executor.dart` | C | |
| 15 | `lib/screens/onboarding_screen.dart` | D | **cascade** — became dead once `splash_screen.dart` was removed |

The cascade is worth noting: deleting one dead file exposed another. Phase 8's
"delete one, validate, repeat" loop is what surfaced it; a batch deletion would
have missed it.

## NOT deleted — insufficient proof

| File | Why |
|---|---|
| `lib/design_system/tokens/layout.dart` | Unreachable and unimported, but its four types (`AnythingPadding`, `AnythingBreakpoints`, `AnythingContentWidth`, `AnythingNavigation`) **collide by name** with live declarations in `spacing.dart`. A text search finds **36** apparent references and cannot attribute them. Import analysis says dead; name analysis cannot confirm. |
| `lib/world_model/semantic_entity.dart` | Identical: `SemanticEntity`/`SemanticRelationship` collide with `synthesis/application_reasoner.dart`, producing **167** unattributable references. |

Both are pinned in `pinnedUnreachableFiles` with these reasons, so **I-86**
keeps them visible rather than letting them sit in an unknown state. Resolving
them needs type-aware (AST) analysis, which R59 did not add — a dependency for
two files is not justified.

## The 50 EXPERIMENTAL files were NOT deleted

They import each other, so none is individually orphaned and none meets the
proof standard. See `PARALLEL_ARCHITECTURE_REPORT.md`.
