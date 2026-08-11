# 22 — Domain Factory Removal Report (P0 Violation Fix)

## Summary

Removed all domain-specific hardcoding from the creation pipeline. Weather, news, and all external data requirements now route through the generic `NetworkReferenceInterfaceFactory` via WebWeaveX, eliminating the forbidden domain-specific factory pattern.

## What Changed

### Production Code (3 files modified, 4 files deleted)

| File | Change |
| --- | ---|
| `lib/creation/creation_engine.dart` | Replaced `WeatherInterfaceFactory`/`NewsInterfaceFactory` branches (lines 281-335) with single `needsExternalData` check → `NetworkReferenceInterfaceFactory`. Removed 2 domain factory imports. |
| `lib/app/creation_coordinator.dart` | Replaced `WeatherInterfaceFactory`/`NewsInterfaceFactory` branches (lines 543-576) with generic `networkReference` intent handling. Removed 2 domain factory imports, added `NetworkReferenceInterfaceFactory` import. |
| `lib/creation/deterministic_repair.dart` | Replaced weather/news gap repair (lines 118-164) with generic `needsExternalData` check → `NetworkReferenceInterfaceFactory`. Removed 2 domain factory imports. |
| `lib/creation/weather_interface_factory.dart` | **DELETED** (241 lines) |
| `lib/creation/news_interface_factory.dart` | **DELETED** (253 lines) |
| `lib/domain_services/weather_data_service.dart` | **DELETED** (159 lines) |
| `lib/domain_services/news_data_service.dart` | **DELETED** (190 lines) |

### Test Files (5 files modified)

| File | Change |
| --- | --- |
| `test/p13_domain_services_test.dart` | Updated to use `NetworkReferenceInterfaceFactory`. Changed prompts to classify as `networkReference` intent (not `weather`/`news`). |
| `test/dynamic/p15_search_image_test.dart` | Replaced `NewsInterfaceFactory` with `NetworkInterfaceFactory`. Changed capability id from `news` to `knowledge`, event id from `search` to `refreshData`. Removed stale-concurrent-search test (domain-specific behavior). |
| `test/dynamic/p16_architecture_mutation_test.dart` | Updated factory list expectation (removed 2 domain factories). |
| `test/dynamic/p21_hardcoding_probe_test.dart` | Removed domain service/factory paths from allow-list. |
| `tool/p13_live_domain_probe.dart` | Rewritten to use `KnowledgeAcquisitionEngine` via WebWeaveX. |
| `tool/p15_news_query_probe.dart` | Rewritten to use `KnowledgeAcquisitionEngine` via WebWeaveX. |

## Why This Was Done

### The Violation

The creation pipeline had a domain-specific switch:
```dart
if (wantsWeather) {
  WeatherInterfaceFactory()  // FORBIDDEN — domain-specific acquisition
} else if (wantsNews) {
  NewsInterfaceFactory()     // FORBIDDEN — domain-specific acquisition
} else {
  NetworkReferenceInterfaceFactory()  // ALLOWED — generic knowledge shell
}
```

This violated the core architecture principle: **the system must reason about WHAT the user needs, not route by domain keywords**. Weather and news were being treated as special cases with their own factories, services, and capability declarations — duplicating what WebWeaveX already provides generically.

### The Fix

Replaced with:
```dart
final needsExternalData =
    inferredCaps.contains(AppCapabilityIds.webKnowledge) ||
    inferredCaps.contains(AppCapabilityIds.networkData) ||
    inferredCaps.contains(AppCapabilityIds.webData) ||
    inferredCaps.contains(AppCapabilityIds.weatherData) ||
    inferredCaps.contains(AppCapabilityIds.newsData);

if (needsExternalData) {
  NetworkReferenceInterfaceFactory()  // ONE path for ALL external data
}
```

Now the semantic planner determines WHAT data is needed, and WebWeaveX's `KnowledgeAcquisitionEngine` figures out HOW to get it — no domain-specific routing.

## Verification

| Check | Result |
| --- | --- |
| `dart analyze lib/` | 1 pre-existing warning only |
| `flutter test` | 2327 pass / 6 fail (all pre-existing, none from this change) |
| Release APK built | 63.0 MB, SHA `8B4D1D33...` |
| APK installed on device | Success |
| App launches | Home screen renders correctly |
| No domain factory refs in `lib/` | Verified via grep |
| Architecture mutation tests pass | `p16`, `p21` pass |
| Hardcoding probe tests pass | `p21` pass |
