/// Experience Resolver — checks if an existing Experience can satisfy an Intent.
///
/// Uses the ExperienceRepository to find matching experiences.
library;

import '../understanding/intent_understanding.dart';

/// Resolves whether an existing Experience matches a user expression.
///
/// Holds no built-in domain knowledge: it only matches experiences that
/// have been explicitly registered (e.g. from ExperienceRepository), so
/// open-world synthesis is never short-circuited by a hardcoded domain.
class ExperienceResolver {
  final Map<String, _ExperienceEntry> _fixtures = {};

  ExperienceResolver();

  /// Register an experience for resolution.
  void registerExperience(String id, String name, List<String> keywords) {
    _fixtures[name.toLowerCase()] = _ExperienceEntry(
      id: id,
      name: name,
      keywords: keywords,
    );
  }

  /// Resolve whether an existing experience matches the expression.
  ExistingExperienceResolution resolve(String expression) {
    final lower = expression.toLowerCase().trim();

    // Check for "open" prefix
    final isOpenRequest =
        lower.startsWith('open ') ||
        lower.startsWith('show ') ||
        lower.startsWith('go to ');
    final searchTerms = isOpenRequest
        ? lower.replaceFirst(RegExp(r'^(open|show me|go to|launch)\s+'), '')
        : lower;

    // Search for matching experiences
    for (final entry in _fixtures.values) {
      for (final keyword in entry.keywords) {
        if (searchTerms.contains(keyword)) {
          return ExistingExperienceResolution.found(
            experienceId: entry.id,
            experienceName: entry.name,
          );
        }
      }
    }

    return ExistingExperienceResolution.notFound();
  }
}

class _ExperienceEntry {
  final String id;
  final String name;
  final List<String> keywords;

  const _ExperienceEntry({
    required this.id,
    required this.name,
    required this.keywords,
  });
}
