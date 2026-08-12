/// Semantic intent compatibility — USER_INTENT_MUST_SURVIVE_PLANNING.
///
/// Rejects installing an Experience whose primary purpose conflicts with the
/// user's request (e.g. stopwatch → calculator). Uses purpose signatures for
/// validation only — not a generation allow-list of product templates.
library;

import 'app_capabilities.dart';
import 'experience_package.dart';

/// Coarse primary purpose used only for mismatch detection.
enum IntentPurpose {
  timing,
  calculation,
  weather,
  news,
  networkReference,
  collection,
  unknown,
}

/// Result of comparing requested intent to a generated package.
class IntentPreservationResult {
  final bool isCompatible;
  final IntentPurpose requested;
  final IntentPurpose generated;
  final String reason;

  const IntentPreservationResult({
    required this.isCompatible,
    required this.requested,
    required this.generated,
    required this.reason,
  });

  factory IntentPreservationResult.ok({
    required IntentPurpose requested,
    required IntentPurpose generated,
  }) => IntentPreservationResult(
    isCompatible: true,
    requested: requested,
    generated: generated,
    reason: 'compatible',
  );

  factory IntentPreservationResult.mismatch({
    required IntentPurpose requested,
    required IntentPurpose generated,
    required String reason,
  }) => IntentPreservationResult(
    isCompatible: false,
    requested: requested,
    generated: generated,
    reason: reason,
  );
}

/// Deterministic semantic distance check before install.
class IntentPreservationValidator {
  const IntentPreservationValidator();

  IntentPreservationResult validate({
    required String rawPrompt,
    required ExperiencePackage package,
    Set<String> requiredCapabilities = const {},
  }) {
    final requested = purposeFromPrompt(rawPrompt);
    final generated = purposeFromPackage(
      package,
      requiredCapabilities: requiredCapabilities,
    );

    if (requested == IntentPurpose.unknown ||
        generated == IntentPurpose.unknown) {
      return IntentPreservationResult.ok(
        requested: requested,
        generated: generated,
      );
    }

    if (requested == generated) {
      return IntentPreservationResult.ok(
        requested: requested,
        generated: generated,
      );
    }

    // Collection ↔ networkReference are both DATA apps and their boundary is
    // genuinely ambiguous for domains like "restaurant booking" (a local
    // reservation manager AND/OR external restaurant discovery). Allow either
    // realization to satisfy the other — a records app that also fetches
    // reference data, or a network dashboard that also has forms, both honor
    // the user's intent. This does NOT relax the guards that matter
    // (timing↔calculation, weather↔news, stopwatch→calculator).
    if ((requested == IntentPurpose.networkReference &&
            generated == IntentPurpose.collection) ||
        (requested == IntentPurpose.collection &&
            generated == IntentPurpose.networkReference)) {
      return IntentPreservationResult.ok(
        requested: requested,
        generated: generated,
      );
    }

    return IntentPreservationResult.mismatch(
      requested: requested,
      generated: generated,
      reason:
          'USER_INTENT_MUST_SURVIVE_PLANNING: requested ${requested.name} '
          'but generated ${generated.name}',
    );
  }

  /// Infer primary purpose from the user's words (validation vocabulary).
  IntentPurpose purposeFromPrompt(String rawPrompt) {
    final t = rawPrompt.toLowerCase();
    if (t.trim().isEmpty) return IntentPurpose.unknown;

    var timing = 0;
    var calc = 0;
    var network = 0;
    var collection = 0;

    void hit(List<String> words, void Function(int) add) {
      for (final w in words) {
        if (t.contains(w)) add(w.contains(' ') ? 3 : 2);
      }
    }

    hit(const [
      'stopwatch',
      'timer',
      'countdown',
      'chronometer',
      'elapsed',
      'lap',
    ], (n) => timing += n);
    hit(const [
      'calculator',
      'arithmetic',
      'calculate',
      'math pad',
      'maths',
      'bill split',
      'bill splitter',
      'split the bill',
    ], (n) => calc += n);
    var weather = 0;
    var news = 0;
    hit(const [
      'weather',
      'forecast',
      'temperature',
      'humidity',
    ], (n) => weather += n);
    hit(const ['news', 'headline', 'headlines', 'articles'], (n) => news += n);
    hit(const [
      'dashboard',
      'live data',
      'lookup',
      'research',
      'explain',
    ], (n) => network += n);
    hit(const [
      'todo',
      'task',
      'notes',
      'journal',
      'tracker',
      'inventory',
      'recipe',
      'crm',
      'habit',
      'flashcard',
      'attendance',
      'booking',
      'expense',
      'invoice',
      'workout',
      'library',
      'project planner',
      'manage',
      'manager',
      'operations',
      'maintenance',
      'schedule',
      'schedules',
      'members',
      'records',
      'planner',
    ], (n) => collection += n);

    // Prefer weather/news over generic "dashboard" network when both score.
    // Durable management intents win over incidental "articles"/"temperature".
    if (collection > 0 && collection >= weather && collection >= news) {
      weather = 0;
      news = 0;
    }
    final scores = {
      IntentPurpose.timing: timing,
      IntentPurpose.calculation: calc,
      IntentPurpose.weather: weather,
      IntentPurpose.news: news,
      IntentPurpose.networkReference: network,
      IntentPurpose.collection: collection,
    };
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value <= 0) return IntentPurpose.unknown;
    return best.key;
  }

  IntentPurpose purposeFromPackage(
    ExperiencePackage package, {
    Set<String> requiredCapabilities = const {},
  }) {
    final probe = PackageCapabilityProbe(package);
    if (probe.hasCalculationPad) return IntentPurpose.calculation;
    if (probe.hasTimingControls) return IntentPurpose.timing;
    if (probe.hasWeatherService ||
        requiredCapabilities.contains(AppCapabilityIds.weatherData)) {
      return IntentPurpose.weather;
    }
    if (probe.hasNewsService ||
        requiredCapabilities.contains(AppCapabilityIds.newsData)) {
      return IntentPurpose.news;
    }
    if (probe.hasKnowledgeService ||
        requiredCapabilities.contains(AppCapabilityIds.networkData) ||
        requiredCapabilities.contains(AppCapabilityIds.webData) ||
        requiredCapabilities.contains(AppCapabilityIds.webKnowledge)) {
      return IntentPurpose.networkReference;
    }
    if (probe.hasEntityForm ||
        probe.hasEntityList ||
        requiredCapabilities.contains(AppCapabilityIds.crud)) {
      return IntentPurpose.collection;
    }
    if (probe.hasCalculationPad) return IntentPurpose.calculation;
    if (probe.hasTimingControls) return IntentPurpose.timing;
    return IntentPurpose.unknown;
  }
}
