# P18 — Fake service audit

**Date:** 2026-08-10  
**Scope:** `lib/` Fake* types vs production composition

## Production wiring

`lib/app/app_composition.dart` registers:

- `RealHttpTransport`
- `RealNotificationService`
- `RealFileService`
- Model / knowledge adapters (not Fake*)

Grep for constructor calls of Fake* services in `app_composition.dart`: **none**.

## Classifications

| Type | Location | Classification |
|---|---|---|
| `FakeHttpTransport` | `lib/capabilities/builtin/http_capability.dart` | Test/adapter double — not production-wired |
| `FakeNotificationService` | `lib/capabilities/builtin/notification_capability.dart` | Test/adapter double — not production-wired |
| `FakeFileService` | `lib/capabilities/builtin/file_capability.dart` | Test/adapter double — not production-wired |
| `FakeAiProvider` | `lib/capabilities/builtin/ai_capability.dart` | Test/adapter double — not production-wired |
| `FakeKnowledgeProvider` | `lib/capabilities/builtin/knowledge_capability.dart` | Test/adapter double — not production-wired |
| `_FakeProviderRegistry` | `lib/compiler_certification/certification_runner.dart` | Certification harness |

## Rule

Historical Fake* implementations may remain in `lib/` as doubles referenced by
capability docs/tests. They must not be registered by `AppComposition`.
P18 confirms they are not.
