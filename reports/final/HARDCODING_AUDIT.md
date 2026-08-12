# HARDCODING AUDIT (reports/final)

Static + call-graph audit of the production tree at HEAD `b867153` (v2.0.0).
Independently reproduced, not copied from prior reports.

## Classification of every domain term in lib/ (production)

| Term | lib/ occurrences | Classification |
|---|---|---|
| accuweather / timesofindia / open-meteo / news.google / googleapis / RSS feed | **0** | not present in source; appear only as dynamic DuckDuckGo results at runtime |
| WeatherCapability / NewsCapability | 0 (deleted IS-P25) | — |
| WeatherFactory / NewsFactory / *domain*InterfaceFactory | 0 | — |
| DataProviderRegistry / default_data_providers / webweavex_data_provider | 0 (deleted IS-P25) | — |
| weatherData / newsData | (D) schema vocabulary + (I) lexical classifiers routing to the ONE generic network shell | never a construction factory |
| weather / news / forecast / humidity / headline | (D) semantic vocabulary, (A) UI labels, (B) doc comments, (I) intent classifiers | classification only |
| restaurant / pottery / clinic / booking | **absent from production construction logic** | IS-P27 derives the subject structurally; no per-domain branch |
| calculator / stopwatch / timer | (D) capability-shell vocabulary + (C) dormant golden-path test fixtures | not domain factories |
| api.groq.com (direct HTTP) | dead legacy island only (lib/services, lib/agents, lib/core, lib/tools, lib/screens/workspace) — **0 live imports** | (J) dead code (MIS-1 Delete list) |

## Verdict per invariant

- **1.1 No domain-specific primary creation mechanism**: PASS. Creation is
  capability/requirement-driven; IS-P27's open-world fallback derives the
  subject noun structurally (no `if restaurant → RestaurantFactory`). The one
  keyword-classification remaining routes to the ONE generic network-reference
  shell, never a factory.
- **1.2 No hardcoded weather/news API**: PASS. Only external non-LLM endpoint in
  lib/ is DuckDuckGo (`lib/knowledge/search_provider.dart:44`), the
  interchangeable default `SearchProvider`. AccuWeather/Times of India are
  DYNAMICALLY DISCOVERED results, scored against the requirement; the source
  changes with the query (India news → NDTV, not TOI). Zero source names in lib/.
- **1.3–1.4 WebWeaveX generic acquisition boundary**: PASS. Sole
  `package:webweavex` importer is `lib/knowledge/webweavex_adapter.dart`.
- **1.7 Kaalka boundary**: PASS. Sole `package:kaalka` importer is
  `lib/security/kaalka_service.dart`; no parallel confidentiality crypto.

## New external-data model (IS-P25)
`KnowledgeRequirement{objective, topicTerms, freshness}` — a generic
external-data requirement (subject/topic/location/freshness), NOT
`WeatherCapability`/`NewsCapability`. "current weather in Lucknow" becomes the
composed query "Lucknow weather current" scored for recency — exactly the
generic model §2.1 asks for.

## Automated guards (all pass)
`test/dynamic/p21_hardcoding_probe_test.dart` (domain-switch regexes over lib/),
`test/dynamic/p16_architecture_mutation_test.dart`,
`test/r46_architectural_integrity_certification_test.dart` (109 invariants).

## Verdict: PASS — no hardcoded domain APIs, factories, sources, or cities in the
production path. IS-P27 added no domain construction logic.
