# Play Store Readiness Audit

## Current Status: Foundation Stage

Anything v2 is in early development. This document tracks Play Store readiness.

## Application Identity

| Item | Status | Notes |
|------|--------|-------|
| Application ID | `com.example.anything` (default) | Needs real ID before release |
| App Name | "Anything" | Set in MaterialApp |
| Version | `1.0.0+1` | Needs update for v2.0.0 |
| Package Name | TBD | Must be unique on Play Store |

## Android Configuration

| Item | Status | Notes |
|------|--------|-------|
| Min SDK | 21 (Flutter default) | Good for broad compatibility |
| Target SDK | Latest stable | Follow Flutter defaults |
| Permissions | Internet only | Microphone requested on-demand |
| Adaptive Icon | Not configured | Needs `assets/branding/` icons |
| Splash Screen | Default Flutter | Needs custom splash |
| Edge-to-edge | Not implemented | Needed for modern Android |
| Backup Rules | Not configured | Needed for local data |

## Permissions Strategy

| Permission | When Requested | Justification |
|-----------|---------------|---------------|
| Internet | Runtime (implicit) | AI provider, WebWeaveX |
| Microphone | On voice input tap | Voice intent input |
| Storage | Not requested | Use platform document APIs |

## Signing

| Item | Status |
|------|--------|
| Debug signing | Flutter default |
| Release signing | Not configured |
| Upload signing | Not configured |
| Key management | Not configured |

## Privacy

| Item | Status |
|------|--------|
| Privacy policy | Not created |
| Data safety form | Not prepared |
| Analytics SDK | None (by design) |
| Crash reporting | None |
| Advertising | None |

## Software Cognition (Vision Milestone V11, 2026-08-02)

`lib/software_cognition/` (repository/package/API understanding) adds no
new network destination beyond `package:webweavex`'s existing bounded
HTTP fetch, no background execution, no new permission requirement, and
no `eval`/`dart:mirrors`/runtime compilation — it remains declarative and
deterministic, consistent with every existing Play Store constraint row
above.

## Pre-release Checklist

- [ ] Real application ID
- [ ] Adaptive icon
- [ ] Custom splash screen
- [ ] Edge-to-edge implementation
- [ ] Release signing configuration
- [ ] Privacy policy
- [ ] Data safety questionnaire
- [ ] Store listing graphics
- [ ] Store description
- [ ] Content rating questionnaire
